// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Sale
/// @notice Manages the sale of ERC20 tokens with configurable pricing and admin controls
/// @dev Implements access control, pausability and reentrancy protection
contract Sale is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role identifier for administrators
    bytes32 public immutable ADMIN_ROLE = keccak256("ADMIN_ROLE");
    /// @notice Role identifier for users who can set token prices
    bytes32 public immutable PRICE_SETTER_ROLE = keccak256("PRICE_SETTER_ROLE");
    /// @notice Role identifier for emergency withdrawals
    bytes32 public immutable EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    /// @notice Role identifier for depositors
    bytes32 public immutable DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    /// @notice Address of timelock controller
    TimelockController public immutable timelock;

    /// @notice Thrown when caller is not timelock contract
    error UnauthorizedTimelock();
    /// @notice Thrown when a zero address is provided where a valid address is required
    error ZeroAddress();
    /// @notice Thrown when an invalid price (zero) is set
    error InvalidPrice();
    /// @notice Thrown when an invalid token amount is specified
    /// @param amount The invalid amount that was provided
    error InvalidTokenAmount(uint256 amount);
    /// @notice Thrown when there are insufficient tokens for a sale
    error InsufficientTokenBalance();
    /// @notice Thrown when the same token address is used for both sale and payment tokens
    /// @param token The duplicate token address
    error SameTokenAddress(address token);
    /// @notice Thrown when attempting to deposit zero tokens
    error InvalidDepositAmount();
    /// @notice Thrown when amount exceeds uint128 max
    error AmountTooLarge();
    /// @notice Thrown when an invalid amount is specified
    error InvalidAmount();
    /// @notice Thrown when there are insufficient tokens for withdrawal
    error InsufficientBalance();

    /// @notice Emitted when the token price is updated
    /// @param oldPrice The previous price
    /// @param newPrice The new price
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    /// @notice Emitted when tokens are sold
    /// @param buyer The address of the token buyer
    /// @param saleTokenAmount Amount of tokens sold
    /// @param paymentTokenAmount Amount of payment tokens received
    event TokensSold(address indexed buyer, uint256 saleTokenAmount, uint256 paymentTokenAmount);
    /// @notice Emitted during emergency withdrawals
    /// @param token The token being withdrawn
    /// @param amount The amount withdrawn
    event EmergencyWithdraw(address token, uint256 amount);
    /// @notice Emitted when sale tokens are deposited
    /// @param amount The amount of tokens deposited
    event SaleTokensDeposited(uint256 amount);

    /// @notice The token being sold
    address public immutable saleToken;
    /// @notice The token used for payment (e.g., USDC)
    address public immutable paymentToken;

    /// @notice Current price in payment tokens per sale token (scaled by 1e18)
    uint256 public price;

    /// @notice Sale name (e.g. "USDC/ETH Sale")
    string public name;
    /// @notice Sale symbol (e.g. "USDC-ETH-SALE")
    string public symbol;

    /// @notice Initializes the token sale contract
    /// @param _saleToken Address of the token being sold
    /// @param _paymentToken Address of the token used for payment
    /// @param _initialPrice Initial price per token (scaled by 1e18)
    /// @param _admin Address of the admin who will have full control
    constructor(
        address _saleToken,
        address _paymentToken,
        uint256 _initialPrice,
        address _admin
    ) {
        if (_admin == address(0)) revert ZeroAddress();
        if (_saleToken == address(0) || _paymentToken == address(0)) revert ZeroAddress();
        if (_saleToken == _paymentToken) revert SameTokenAddress(_saleToken);
        if (_initialPrice == 0) revert InvalidPrice();

        saleToken = _saleToken;
        paymentToken = _paymentToken;
        price = _initialPrice;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(PRICE_SETTER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        _grantRole(DEPOSITOR_ROLE, _admin);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = _admin;
        executors[0] = _admin;
        timelock = new TimelockController(2 days, proposers, executors, _admin);

        // Generate dynamic name and symbol
        name = string.concat(
            IERC20Metadata(_paymentToken).symbol(),
            "/",
            IERC20Metadata(_saleToken).symbol(),
            " Sale"
        );
        symbol = string.concat(
            IERC20Metadata(_paymentToken).symbol(),
            "-",
            IERC20Metadata(_saleToken).symbol(),
            "-SALE"
        );
    }

    /// @notice Updates the token sale price
    /// @param _newPrice New price per token (scaled by 1e18)
    function setPrice(uint256 _newPrice) external {
        if (msg.sender != address(timelock)) revert UnauthorizedTimelock();
        if (_newPrice == 0) revert InvalidPrice();
        emit PriceUpdated(price, _newPrice);
        price = _newPrice;
    }

    /// @notice Allows users to purchase tokens at the current price
    /// @param saleTokenAmount Amount of tokens to purchase
    function buyTokens(uint256 saleTokenAmount) external nonReentrant whenNotPaused {
        if (saleTokenAmount > type(uint128).max) revert AmountTooLarge();
        if (saleTokenAmount == 0) revert InvalidTokenAmount(0);

        uint256 paymentAmount = (saleTokenAmount * price) / 1e18;

        if (IERC20(saleToken).balanceOf(address(this)) < saleTokenAmount) {
            revert InsufficientTokenBalance();
        }

        emit TokensSold(msg.sender, saleTokenAmount, paymentAmount);

        // Transfer payment tokens from buyer to this contract
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), paymentAmount);

        // Transfer sale tokens to buyer
        IERC20(saleToken).safeTransfer(msg.sender, saleTokenAmount);
    }

    /// @notice Pauses all token sales
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /// @notice Resumes token sales
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Allows admins to withdraw tokens in case of emergency
    /// @param token Address of the token to withdraw
    /// @param amount Amount of tokens to withdraw
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyRole(EMERGENCY_ROLE) nonReentrant {
        if(token == address(0)) revert ZeroAddress();
        if(amount == 0) revert InvalidAmount();
        if(amount > IERC20(token).balanceOf(address(this))) revert InsufficientBalance();
        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(token, amount);
    }

    /// @notice Allows admins to deposit sale tokens into the contract
    /// @param amount Amount of tokens to deposit
    function depositSaleTokens(uint256 amount) external onlyRole(DEPOSITOR_ROLE) {
        if (amount == 0) revert InvalidDepositAmount();

        // Transfer sale tokens from admin to this contract
        IERC20(saleToken).safeTransferFrom(msg.sender, address(this), amount);

        emit SaleTokensDeposited(amount);
    }
}
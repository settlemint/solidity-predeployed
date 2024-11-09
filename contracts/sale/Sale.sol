// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Sale is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role identifier for administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Thrown when input validation fails
    error InvalidInput(string message);
    /// @notice Thrown when operation validation fails
    error InvalidOperation(string message);

    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TokensSold(address indexed buyer, uint256 saleTokenAmount, uint256 paymentTokenAmount);
    event EmergencyWithdraw(address token, uint256 amount);
    event SaleTokensDeposited(uint256 amount);

    address public immutable saleToken;
    address public immutable paymentToken;
    uint256 public price;
    string public name;
    string public symbol;

    constructor(address _saleToken, address _paymentToken, uint256 _initialPrice, address _admin) {
        if (_admin == address(0)) revert InvalidInput("Zero admin address");
        if (_saleToken == address(0) || _paymentToken == address(0)) {
            revert InvalidInput("Zero token address");
        }
        if (_saleToken == _paymentToken) {
            revert InvalidInput("Same token address");
        }
        if (_initialPrice == 0) {
            revert InvalidInput("Zero price");
        }

        saleToken = _saleToken;
        paymentToken = _paymentToken;
        price = _initialPrice;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);

        name = string.concat(IERC20Metadata(_paymentToken).symbol(), "/", IERC20Metadata(_saleToken).symbol(), " Sale");
        symbol =
            string.concat(IERC20Metadata(_paymentToken).symbol(), "-", IERC20Metadata(_saleToken).symbol(), "-SALE");
    }

    function setPrice(uint256 _newPrice) external onlyRole(ADMIN_ROLE) {
        if (_newPrice == 0) revert InvalidInput("Zero price");
        emit PriceUpdated(price, _newPrice);
        price = _newPrice;
    }

    function buyTokens(uint256 saleTokenAmount) external whenNotPaused nonReentrant {
        if (saleTokenAmount > type(uint128).max) {
            revert InvalidInput("Amount too large");
        }
        if (saleTokenAmount == 0) {
            revert InvalidInput("Zero amount");
        }

        uint256 paymentAmount = (saleTokenAmount * price) / 1e18;

        if (IERC20(saleToken).balanceOf(address(this)) < saleTokenAmount) {
            revert InvalidOperation("Insufficient token balance");
        }

        emit TokensSold(msg.sender, saleTokenAmount, paymentAmount);

        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), paymentAmount);
        IERC20(saleToken).safeTransfer(msg.sender, saleTokenAmount);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyRole(ADMIN_ROLE) nonReentrant {
        if (token == address(0)) revert InvalidInput("Zero token address");
        if (amount == 0) revert InvalidInput("Zero amount");
        if (amount > IERC20(token).balanceOf(address(this))) {
            revert InvalidOperation("Insufficient balance");
        }
        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(token, amount);
    }

    function depositSaleTokens(uint256 amount) external onlyRole(ADMIN_ROLE) nonReentrant {
        if (amount == 0) revert InvalidInput("Zero deposit amount");
        IERC20(saleToken).safeTransferFrom(msg.sender, address(this), amount);
        emit SaleTokensDeposited(amount);
    }
}

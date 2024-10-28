// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title StarterKitERC20Sale
/// @notice A contract for managing ERC20 token sales with configurable pricing and purchase limits
/// @dev Implements reentrancy protection and ownership controls using OpenZeppelin contracts
/// @custom:security-contact security@settlemint.com
contract StarterKitERC20Sale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The ERC20 token being sold through this contract
    IERC20 public immutable TOKEN_FOR_SALE;
    /// @notice The ERC20 token accepted as payment for purchases
    IERC20 public immutable TOKEN_FOR_PAYMENT;
    /// @notice The price per token in payment token units (18 decimals)
    uint256 public pricePerToken;

    /// @notice The minimum amount of tokens that can be purchased in a single transaction
    uint256 public minPurchase;
    /// @notice The maximum amount of tokens that can be purchased in a single transaction
    uint256 public maxPurchase;
    /// @notice Flag indicating if the sale is currently active and accepting purchases
    bool public saleActive;

    /// @notice Thrown when the buyer's token allowance is insufficient for the purchase
    /// @param allowed The current allowance amount
    /// @param required The required allowance amount
    error InsufficientAllowance(uint256 allowed, uint256 required);
    /// @notice Thrown when the buyer's token balance is insufficient for the purchase
    /// @param balance The buyer's current balance
    /// @param required The required balance amount
    error InsufficientBalance(uint256 balance, uint256 required);
    /// @notice Thrown when the contract's token balance is insufficient for the purchase
    /// @param balance The contract's current balance
    /// @param required The required balance amount
    error InsufficientContractBalance(uint256 balance, uint256 required);
    /// @notice Thrown when attempting to make a purchase while the sale is inactive
    error SaleNotActive();
    /// @notice Thrown when the purchase amount is outside the allowed range
    /// @param amount The invalid purchase amount
    error InvalidAmount(uint256 amount);
    /// @notice Thrown when attempting to set the token price to zero
    error PriceNotGreaterThanZero();
    /// @notice Thrown when the minimum purchase amount exceeds the maximum purchase amount
    /// @param min The minimum purchase amount
    /// @param max The maximum purchase amount
    error MinPurchaseExceedsMax(uint256 min, uint256 max);
    /// @notice Thrown when attempting to rescue sale or payment tokens via rescueToken
    error CannotRescueProtectedTokens();

    /// @notice Emitted when a successful token purchase occurs
    /// @param buyer The address of the account that purchased tokens
    /// @param amount The amount of tokens purchased
    /// @param cost The total cost in payment tokens
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    /// @notice Emitted when tokens are deposited into the sale contract
    /// @param sender The address that deposited the tokens
    /// @param amount The amount of tokens deposited
    event TokensDeposited(address indexed sender, uint256 amount);
    /// @notice Emitted when tokens are withdrawn from the sale contract
    /// @param receiver The address receiving the withdrawn tokens
    /// @param amount The amount of tokens withdrawn
    event TokensWithdrawn(address indexed receiver, uint256 amount);
    /// @notice Emitted when the sale status is updated
    /// @param isActive The new status of the sale
    event SaleStatusUpdated(bool isActive);
    /// @notice Emitted when the token price is updated
    /// @param newPrice The new price per token
    event PriceUpdated(uint256 newPrice);
    /// @notice Emitted when the purchase limits are updated
    /// @param minAmount The new minimum purchase amount
    /// @param maxAmount The new maximum purchase amount
    event PurchaseLimitsUpdated(uint256 minAmount, uint256 maxAmount);

    /// @notice Initializes the sale contract with the specified parameters
    /// @param tokenForSale The address of the ERC20 token being sold
    /// @param tokenForPayment The address of the ERC20 token accepted as payment
    /// @param _pricePerToken The initial price per token in payment token units (18 decimals)
    /// @param _minPurchase The minimum amount of tokens that can be purchased
    /// @param _maxPurchase The maximum amount of tokens that can be purchased
    /// @param owner The address that will own and control the sale contract
    constructor(
        IERC20 tokenForSale,
        IERC20 tokenForPayment,
        uint256 _pricePerToken,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        address owner
    )
        Ownable(owner)
    {
        TOKEN_FOR_SALE = tokenForSale;
        TOKEN_FOR_PAYMENT = tokenForPayment;
        pricePerToken = _pricePerToken;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        saleActive = true;
    }

    /// @notice Allows users to purchase tokens from the sale
    /// @dev Implements checks for sale status, purchase limits, and token transfers
    /// @param amount The amount of tokens to purchase
    function buy(uint256 amount) external nonReentrant {
        if (!saleActive) revert SaleNotActive();

        uint256 contractBalance = TOKEN_FOR_SALE.balanceOf(address(this));

        if (minPurchase != 0 || maxPurchase != 0) {
            if (amount != contractBalance && (amount < minPurchase || amount > maxPurchase)) {
                revert InvalidAmount(amount);
            }
        }

        if (contractBalance < amount) {
            revert InsufficientContractBalance(contractBalance, amount);
        }

        uint256 paymentAmount = amount * pricePerToken / 1e18;

        if (TOKEN_FOR_PAYMENT.allowance(msg.sender, address(this)) < paymentAmount) {
            revert InsufficientAllowance(TOKEN_FOR_PAYMENT.allowance(msg.sender, address(this)), paymentAmount);
        }

        if (TOKEN_FOR_PAYMENT.balanceOf(msg.sender) < paymentAmount) {
            revert InsufficientBalance(TOKEN_FOR_PAYMENT.balanceOf(msg.sender), paymentAmount);
        }

        TOKEN_FOR_PAYMENT.safeTransferFrom(msg.sender, owner(), paymentAmount);
        TOKEN_FOR_SALE.safeTransfer(msg.sender, amount);

        emit TokensPurchased(msg.sender, amount, paymentAmount);
    }

    /// @notice Allows the owner to deposit tokens for sale
    /// @dev Transfers tokens from the owner to the contract
    /// @param amount The amount of tokens to deposit
    function deposit(uint256 amount) external onlyOwner {
        TOKEN_FOR_SALE.safeTransferFrom(msg.sender, address(this), amount);
        emit TokensDeposited(msg.sender, amount);
    }

    /// @notice Allows the owner to withdraw tokens from the sale
    /// @dev Transfers tokens from the contract to the owner
    /// @param amount The amount of tokens to withdraw
    function withdraw(uint256 amount) external onlyOwner {
        TOKEN_FOR_SALE.safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(msg.sender, amount);
    }

    /// @notice Allows the owner to enable or disable the sale
    /// @dev Updates the sale status and emits an event
    /// @param status The new sale status (true = active, false = inactive)
    function setSaleStatus(bool status) external onlyOwner {
        saleActive = status;
        emit SaleStatusUpdated(status);
    }

    /// @notice Allows the owner to set the minimum and maximum purchase limits
    /// @dev Validates that minimum is not greater than maximum
    /// @param _minPurchase The new minimum purchase amount
    /// @param _maxPurchase The new maximum purchase amount
    function setPurchaseLimits(uint256 _minPurchase, uint256 _maxPurchase) external onlyOwner {
        if (_minPurchase > _maxPurchase) revert MinPurchaseExceedsMax(_minPurchase, _maxPurchase);
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        emit PurchaseLimitsUpdated(_minPurchase, _maxPurchase);
    }

    /// @notice Allows the owner to update the price per token
    /// @dev Validates that the new price is not zero
    /// @param newPrice The new price per token in payment token units (18 decimals)
    function updatePrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert PriceNotGreaterThanZero();
        pricePerToken = newPrice;
        emit PriceUpdated(newPrice);
    }

    /// @notice Allows the owner to rescue any ERC20 tokens accidentally sent to the contract
    /// @dev Prevents withdrawal of sale and payment tokens
    /// @param token The address of the token to rescue
    /// @param amount The amount of tokens to rescue
    function rescueToken(IERC20 token, uint256 amount) external onlyOwner {
        if (token == TOKEN_FOR_SALE || token == TOKEN_FOR_PAYMENT) revert CannotRescueProtectedTokens();
        token.safeTransfer(owner(), amount);
    }

    /// @notice Returns the current balance of sale tokens in the contract
    /// @dev Queries the token contract for the current balance
    /// @return The amount of tokens available for sale
    function availableTokens() external view returns (uint256) {
        return TOKEN_FOR_SALE.balanceOf(address(this));
    }
}

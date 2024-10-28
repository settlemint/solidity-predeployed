// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title StarterKitERC20Sale
/// @notice Manages token sales with configurable pricing and purchase limits
/// @dev Implements reentrancy protection and ownership controls
contract StarterKitERC20Sale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Token being sold
    IERC20 public immutable TOKEN_FOR_SALE;
    /// @notice Token accepted as payment
    IERC20 public immutable TOKEN_FOR_PAYMENT;
    /// @notice Price per token in payment token units
    uint256 public pricePerToken;

    /// @notice Minimum purchase amount
    uint256 public minPurchase;
    /// @notice Maximum purchase amount
    uint256 public maxPurchase;
    /// @notice Whether the sale is currently active
    bool public saleActive;

    /// @notice Thrown when allowance is insufficient for purchase
    error InsufficientAllowance(uint256 allowed, uint256 required);
    /// @notice Thrown when buyer balance is insufficient
    error InsufficientBalance(uint256 balance, uint256 required);
    /// @notice Thrown when contract token balance is insufficient
    error InsufficientContractBalance(uint256 balance, uint256 required);
    /// @notice Thrown when attempting purchase while sale is inactive
    error SaleNotActive();
    /// @notice Thrown when purchase amount is invalid
    error InvalidAmount(uint256 amount);
    /// @notice Thrown when attempting to set price to zero
    error PriceNotGreaterThanZero();
    /// @notice Thrown when min purchase exceeds max purchase
    error MinPurchaseExceedsMax(uint256 min, uint256 max);

    /// @notice Emitted when tokens are purchased
    /// @param buyer Address of the purchaser
    /// @param amount Amount of tokens purchased
    /// @param cost Total cost in payment tokens
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    /// @notice Emitted when tokens are deposited to the contract
    /// @param sender Address depositing tokens
    /// @param amount Amount of tokens deposited
    event TokensDeposited(address indexed sender, uint256 amount);
    /// @notice Emitted when tokens are withdrawn from the contract
    /// @param receiver Address receiving withdrawn tokens
    /// @param amount Amount of tokens withdrawn
    event TokensWithdrawn(address indexed receiver, uint256 amount);
    /// @notice Emitted when sale status is updated
    /// @param isActive New sale status
    event SaleStatusUpdated(bool isActive);
    /// @notice Emitted when token price is updated
    /// @param newPrice New price per token
    event PriceUpdated(uint256 newPrice);
    /// @notice Emitted when purchase limits are updated
    /// @param minAmount New minimum purchase amount
    /// @param maxAmount New maximum purchase amount
    event PurchaseLimitsUpdated(uint256 minAmount, uint256 maxAmount);

    /// @notice Initializes the sale contract
    /// @param tokenForSale Address of token being sold
    /// @param tokenForPayment Address of token accepted as payment
    /// @param _pricePerToken Initial price per token
    /// @param _minPurchase Minimum purchase amount
    /// @param _maxPurchase Maximum purchase amount
    /// @param owner Address of contract owner
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

    /// @notice Purchase tokens
    /// @param amount Amount of tokens to purchase
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

    /// @notice Deposit tokens for sale
    /// @param amount Amount of tokens to deposit
    function deposit(uint256 amount) external onlyOwner {
        TOKEN_FOR_SALE.safeTransferFrom(msg.sender, address(this), amount);
        emit TokensDeposited(msg.sender, amount);
    }

    /// @notice Withdraw tokens from sale
    /// @param amount Amount of tokens to withdraw
    function withdraw(uint256 amount) external onlyOwner {
        TOKEN_FOR_SALE.safeTransfer(msg.sender, amount);
        emit TokensWithdrawn(msg.sender, amount);
    }

    /// @notice Set sale active status
    /// @param status New sale status
    function setSaleStatus(bool status) external onlyOwner {
        saleActive = status;
        emit SaleStatusUpdated(status);
    }

    /// @notice Set minimum and maximum purchase limits
    /// @param _minPurchase New minimum purchase amount
    /// @param _maxPurchase New maximum purchase amount
    function setPurchaseLimits(uint256 _minPurchase, uint256 _maxPurchase) external onlyOwner {
        if (_minPurchase > _maxPurchase) revert MinPurchaseExceedsMax(_minPurchase, _maxPurchase);
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        emit PurchaseLimitsUpdated(_minPurchase, _maxPurchase);
    }

    /// @notice Update price per token
    /// @param newPrice New price per token
    function updatePrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert PriceNotGreaterThanZero();
        pricePerToken = newPrice;
        emit PriceUpdated(newPrice);
    }

    /// @notice Rescue any ERC20 tokens accidentally sent to contract
    /// @param token Token to rescue
    /// @param amount Amount to rescue
    function rescueToken(IERC20 token, uint256 amount) external onlyOwner {
        token.safeTransfer(owner(), amount);
    }

    /// @notice Get available tokens for sale
    /// @return Amount of tokens available
    function availableTokens() external view returns (uint256) {
        return TOKEN_FOR_SALE.balanceOf(address(this));
    }
}

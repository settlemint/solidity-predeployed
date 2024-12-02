// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Dex
/// @notice Implements an automated market maker DEX for ERC20 token pairs
/// @dev Extends ERC20 for liquidity tokens and includes access control, pausability and reentrancy protection
contract Pair is ERC20, ERC20Permit, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role identifier for administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Thrown when input validation fails
    error InvalidInput(string message);
    /// @notice Thrown when operation validation fails
    error InvalidOperation(string message);
    /// @notice Thrown when security check fails
    error SecurityError(string message);

    /// @notice Emitted when liquidity is added
    /// @param sender Address adding liquidity
    /// @param baseAmount Amount of base token added
    /// @param quoteAmount Amount of quote token added
    /// @param liquidity Amount of PAIR tokens minted
    event Mint(address indexed sender, uint256 baseAmount, uint256 quoteAmount, uint256 liquidity);

    /// @notice Emitted when liquidity is removed
    /// @param sender Address removing liquidity
    /// @param baseAmount Amount of base token removed
    /// @param quoteAmount Amount of quote token removed
    /// @param to Address receiving tokens
    /// @param liquidity Amount of PAIR tokens burned
    event Burn(address indexed sender, uint256 baseAmount, uint256 quoteAmount, address indexed to, uint256 liquidity);

    /// @notice Emitted when tokens are swapped
    /// @param sender Address initiating swap
    /// @param baseAmountIn Amount of base token input
    /// @param quoteAmountIn Amount of quote token input
    /// @param baseAmountOut Amount of base token output
    /// @param quoteAmountOut Amount of quote token output
    /// @param to Address receiving output tokens
    event Swap(
        address indexed sender,
        uint256 baseAmountIn,
        uint256 quoteAmountIn,
        uint256 baseAmountOut,
        uint256 quoteAmountOut,
        address indexed to
    );

    /// @notice Emitted when fee is updated
    /// @param oldFee Previous fee value
    /// @param newFee New fee value
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    /// @notice Emitted during emergency withdrawals
    /// @param token Token being withdrawn
    /// @param amount Amount withdrawn
    event EmergencyWithdraw(address token, uint256 amount);

    /// @notice Address of base token in pair
    address public immutable baseToken;
    /// @notice Address of quote token in pair
    address public immutable quoteToken;

    /// @notice Current swap fee (in basis points)
    uint96 public swapFee;
    /// @notice Maximum allowed fee (in basis points)
    uint256 public constant MAX_FEE = 1000;
    /// @notice Minimum liquidity to prevent division by zero
    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    /// @notice Tolerance for amount ratio checks (in basis points)
    uint256 private constant AMOUNT_TOLERANCE = 100;
    /// @notice Maximum token amount to prevent overflow
    uint256 public constant MAX_TOKEN_AMOUNT = type(uint128).max;

    /// @notice Tracked balance of base token
    uint128 private _trackedBaseBalance;
    /// @notice Tracked balance of quote token
    uint128 private _trackedQuoteBalance;

    /// @notice Creates a new DEX pair
    /// @param _baseToken Address of base token
    /// @param _quoteToken Address of quote token
    /// @param _initialFee Initial swap fee in basis points
    /// @param _admin Address of admin
    constructor(
        address _baseToken,
        address _quoteToken,
        uint256 _initialFee,
        address _admin
    )
        ERC20(
            string.concat(IERC20Metadata(_baseToken).symbol(), "/", IERC20Metadata(_quoteToken).symbol(), " PAIR"),
            string.concat(IERC20Metadata(_baseToken).symbol(), "-", IERC20Metadata(_quoteToken).symbol(), "-P")
        )
        ERC20Permit(string.concat(IERC20Metadata(_baseToken).symbol(), "/", IERC20Metadata(_quoteToken).symbol(), " PAIR"))
    {
        if (_baseToken == _quoteToken) {
            revert InvalidInput("Same token address");
        }
        if (_initialFee > MAX_FEE) {
            revert InvalidInput("Fee too high");
        }
        if (_initialFee == 0) {
            revert InvalidInput("Zero fee");
        }

        uint8 baseDecimals = ERC20Permit(_baseToken).decimals();
        uint8 quoteDecimals = ERC20Permit(_quoteToken).decimals();
        if (baseDecimals != quoteDecimals) {
            revert InvalidInput("Token decimals mismatch");
        }

        baseToken = _baseToken;
        quoteToken = _quoteToken;
        swapFee = uint96(_initialFee);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    /// @notice Pauses all swap and liquidity operations
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses all swap and liquidity operations
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Updates the swap fee
    /// @param _newFee New fee value in basis points
    function setFee(uint256 _newFee) external onlyRole(ADMIN_ROLE) {
        if (_newFee == 0) revert InvalidInput("Zero fee");
        emit FeeUpdated(swapFee, _newFee);
        swapFee = uint96(_newFee);
    }

    /// @notice Gets current base token balance
    /// @return Current tracked balance of base token
    function getBaseTokenBalance() public view returns (uint256) {
        return _trackedBaseBalance;
    }

    /// @notice Gets current quote token balance
    /// @return Current tracked balance of quote token
    function getQuoteTokenBalance() public view returns (uint256) {
        return _trackedQuoteBalance;
    }

    /// @notice Adds liquidity to the pool
    /// @param baseAmount Amount of base token to add
    /// @param quoteAmount Amount of quote token to add
    /// @return Amount of PAIR tokens minted
    function addLiquidity(uint256 baseAmount, uint256 quoteAmount) public nonReentrant returns (uint256) {
        if (baseAmount > MAX_TOKEN_AMOUNT || quoteAmount > MAX_TOKEN_AMOUNT) {
            revert InvalidInput("Amount exceeds maximum");
        }

        uint256 _liquidity;
        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        if (baseBalance == 0 && quoteBalance == 0) {
            _liquidity = Math.sqrt(baseAmount * quoteAmount);
            if (_liquidity <= MINIMUM_LIQUIDITY) {
                revert InvalidOperation("Insufficient liquidity");
            }

            // Effects before interactions
            _mint(address(1), MINIMUM_LIQUIDITY);
            _mint(msg.sender, _liquidity - MINIMUM_LIQUIDITY);
            emit Mint(msg.sender, baseAmount, quoteAmount, _liquidity - MINIMUM_LIQUIDITY);

            // Interactions last
            IERC20(baseToken).safeTransferFrom(msg.sender, address(this), baseAmount);
            IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), quoteAmount);
        } else {
            if (baseBalance == 0 || quoteBalance == 0) {
                revert InvalidOperation("Invalid reserves");
            }

            uint256 expectedQuoteAmount = (baseAmount * quoteBalance) / baseBalance;
            uint256 lowerBound = (expectedQuoteAmount * (10_000 - AMOUNT_TOLERANCE)) / 10_000;
            uint256 upperBound = (expectedQuoteAmount * (10_000 + AMOUNT_TOLERANCE)) / 10_000;

            if (quoteAmount < lowerBound || quoteAmount > upperBound) {
                revert InvalidInput("Amount ratio mismatch");
            }

            _liquidity = (totalSupply() * baseAmount) / baseBalance;
            if (_liquidity == 0) revert InvalidOperation("Insufficient liquidity");

            // Effects before interactions
            _mint(msg.sender, _liquidity);
            emit Mint(msg.sender, baseAmount, quoteAmount, _liquidity);

            // Interactions last
            IERC20(baseToken).safeTransferFrom(msg.sender, address(this), baseAmount);
            IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), quoteAmount);
        }
        _trackedBaseBalance += uint128(baseAmount);
        _trackedQuoteBalance += uint128(quoteAmount);
        return _liquidity;
    }

    /// @notice Removes liquidity from the pool
    /// @param amount Amount of PAIR tokens to burn
    /// @param minBaseAmount Minimum base token amount to receive
    /// @param minQuoteAmount Minimum quote token amount to receive
    /// @param deadline Block number deadline for transaction
    /// @return baseAmount Amount of base tokens received
    /// @return quoteAmount Amount of quote tokens received
    function removeLiquidity(
        uint256 amount,
        uint256 minBaseAmount,
        uint256 minQuoteAmount,
        uint256 deadline
    )
        public
        whenNotPaused
        nonReentrant
        returns (uint256, uint256)
    {
        requireValidBalances();
        if (block.number > deadline) revert InvalidOperation("Deadline expired");
        if (amount == 0) revert InvalidInput("Zero amount");

        uint256 _totalSupply = totalSupply();
        uint256 baseAmount = (amount * getBaseTokenBalance()) / _totalSupply;
        uint256 quoteAmount = (amount * getQuoteTokenBalance()) / _totalSupply;

        if (baseAmount < minBaseAmount || quoteAmount < minQuoteAmount) revert InvalidOperation("Slippage exceeded");

        // Effects before interactions
        _burn(msg.sender, amount);
        emit Burn(msg.sender, baseAmount, quoteAmount, msg.sender, amount);

        // Interactions last
        IERC20(baseToken).safeTransfer(msg.sender, baseAmount);
        IERC20(quoteToken).safeTransfer(msg.sender, quoteAmount);

        _trackedBaseBalance -= uint128(baseAmount);
        _trackedQuoteBalance -= uint128(quoteAmount);

        return (baseAmount, quoteAmount);
    }

    /// @notice Calculates output amount for a swap
    /// @param inputAmount Amount of input token
    /// @param inputReserve Current reserve of input token
    /// @param outputReserve Current reserve of output token
    /// @return Amount of output tokens
    function getAmountOfTokens(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    )
        public
        view
        returns (uint256)
    {
        if (inputReserve == 0 || outputReserve == 0) revert InvalidOperation("Invalid reserves");
        if (inputAmount == 0) revert InvalidInput("Zero amount");

        unchecked {
            uint256 inputAmountWithFee = inputAmount * (10_000 - swapFee);
            uint256 numerator = inputAmountWithFee * outputReserve;
            uint256 denominator = (inputReserve * 10_000) + inputAmountWithFee;
            return numerator / denominator;
        }
    }

    /// @notice Swaps base token for quote token
    /// @param baseAmount Amount of base token to swap
    /// @param minQuoteAmount Minimum quote token amount to receive
    /// @param deadline Block number deadline for transaction
    function swapBaseToQuote(
        uint256 baseAmount,
        uint256 minQuoteAmount,
        uint256 deadline
    )
        public
        whenNotPaused
        nonReentrant
    {
        requireValidBalances();
        uint256 initialBalance = getBaseTokenBalance();
        uint256 maxSwapAmount = (initialBalance * 3) / 100;
        if (baseAmount > maxSwapAmount) {
            revert InvalidOperation("Swap amount too large");
        }
        if (block.number > deadline) revert InvalidOperation("Deadline expired");
        if (baseAmount == 0) revert InvalidInput("Zero amount");

        uint256 quoteBought = getAmountOfTokens(baseAmount, getBaseTokenBalance(), getQuoteTokenBalance());

        if (quoteBought < minQuoteAmount) revert InvalidOperation("Slippage exceeded");

        // Effects before interactions
        emit Swap(msg.sender, baseAmount, 0, 0, quoteBought, msg.sender);

        // Interactions last
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), baseAmount);
        _trackedBaseBalance += uint128(baseAmount);
        IERC20(quoteToken).safeTransfer(msg.sender, quoteBought);
        _trackedQuoteBalance -= uint128(quoteBought);
    }

    /// @notice Swaps quote token for base token
    /// @param quoteAmount Amount of quote token to swap
    /// @param minBaseAmount Minimum base token amount to receive
    /// @param deadline Block number deadline for transaction
    function swapQuoteToBase(
        uint256 quoteAmount,
        uint256 minBaseAmount,
        uint256 deadline
    )
        public
        whenNotPaused
        nonReentrant
    {
        requireValidBalances();
        if (block.number > deadline) revert InvalidOperation("Deadline expired");
        if (quoteAmount == 0) revert InvalidInput("Zero amount");

        uint256 baseBought = getAmountOfTokens(quoteAmount, getQuoteTokenBalance(), getBaseTokenBalance());

        if (baseBought < minBaseAmount) revert InvalidOperation("Slippage exceeded");

        // Effects before interactions
        emit Swap(msg.sender, 0, quoteAmount, baseBought, 0, msg.sender);

        // Interactions last
        IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), quoteAmount);
        _trackedQuoteBalance += uint128(quoteAmount);
        IERC20(baseToken).safeTransfer(msg.sender, baseBought);
        _trackedBaseBalance -= uint128(baseBought);
    }

    /// @notice Emergency withdrawal of tokens
    /// @param token Address of token to withdraw
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(ADMIN_ROLE) nonReentrant {
        if (token == address(0)) {
            revert InvalidInput("Zero address");
        }
        if (amount == 0) {
            revert InvalidInput("Zero amount");
        }
        if (amount > IERC20(token).balanceOf(address(this))) {
            revert InvalidOperation("Insufficient balance");
        }

        // Update tracked balances
        if (token == baseToken) {
            _trackedBaseBalance -= uint128(amount);
        } else if (token == quoteToken) {
            _trackedQuoteBalance -= uint128(amount);
        }

        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(token, amount);
    }

    /// @notice Calculates quote token output for base token input
    /// @param baseAmount Amount of base token input
    /// @return Amount of quote tokens output
    function getBaseToQuotePrice(uint256 baseAmount) external view returns (uint256) {
        return _getPrice(baseAmount, true);
    }

    /// @notice Calculates base token output for quote token input
    /// @param quoteAmount Amount of quote token input
    /// @return Amount of base tokens output
    function getQuoteToBasePrice(uint256 quoteAmount) external view returns (uint256) {
        return _getPrice(quoteAmount, false);
    }

    /// @notice Verifies that tracked balances match actual balances
    /// @return True if balances match within tolerance
    function verifyBalances() public view returns (bool) {
        // Check cheaper operation first
        if (_trackedBaseBalance == 0) return false;

        uint256 baseBalance = IERC20(baseToken).balanceOf(address(this));
        if (_abs(baseBalance, _trackedBaseBalance) > AMOUNT_TOLERANCE) return false;

        uint256 quoteBalance = IERC20(quoteToken).balanceOf(address(this));
        return _abs(quoteBalance, _trackedQuoteBalance) <= AMOUNT_TOLERANCE;
    }

    /// @notice Requires that balances are valid
    function requireValidBalances() internal view {
        if (!verifyBalances()) revert InvalidOperation("Balance mismatch");
    }

    /// @notice Calculates absolute difference between two numbers
    /// @param a First number
    /// @param b Second number
    /// @return Absolute difference
    function _abs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a - b : b - a;
    }

    function _getPrice(uint256 amount, bool isBase) private view returns (uint256) {
        uint256 inputBalance = isBase ? getBaseTokenBalance() : getQuoteTokenBalance();
        uint256 outputBalance = isBase ? getQuoteTokenBalance() : getBaseTokenBalance();

        if (inputBalance == 0 || outputBalance == 0) revert InvalidOperation("Invalid reserves");
        if (amount == 0) revert InvalidInput("Zero amount");

        return getAmountOfTokens(amount, inputBalance, outputBalance);
    }
}

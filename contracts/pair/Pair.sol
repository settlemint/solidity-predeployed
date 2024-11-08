// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Dex
/// @notice Implements an automated market maker DEX for ERC20 token pairs
/// @dev Extends ERC20 for liquidity tokens and includes access control, pausability and reentrancy protection
contract Pair is ERC20, ERC20Permit, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role identifier for administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    /// @notice Role identifier for fee setters
    bytes32 public constant FEE_SETTER_ROLE = keccak256("FEE_SETTER_ROLE");
    /// @notice Role identifier for emergency withdrawers
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /// @notice Thrown when same token address is used for both tokens
    error SameTokenAddress(address token);
    /// @notice Thrown when reserves are invalid (zero)
    error InvalidReserves();
    /// @notice Thrown when provided amount ratio doesn't match expected
    error AmountRatioMismatch(uint256 provided, uint256 expected);
    /// @notice Thrown when amount is zero
    error ZeroAmount();
    /// @notice Thrown when insufficient liquidity would be minted
    error InsufficientLiquidityMinted();
    /// @notice Thrown when token amount is invalid
    error InvalidTokenAmount(uint256 amount);
    /// @notice Thrown when fee is invalid (zero)
    error InvalidFee(uint256 fee);
    /// @notice Thrown when fee exceeds maximum
    error FeeTooHigh(uint256 fee);
    /// @notice Thrown when deadline has expired
    error DeadlineExpired();
    /// @notice Thrown when slippage tolerance is exceeded
    error SlippageExceeded();
    /// @notice Thrown when zero address is provided
    error ZeroAddress();
    /// @notice Thrown when token is not a valid ERC20
    error InvalidERC20();
    /// @notice Thrown when token decimals don't match
    error TokenDecimalsMismatch();
    /// @notice Thrown when token amount exceeds maximum
    error MaxTokenAmountExceeded();
    /// @notice Thrown when tracked balances don't match actual balances
    error BalanceMismatch();
    /// @notice Thrown when swap amount is too large relative to reserves
    error SwapAmountTooLarge(uint256 amount, uint256 maxAmount);
    /// @notice Thrown when caller is not timelock contract
    error UnauthorizedTimelock();
    /// @notice Thrown when amount is invalid (zero)
    error InvalidAmount();
    /// @notice Thrown when balance is insufficient
    error InsufficientBalance();

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
    event Swap(address indexed sender, uint256 baseAmountIn, uint256 quoteAmountIn, uint256 baseAmountOut, uint256 quoteAmountOut, address indexed to);

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
    /// @notice Address of timelock controller
    TimelockController public immutable timelock;

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
    ) ERC20(
        string.concat(
            IERC20Metadata(_baseToken).symbol(),
            "/",
            IERC20Metadata(_quoteToken).symbol(),
            " PAIR"
        ),
        string.concat(
            IERC20Metadata(_baseToken).symbol(),
            "-",
            IERC20Metadata(_quoteToken).symbol(),
            "-PAIR"
        )
    ) ERC20Permit(
        string.concat(
            IERC20Metadata(_baseToken).symbol(),
            "/",
            IERC20Metadata(_quoteToken).symbol(),
            " PAIR"
        )
    ) {
        if (_baseToken == address(0) || _quoteToken == address(0)) revert ZeroAddress();
        if (_baseToken == _quoteToken) revert SameTokenAddress(_baseToken);
        if (_initialFee > MAX_FEE) revert FeeTooHigh(_initialFee);
        if (_initialFee == 0) revert InvalidFee(_initialFee);

        try IERC20(_baseToken).totalSupply() {} catch { revert InvalidERC20(); }
        try IERC20(_quoteToken).totalSupply() {} catch { revert InvalidERC20(); }

        uint8 baseDecimals = ERC20Permit(_baseToken).decimals();
        uint8 quoteDecimals = ERC20Permit(_quoteToken).decimals();
        if (baseDecimals != quoteDecimals) revert TokenDecimalsMismatch();

        baseToken = _baseToken;
        quoteToken = _quoteToken;
        swapFee = uint96(_initialFee);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(FEE_SETTER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = _admin;
        executors[0] = _admin;
        timelock = new TimelockController(2 days, proposers, executors, _admin);
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
    function setFee(uint256 _newFee) external {
        if (msg.sender != address(timelock)) revert UnauthorizedTimelock();
        if (_newFee == 0) revert InvalidFee(_newFee);
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
        if (baseAmount > MAX_TOKEN_AMOUNT || quoteAmount > MAX_TOKEN_AMOUNT)
            revert MaxTokenAmountExceeded();

        uint256 _liquidity;
        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        if (baseBalance == 0 && quoteBalance == 0) {
            _liquidity = Math.sqrt(baseAmount * quoteAmount);
            if (_liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();

            // Effects before interactions
            _mint(address(1), MINIMUM_LIQUIDITY);
            _mint(msg.sender, _liquidity - MINIMUM_LIQUIDITY);
            emit Mint(msg.sender, baseAmount, quoteAmount, _liquidity - MINIMUM_LIQUIDITY);

            // Interactions last
            IERC20(baseToken).safeTransferFrom(msg.sender, address(this), baseAmount);
            IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), quoteAmount);
        } else {
            if (baseBalance == 0 || quoteBalance == 0) revert InvalidReserves();

            uint256 expectedQuoteAmount = (baseAmount * quoteBalance) / baseBalance;
            uint256 lowerBound = (expectedQuoteAmount * (10000 - AMOUNT_TOLERANCE)) / 10000;
            uint256 upperBound = (expectedQuoteAmount * (10000 + AMOUNT_TOLERANCE)) / 10000;

            if (quoteAmount < lowerBound || quoteAmount > upperBound) {
                revert AmountRatioMismatch(quoteAmount, expectedQuoteAmount);
            }

            _liquidity = (totalSupply() * baseAmount) / baseBalance;
            if (_liquidity == 0) revert InsufficientLiquidityMinted();

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
    ) public nonReentrant whenNotPaused returns (uint256, uint256) {
        requireValidBalances();
        if (block.number > deadline) revert DeadlineExpired();
        if (amount == 0) revert ZeroAmount();

        uint256 _totalSupply = totalSupply();
        uint256 baseAmount = (amount * getBaseTokenBalance()) / _totalSupply;
        uint256 quoteAmount = (amount * getQuoteTokenBalance()) / _totalSupply;

        if (baseAmount < minBaseAmount || quoteAmount < minQuoteAmount) revert SlippageExceeded();

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
    ) public view returns (uint256) {
        if (inputReserve == 0 || outputReserve == 0) revert InvalidReserves();
        if (inputAmount == 0) revert InvalidTokenAmount(inputAmount);

        unchecked {
            uint256 inputAmountWithFee = inputAmount * (10000 - swapFee);
            uint256 numerator = inputAmountWithFee * outputReserve;
            uint256 denominator = (inputReserve * 10000) + inputAmountWithFee;
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
    ) public nonReentrant whenNotPaused {
        requireValidBalances();
        uint256 initialBalance = getBaseTokenBalance();
        uint256 maxSwapAmount = (initialBalance * 3) / 100;
        if (baseAmount > maxSwapAmount) {
            revert SwapAmountTooLarge(baseAmount, maxSwapAmount);
        }
        if (block.number > deadline) revert DeadlineExpired();
        if (baseAmount == 0) revert InvalidTokenAmount(baseAmount);

        uint256 quoteBought = getAmountOfTokens(
            baseAmount,
            getBaseTokenBalance(),
            getQuoteTokenBalance()
        );

        if (quoteBought < minQuoteAmount) revert SlippageExceeded();

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
    ) public nonReentrant whenNotPaused {
        requireValidBalances();
        if (block.number > deadline) revert DeadlineExpired();
        if (quoteAmount == 0) revert InvalidTokenAmount(quoteAmount);

        uint256 baseBought = getAmountOfTokens(
            quoteAmount,
            getQuoteTokenBalance(),
            getBaseTokenBalance()
        );

        if (baseBought < minBaseAmount) revert SlippageExceeded();

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

    /// @notice Calculates quote token output for base token input
    /// @param baseAmount Amount of base token input
    /// @return Amount of quote tokens output
    function getBaseToQuotePrice(uint256 baseAmount) external view returns (uint256) {
        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        if (baseBalance == 0 || quoteBalance == 0) revert InvalidReserves();
        if (baseAmount == 0) revert InvalidTokenAmount(0);

        return getAmountOfTokens(
            baseAmount,
            baseBalance,
            quoteBalance
        );
    }

    /// @notice Calculates base token output for quote token input
    /// @param quoteAmount Amount of quote token input
    /// @return Amount of base tokens output
    function getQuoteToBasePrice(uint256 quoteAmount) external view returns (uint256) {
        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        if (baseBalance == 0 || quoteBalance == 0) revert InvalidReserves();
        if (quoteAmount == 0) revert InvalidTokenAmount(0);

        return getAmountOfTokens(
            quoteAmount,
            quoteBalance,
            baseBalance
        );
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
        if (!verifyBalances()) revert BalanceMismatch();
    }

    /// @notice Calculates absolute difference between two numbers
    /// @param a First number
    /// @param b Second number
    /// @return Absolute difference
    function _abs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a - b : b - a;
    }
}

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

/// @notice This contract implements a constant product automated market maker (AMM) where the product
/// of the two token reserves remains constant after each trade (x * y = k). When adding or removing
/// liquidity, the ratio of tokens must match the current price ratio to maintain price stability.
contract StarterKitERC20Dex is ERC20, ERC20Permit, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FEE_SETTER_ROLE = keccak256("FEE_SETTER_ROLE");

    error SameTokenAddress(address token);
    error InvalidReserves();
    error AmountRatioMismatch(uint256 provided, uint256 expected);
    error ZeroAmount();
    error InsufficientLiquidityMinted();
    error InvalidTokenAmount(uint256 amount);
    error InvalidFee(uint256 fee);
    error FeeTooHigh(uint256 fee);
    error DeadlineExpired();
    error SlippageExceeded();
    error ZeroAddress();
    error InvalidERC20();
    error TokenDecimalsMismatch();
    error MaxTokenAmountExceeded();
    error BalanceMismatch();
    error SwapAmountTooLarge(uint256 amount, uint256 maxAmount);
    error UnauthorizedTimelock();

    event Mint(address indexed sender, uint256 baseAmount, uint256 quoteAmount, uint256 liquidity);
    event Burn(address indexed sender, uint256 baseAmount, uint256 quoteAmount, address indexed to, uint256 liquidity);
    event Swap(
        address indexed sender,
        uint256 baseAmountIn,
        uint256 quoteAmountIn,
        uint256 baseAmountOut,
        uint256 quoteAmountOut,
        address indexed to
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event EmergencyWithdraw(address token, uint256 amount);

    address public immutable baseToken;
    address public immutable quoteToken;
    TimelockController public immutable timelock;

    /// @notice Fee charged on swaps, denominated in basis points (1/10th of a percent)
    /// @dev Basis points are used instead of percentages to avoid floating point arithmetic,
    /// which is error-prone and gas-intensive in Solidity. 1 basis point = 0.01%
    uint256 public swapFeeInBasisPoints;
    /// @notice Maximum allowed swap amount as a percentage of total reserves
    /// @dev This limit prevents large trades that could significantly impact price or drain the pool.
    /// The value 30 represents 3% (30/1000) of the pool's reserves as the maximum single swap size.
    uint256 public constant MAX_SWAP_AMOUNT_IN_BASIS_POINTS = 30;
    /// @notice Denominator used for basis point calculations (1000 = 100%)
    /// @dev Using basis points with integer math provides precise fee calculations while
    /// avoiding floating point operations. The denominator of 1000 allows for fees to be
    /// specified with 0.1% granularity (e.g. 5 = 0.5%, 10 = 1%)
    uint256 public constant BASIS_POINTS_DENOMINATOR = 1000;
    /// @notice Minimum liquidity that must be maintained in the pool to prevent manipulation
    /// @dev This minimum liquidity is permanently locked in the pool and can never be withdrawn.
    /// It prevents the first liquidity provider from manipulating prices by withdrawing almost
    /// all liquidity, which would make the pool's reserves extremely small. With very small
    /// reserves, tiny trades could cause massive price swings. The locked minimum liquidity
    /// ensures there's always some baseline reserves to maintain price stability.
    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    /// @notice Maximum allowed difference between tracked and actual token balances based on BASIS_POINTS_DENOMINATOR
    /// @dev Value of 100 represents 10% of BASIS_POINTS_DENOMINATOR (1000), allowing for a 10% tolerance in balance
    /// tracking
    uint256 private constant AMOUNT_TOLERANCE = 100;
    /// @notice Maximum token amount that can be used in a single operation
    uint256 public constant MAX_TOKEN_AMOUNT = type(uint128).max;

    uint256 private _trackedBaseBalance;
    uint256 private _trackedQuoteBalance;

    /// @notice Initializes the DEX contract with base and quote tokens, initial fee, and admin
    /// @dev Sets up the DEX with token pair, fee structure, and admin roles. Also creates a timelock controller.
    /// @param _baseToken The address of the base token for the trading pair
    /// @param _quoteToken The address of the quote token for the trading pair
    /// @param _initialFeeInBasisPoints The initial swap fee in basis points (1 basis point = 0.01%)
    /// @param _admin The address that will be granted admin roles
    constructor(
        address _baseToken,
        address _quoteToken,
        uint256 _initialFeeInBasisPoints,
        address _admin
    )
        ERC20(
            string.concat(IERC20Metadata(_baseToken).symbol(), "/", IERC20Metadata(_quoteToken).symbol(), " LP"),
            string.concat(IERC20Metadata(_baseToken).symbol(), "-", IERC20Metadata(_quoteToken).symbol(), "-LP")
        )
        ERC20Permit(string.concat(IERC20Metadata(_baseToken).symbol(), "/", IERC20Metadata(_quoteToken).symbol(), " LP"))
    {
        if (_baseToken == address(0) || _quoteToken == address(0)) revert ZeroAddress();
        if (_baseToken == _quoteToken) revert SameTokenAddress(_baseToken);
        if (_initialFeeInBasisPoints > BASIS_POINTS_DENOMINATOR) revert FeeTooHigh(_initialFeeInBasisPoints);
        if (_initialFeeInBasisPoints == 0) revert InvalidFee(_initialFeeInBasisPoints);

        try IERC20(_baseToken).totalSupply() { }
        catch {
            revert InvalidERC20();
        }
        try IERC20(_quoteToken).totalSupply() { }
        catch {
            revert InvalidERC20();
        }

        uint8 baseDecimals = ERC20Permit(_baseToken).decimals();
        uint8 quoteDecimals = ERC20Permit(_quoteToken).decimals();
        if (baseDecimals != quoteDecimals) revert TokenDecimalsMismatch();

        baseToken = _baseToken;
        quoteToken = _quoteToken;
        swapFeeInBasisPoints = _initialFeeInBasisPoints;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(FEE_SETTER_ROLE, _admin);

        // Create a new TimelockController contract that adds a 2-day delay to certain administrative actions (like fee
        // changes).
        // Sets up the admin as both a proposer and executor of delayed actions. This is a security feature that
        // prevents
        // immediate changes to sensitive parameters, giving users time to react to proposed changes.
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = _admin;
        executors[0] = _admin;
        timelock = new TimelockController(2 days, proposers, executors, _admin);
    }

    /// @notice Pauses all token transfers and swaps
    /// @dev Can only be called by accounts with ADMIN_ROLE
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses all token transfers and swaps
    /// @dev Can only be called by accounts with ADMIN_ROLE
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Updates the swap fee for the DEX
    /// @dev Can only be called by the timelock contract to ensure fee changes are time-delayed
    /// @param _newFeeInBasisPoints The new fee value in basis points (1 basis point = 0.01%)
    /// @custom:throws UnauthorizedTimelock if caller is not the timelock contract
    /// @custom:throws InvalidFee if the new fee is 0
    /// @custom:throws FeeTooHigh if the new fee exceeds BASIS_POINTS_DENOMINATOR
    function setFee(uint256 _newFeeInBasisPoints) external {
        if (msg.sender != address(timelock)) revert UnauthorizedTimelock();
        if (_newFeeInBasisPoints == 0) revert InvalidFee(_newFeeInBasisPoints);
        if (_newFeeInBasisPoints > BASIS_POINTS_DENOMINATOR) revert FeeTooHigh(_newFeeInBasisPoints);
        emit FeeUpdated(swapFeeInBasisPoints, _newFeeInBasisPoints);
        swapFeeInBasisPoints = _newFeeInBasisPoints;
    }

    /// @notice Returns the current tracked balance of the base token in the DEX
    /// @return The amount of base tokens currently held by the DEX
    function getBaseTokenBalance() public view returns (uint256) {
        return _trackedBaseBalance;
    }

    /// @notice Returns the current tracked balance of the quote token in the DEX
    /// @return The amount of quote tokens currently held by the DEX
    function getQuoteTokenBalance() public view returns (uint256) {
        return _trackedQuoteBalance;
    }

    /// @notice Adds liquidity to the DEX by depositing base and quote tokens
    /// @dev Handles both initial liquidity provision and subsequent additions
    /// @param baseAmount Amount of base tokens to add as liquidity
    /// @param quoteAmount Amount of quote tokens to add as liquidity
    /// @return Amount of LP tokens minted to the provider
    function addLiquidity(uint256 baseAmount, uint256 quoteAmount) public nonReentrant returns (uint256) {
        // Check for zero amounts
        if (baseAmount == 0 || quoteAmount == 0) {
            revert ZeroAmount();
        }

        // Check if amounts exceed maximum allowed token amounts
        if (baseAmount > MAX_TOKEN_AMOUNT || quoteAmount > MAX_TOKEN_AMOUNT) {
            revert MaxTokenAmountExceeded();
        }

        uint256 _liquidity;
        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        // Handle initial liquidity provision when pool is empty
        if (baseBalance == 0 && quoteBalance == 0) {
            // Calculate initial LP tokens as sqrt of token amounts product
            _liquidity = Math.sqrt(baseAmount * quoteAmount);
            if (_liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();

            // Effects: Mint minimum liquidity to address(1) to prevent first LP token from having too much power
            // Then mint remaining LP tokens to provider
            _mint(address(1), MINIMUM_LIQUIDITY);
            _mint(msg.sender, _liquidity - MINIMUM_LIQUIDITY);
            emit Mint(msg.sender, baseAmount, quoteAmount, _liquidity - MINIMUM_LIQUIDITY);

            // Interactions: Transfer tokens from provider to DEX
            IERC20(baseToken).safeTransferFrom(msg.sender, address(this), baseAmount);
            IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), quoteAmount);
        }
        // Handle subsequent liquidity additions
        else {
            // Ensure both reserves are non-zero
            if (baseBalance == 0 || quoteBalance == 0) revert InvalidReserves();

            // Calculate expected quote amount based on current ratio
            // This maintains the price ratio when adding liquidity
            // Derivation from price ratio equality formula:
            // 1. baseAmount/baseBalance = quoteAmount/quoteBalance (ratio equality)
            // 2. Cross multiply to eliminate fractions:
            //    baseAmount * quoteBalance = baseBalance * quoteAmount
            // 3. Solve for quoteAmount:
            //    quoteAmount = (baseAmount * quoteBalance) / baseBalance
            uint256 expectedQuoteAmount = (baseAmount * quoteBalance) / baseBalance;

            // Calculate acceptable range using AMOUNT_TOLERANCE
            uint256 lowerBound =
                (expectedQuoteAmount * (BASE_POINTS_DENOMINATOR - AMOUNT_TOLERANCE)) / BASE_POINTS_DENOMINATOR;
            uint256 upperBound =
                (expectedQuoteAmount * (BASE_POINTS_DENOMINATOR + AMOUNT_TOLERANCE)) / BASE_POINTS_DENOMINATOR;

            // Ensure provided quote amount maintains price ratio within tolerance
            if (quoteAmount < lowerBound || quoteAmount > upperBound) {
                revert AmountRatioMismatch(quoteAmount, expectedQuoteAmount);
            }

            // Calculate LP tokens to mint proportional to contribution
            // Formula: new_LP_tokens = (total_LP_supply * new_base_tokens) / total_base_tokens
            // This maintains proportional ownership - if you contribute x% of current assets,
            // you get x% of new LP tokens
            // Derivation:
            // 1. Each LP token should represent same proportion of pool
            // 2. If you contribute x% of current assets, you should get x% of new LP tokens
            // 3. Therefore, since all ratios should be equal:
            //    new_LP_tokens/total_LP_supply = baseAmount/baseBalance = quoteAmount/quoteBalance
            // 4. Solving for new_LP_tokens gives us this formula (we use base because it's more accurate)
            _liquidity = (totalSupply() * baseAmount) / baseBalance;
            if (_liquidity == 0) revert InsufficientLiquidityMinted();

            // Effects: Mint LP tokens to provider
            _mint(msg.sender, _liquidity);
            emit Mint(msg.sender, baseAmount, quoteAmount, _liquidity);

            // Interactions: Transfer tokens from provider to DEX
            IERC20(baseToken).safeTransferFrom(msg.sender, address(this), baseAmount);
            IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), quoteAmount);
        }

        // Update tracked balances
        _trackedBaseBalance += baseAmount;
        _trackedQuoteBalance += quoteAmount;
        return _liquidity;
    }

    /// @notice Removes liquidity from the pool by burning LP tokens and receiving base and quote tokens
    /// @dev Burns LP tokens and returns proportional amounts of base and quote tokens to the provider
    /// @param amount The amount of LP tokens to burn
    /// @param minBaseAmount The minimum amount of base tokens that must be received
    /// @param minQuoteAmount The minimum amount of quote tokens that must be received
    /// @param deadline The block number by which this transaction must be executed
    /// @return Returns a tuple of the base and quote token amounts withdrawn
    function removeLiquidity(
        uint256 amount,
        uint256 minBaseAmount,
        uint256 minQuoteAmount,
        uint256 deadline
    )
        public
        nonReentrant
        whenNotPaused
        returns (uint256, uint256)
    {
        requireValidBalances();
        if (block.number > deadline) revert DeadlineExpired();
        if (amount == 0) revert ZeroAmount();

        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        // Calculate base and quote amounts based on share of total supply
        uint256 _totalSupply = totalSupply();
        uint256 baseAmount = (amount * baseBalance) / _totalSupply;
        uint256 quoteAmount = (amount * quoteBalance) / _totalSupply;

        if (baseAmount < minBaseAmount || quoteAmount < minQuoteAmount) revert SlippageExceeded();

        // Check that remaining liquidity maintains minimum sqrt(k) requirement
        uint256 remainingBaseBalance = baseBalance - baseAmount;
        uint256 remainingQuoteBalance = quoteBalance - quoteAmount;
        uint256 k = Math.sqrt(remainingBaseBalance * remainingQuoteBalance);
        if (k < MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();

        // Effects before interactions
        _burn(msg.sender, amount);
        emit Burn(msg.sender, baseAmount, quoteAmount, msg.sender, amount);

        // Interactions last
        IERC20(baseToken).safeTransfer(msg.sender, baseAmount);
        IERC20(quoteToken).safeTransfer(msg.sender, quoteAmount);

        _trackedBaseBalance -= baseAmount;
        _trackedQuoteBalance -= quoteAmount;

        return (baseAmount, quoteAmount);
    }

    /// @notice Calculates the output amount of tokens for a given input amount and reserves
    /// @dev Uses constant product formula (k = x * y) to maintain balanced reserves,
    ///      where k is the invariant liquidity parameter and x,y are the token reserves.
    ///      The formula ensures that after any swap, the product of the reserves remains constant.
    /// @param inputAmount The amount of input tokens to swap
    /// @param inputReserve The current reserve of input tokens
    /// @param outputReserve The current reserve of output tokens
    /// @return The amount of output tokens that will be received
    function getAmountOfTokens(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    )
        public
        view
        returns (uint256)
    {
        if (inputReserve == 0 || outputReserve == 0) revert InvalidReserves();
        if (inputAmount == 0) revert ZeroAmount();

        // Calculate net input amount after the fee is deducted
        uint256 netInputAmountAfterFeeInBasisPoints = inputAmount * (BASIS_POINTS_DENOMINATOR - swapFeeInBasisPoints);

        // Calculate the numerator and denominator for the output amount
        // Based on the constant product formula: k = inputReserve * outputReserve
        // 1. The constant k (liquidity) remains the same before and after the trade:
        //    k = inputReserve * outputReserve = (inputReserve + netInputAmount) * (outputReserve - outputAmount)
        // 2. Rearrange to isolate (outputReserve - outputAmount):
        //    (inputReserve * outputReserve) / (inputReserve + netInputAmount) = outputReserve - outputAmount
        // 3. Solve for outputAmount:
        //    outputAmount = outputReserve - (inputReserve * outputReserve) / (inputReserve + netInputAmount)
        // 4. Multiply both sides by (inputReserve + netInputAmount) to eliminate the denominator:
        //    outputAmount * (inputReserve + netInputAmount) = outputReserve * (inputReserve + netInputAmount) -
        //    inputReserve * outputReserve
        // 5. Factor out outputReserve on the right-hand side:
        //    outputAmount * (inputReserve + netInputAmount) = outputReserve * netInputAmount
        // 6. Divide both sides by (inputReserve + netInputAmount) to isolate outputAmount:
        //    outputAmount = (outputReserve * netInputAmount) / (inputReserve + netInputAmount)
        // 7. Final formula:
        //    outputAmount = (outputReserve * netInputAmount) / (inputReserve + netInputAmount)
        uint256 numerator = netInputAmountAfterFeeInBasisPoints * outputReserve;
        uint256 denominator = (inputReserve * BASIS_POINTS_DENOMINATOR) + netInputAmountAfterFeeInBasisPoints;

        unchecked {
            return numerator / denominator;
        }
    }

    /// @notice Swaps base tokens for quote tokens with slippage protection and deadline
    /// @param baseAmount Amount of base tokens to swap in, should be less than max swap amount
    /// @param minQuoteAmount Minimum amount of quote tokens expected out to protect against slippage
    /// @param deadline Block number by which swap must execute to prevent stale transactions
    function swapBaseToQuote(
        uint256 baseAmount,
        uint256 minQuoteAmount,
        uint256 deadline
    )
        public
        nonReentrant
        whenNotPaused
    {
        if (baseAmount == 0) revert ZeroAmount();
        if (block.number > deadline) revert DeadlineExpired();
        requireValidBalances();

        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        // Limit swap size to prevent price manipulation and excessive slippage by restricting
        // trades to a small percentage of total pool liquidity
        uint256 maxSwapAmount = (baseBalance * MAX_SWAP_AMOUNT_IN_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        if (baseAmount > maxSwapAmount) {
            revert SwapAmountTooLarge(baseAmount, maxSwapAmount);
        }

        uint256 quoteBought = getAmountOfTokens(baseAmount, baseBalance, quoteBalance);

        // check for zero output amount, this can happen if the swap amount is too large and rounding issues
        if (quoteBought == 0) revert InvalidTokenAmount(quoteBought);
        if (quoteBought < minQuoteAmount) revert SlippageExceeded();

        // Effects before interactions
        emit Swap(msg.sender, baseAmount, 0, 0, quoteBought, msg.sender);

        // Interactions last
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), baseAmount);
        _trackedBaseBalance += baseAmount;
        IERC20(quoteToken).safeTransfer(msg.sender, quoteBought);
        _trackedQuoteBalance -= quoteBought;
    }

    /// @notice Swaps quote tokens for base tokens with slippage protection and deadline
    /// @param quoteAmount Amount of quote tokens to swap in, should be less than max swap amount
    /// @param minBaseAmount Minimum amount of base tokens expected out to protect against slippage
    /// @param deadline Block number by which swap must execute to prevent stale transactions
    function swapQuoteToBase(
        uint256 quoteAmount,
        uint256 minBaseAmount,
        uint256 deadline
    )
        public
        nonReentrant
        whenNotPaused
    {
        if (quoteAmount == 0) revert ZeroAmount();
        if (block.number > deadline) revert DeadlineExpired();
        requireValidBalances();

        uint256 quoteBalance = getQuoteTokenBalance();
        uint256 baseBalance = getBaseTokenBalance();

        // Limit swap size to prevent price manipulation and excessive slippage by restricting
        // trades to a small percentage of total pool liquidity
        uint256 maxSwapAmount = (quoteBalance * MAX_SWAP_AMOUNT_IN_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        if (quoteAmount > maxSwapAmount) {
            revert SwapAmountTooLarge(quoteAmount, maxSwapAmount);
        }

        uint256 baseBought = getAmountOfTokens(quoteAmount, quoteBalance, baseBalance);

        // check for zero output amount, this can happen if the swap amount is too large and rounding issues
        if (baseBought == 0) revert InvalidTokenAmount(baseBought);
        if (baseBought < minBaseAmount) revert SlippageExceeded();

        // Effects before interactions
        emit Swap(msg.sender, 0, quoteAmount, baseBought, 0, msg.sender);

        // Interactions last
        IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), quoteAmount);
        _trackedQuoteBalance += quoteAmount;
        IERC20(baseToken).safeTransfer(msg.sender, baseBought);
        _trackedBaseBalance -= baseBought;
    }

    function emergencyWithdraw(address token, uint256 amount) external nonReentrant onlyRole(ADMIN_ROLE) {
        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(token, amount);
    }

    // Add view function for price calculation
    function getBaseToQuotePrice(uint256 baseAmount) external view returns (uint256) {
        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        if (baseBalance == 0 || quoteBalance == 0) revert InvalidReserves();
        if (baseAmount == 0) revert InvalidTokenAmount(0);

        return getAmountOfTokens(baseAmount, baseBalance, quoteBalance);
    }

    function getQuoteToBasePrice(uint256 quoteAmount) external view returns (uint256) {
        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        if (baseBalance == 0 || quoteBalance == 0) revert InvalidReserves();
        if (quoteAmount == 0) revert InvalidTokenAmount(0);

        return getAmountOfTokens(quoteAmount, quoteBalance, baseBalance);
    }

    function verifyBalances() public view returns (bool) {
        uint256 baseBalance = IERC20(baseToken).balanceOf(address(this));
        uint256 quoteBalance = IERC20(quoteToken).balanceOf(address(this));

        return (
            _absDifference(baseBalance, _trackedBaseBalance) <= AMOUNT_TOLERANCE
                && _absDifference(quoteBalance, _trackedQuoteBalance) <= AMOUNT_TOLERANCE
        );
    }

    /// @notice Reverts if tracked balances don't match actual token balances within tolerance
    /// @dev Internal view function used as a guard against balance tracking errors
    function requireValidBalances() internal view {
        if (!verifyBalances()) revert BalanceMismatch();
    }

    /// @notice Returns the absolute difference between two uint256 values
    /// @param a First value
    /// @param b Second value
    /// @return The absolute difference |a - b|
    function _absDifference(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a - b : b - a;
    }
}

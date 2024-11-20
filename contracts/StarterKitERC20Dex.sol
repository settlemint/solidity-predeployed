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
/// @dev Only provides basic emergency withdrawal functionality by pausing the contract and allowing
/// users to liquidate their positions. More sophisticated emergency handling may be needed.
contract StarterKitERC20Dex is ERC20, ERC20Permit, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

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
    error ContractNotPaused();
    error EmergencyWithdrawAlreadyInitiated();
    error NoLiquidityToClaim();
    error ZeroTotalSupply();
    error NoFeesToCollect();
    error BelowMinimumCollectionAmount();
    error FeeCollectorNotSet();
    error EmergencyWithdrawNotInitiated();
    error InvalidToken();
    error TokenDecimalsTooHigh();
    error MaxTotalSupplyExceeded();
    error DivisionByZero();

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
    event EmergencyWithdrawInitiated(
        uint256 totalLPSupply,
        uint256 emergencyBaseBalance,
        uint256 emergencyQuoteBalance,
        uint256 trackedBaseBalance,
        uint256 trackedQuoteBalance
    );
    event EmergencyWithdrawExecuted(address indexed user, uint256 baseAmount, uint256 quoteAmount, uint256 lpBalance);
    event FeesAccrue(address indexed user, uint256 baseFee, uint256 quoteFee);
    event FeesAccrued(address indexed user, uint256 baseFeesInBasisPoints, uint256 quoteFeesInBasisPoints);
    event FeesCollected(address indexed user, uint256 baseAmount, uint256 quoteAmount);
    event ProtocolFeesCollected(uint256 baseAmount, uint256 quoteAmount);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);
    event TokenRecovered(address indexed token, uint256 amount);
    event ETHReceived(uint256 amount);

    address public immutable baseToken;
    address public immutable quoteToken;
    TimelockController public immutable timelock;

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

    /// @notice Percentage of fees that go to the protocol (10%)
    uint256 private constant PROTOCOL_FEE_SHARE_IN_BASIS_POINTS = 100;

    /// @notice Minimum amount required for fee collection
    uint256 private constant MINIMUM_COLLECTION_AMOUNT = 1000;

    /// @notice The delay period required for timelock operations
    /// @dev This constant sets a 2 day waiting period between when a timelock operation is proposed and when it can be
    /// executed
    /// This delay gives users time to react to proposed changes before they take effect
    uint256 private constant TIMELOCK_DELAY = 2 days;

    /// @notice Fee charged on swaps, denominated in basis points (1/10th of a percent)
    /// @dev Basis points are used instead of percentages to avoid floating point arithmetic,
    /// which is error-prone and gas-intensive in Solidity. 1 basis point = 0.01%
    uint256 public swapFeeInBasisPoints;

    /// @notice Flag to track if emergency withdrawal has been initiated
    bool public emergencyWithdrawInitiated;

    /// @notice track owed fees
    uint256 public protocolBaseFeesInBasisPoints;
    uint256 public protocolQuoteFeesInBasisPoints;
    mapping(address => uint256) public baseFeesOwedInBasisPoints;
    mapping(address => uint256) public quoteFeesOwedInBasisPoints;

    uint256 private _trackedBaseBalance;
    uint256 private _trackedQuoteBalance;

    /// @notice Snapshot of balances and supply when emergency was initiated
    uint256 private _emergencyTotalSupply;
    uint256 private _emergencyBaseBalance;
    uint256 private _emergencyQuoteBalance;

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
        if (baseDecimals > 18) revert TokenDecimalsTooHigh();

        baseToken = _baseToken;
        quoteToken = _quoteToken;
        swapFeeInBasisPoints = _initialFeeInBasisPoints;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);

        // Create a new TimelockController contract that adds a 2-day delay to certain administrative actions (like fee
        // changes).
        // Sets up the admin as both a proposer and executor of delayed actions. This is a security feature that
        // prevents immediate changes to sensitive parameters, giving users time to react to proposed changes.
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = _admin;
        executors[0] = _admin;
        timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, _admin);
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

    /// @notice Returns the owner of the contract
    /// @return The address of the contract owner
    function owner() public view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }

    /// @notice Allows transferring admin rights in emergency
    function transferEmergencyAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (msg.sender != address(timelock)) revert UnauthorizedTimelock();

        _revokeRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, newAdmin);
        emit AdminTransferred(msg.sender, newAdmin);
    }

    /// @notice Updates the swap fee for the DEX
    /// @dev Can only be called by the timelock contract to ensure fee changes are time-delayed
    /// @param _newFeeInBasisPoints The new fee value in basis points (1 basis point = 0.01%)
    /// @custom:throws UnauthorizedTimelock if caller is not the timelock contract
    /// @custom:throws InvalidFee if the new fee is 0
    /// @custom:throws FeeTooHigh if the new fee exceeds BASIS_POINTS_DENOMINATOR
    function setSwapFee(uint256 _newFeeInBasisPoints) external {
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
        uint256 totalSupply = totalSupply();

        // Handle initial liquidity provision when pool is empty
        if (baseBalance == 0 && quoteBalance == 0) {
            // Calculate initial LP tokens and validate minimum liquidity requirement
            _liquidity = _calculateAndVerifyLiquidity(baseAmount, quoteAmount);

            // Check total supply limit
            if (totalSupply + _liquidity > type(uint256).max - MINIMUM_LIQUIDITY) {
                revert MaxTotalSupplyExceeded();
            }

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
                (expectedQuoteAmount * (BASIS_POINTS_DENOMINATOR - AMOUNT_TOLERANCE)) / BASIS_POINTS_DENOMINATOR;
            uint256 upperBound =
                (expectedQuoteAmount * (BASIS_POINTS_DENOMINATOR + AMOUNT_TOLERANCE)) / BASIS_POINTS_DENOMINATOR;

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
            _liquidity = (totalSupply * baseAmount) / baseBalance;
            if (_liquidity == 0) revert InsufficientLiquidityMinted();

            // Check total supply limit
            if (totalSupply + _liquidity > type(uint256).max - MINIMUM_LIQUIDITY) {
                revert MaxTotalSupplyExceeded();
            }

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
        _calculateAndVerifyLiquidity(remainingBaseBalance, remainingQuoteBalance);

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

        uint256 maxSwapAmount = (baseBalance * MAX_SWAP_AMOUNT_IN_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        if (baseAmount > maxSwapAmount) {
            revert SwapAmountTooLarge(baseAmount, maxSwapAmount);
        }

        // Get net amount after fees
        (uint256 netBaseAmount,) = _handleFees(baseAmount, 0);
        uint256 quoteBought = _getAmountOfTokens(baseBalance, quoteBalance, netBaseAmount);

        if (quoteBought == 0) revert InvalidTokenAmount(quoteBought);
        if (quoteBought < minQuoteAmount) revert SlippageExceeded();

        emit Swap(msg.sender, baseAmount, 0, 0, quoteBought, msg.sender);

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

        uint256 maxSwapAmount = (quoteBalance * MAX_SWAP_AMOUNT_IN_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        if (quoteAmount > maxSwapAmount) {
            revert SwapAmountTooLarge(quoteAmount, maxSwapAmount);
        }

        // Get net amount after fees
        (, uint256 netQuoteAmount) = _handleFees(0, quoteAmount);
        uint256 baseBought = _getAmountOfTokens(quoteBalance, baseBalance, netQuoteAmount);

        if (baseBought == 0) revert InvalidTokenAmount(baseBought);
        if (baseBought < minBaseAmount) revert SlippageExceeded();

        emit Swap(msg.sender, 0, quoteAmount, baseBought, 0, msg.sender);

        IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), quoteAmount);
        _trackedQuoteBalance += quoteAmount;
        IERC20(baseToken).safeTransfer(msg.sender, baseBought);
        _trackedBaseBalance -= baseBought;
    }

    /// @notice Allows recovery of tokens that are not part of the trading pair
    /// @dev Only callable by admin role
    /// @param token The address of the token to recover (must not be base or quote token)
    function recoverUnusedTokens(address token) external nonReentrant onlyRole(ADMIN_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (token == baseToken || token == quoteToken) revert InvalidToken();

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance == 0) revert ZeroAmount();

        IERC20(token).safeTransfer(msg.sender, balance);
        emit TokenRecovered(token, balance);
    }

    /// @notice Initiates emergency shutdown and enables LP holders to withdraw their share
    /// @dev Pauses contract and snapshots current state for withdrawals
    function initiateEmergencyWithdraw() external nonReentrant onlyRole(ADMIN_ROLE) {
        if (emergencyWithdrawInitiated) revert EmergencyWithdrawAlreadyInitiated();

        uint256 totalLPSupply = totalSupply();
        if (totalLPSupply == 0) revert ZeroTotalSupply();

        // Pause all operations first
        _pause();

        // Store actual token balances rather than tracked balances
        // This ensures users can withdraw based on real token amounts in the contract
        _emergencyBaseBalance = IERC20(baseToken).balanceOf(address(this));
        _emergencyQuoteBalance = IERC20(quoteToken).balanceOf(address(this));
        _emergencyTotalSupply = totalLPSupply;

        emergencyWithdrawInitiated = true;

        emit EmergencyWithdrawInitiated(
            totalLPSupply, _emergencyBaseBalance, _emergencyQuoteBalance, _trackedBaseBalance, _trackedQuoteBalance
        );
    }

    /// @notice Allows LP holders to withdraw their proportional share of tokens
    /// @dev Uses actual token balances at emergency initiation for calculations
    function withdrawLPEmergency() external nonReentrant whenPaused {
        if (!emergencyWithdrawInitiated) revert EmergencyWithdrawNotInitiated();

        uint256 lpBalance = balanceOf(msg.sender);
        if (lpBalance == 0) revert NoLiquidityToClaim();

        // Calculate share using actual token balances from emergency initiation
        uint256 baseShare = (_emergencyBaseBalance * lpBalance) / _emergencyTotalSupply;
        uint256 quoteShare = (_emergencyQuoteBalance * lpBalance) / _emergencyTotalSupply;

        // Effects before interactions
        _burn(msg.sender, lpBalance);

        // Transfer tokens to user
        IERC20(baseToken).safeTransfer(msg.sender, baseShare);
        IERC20(quoteToken).safeTransfer(msg.sender, quoteShare);

        emit EmergencyWithdrawExecuted(msg.sender, baseShare, quoteShare, lpBalance);
    }

    /// @notice Fallback function to handle unexpected ETH sent to the contract
    /// @dev Emits ETHReceived event with the received amount
    /// @dev This is needed since the contract may receive ETH by accident or through selfdestruct
    receive() external payable {
        emit ETHReceived(msg.value);
    }

    /// @notice Allows admin to withdraw any ETH accidentally sent to the contract
    /// @dev Can only be called by accounts with ADMIN_ROLE
    /// @dev Transfers entire ETH balance to the contract owner
    function emergencyETHWithdraw() external onlyRole(ADMIN_ROLE) {
        payable(owner()).transfer(address(this).balance);
    }

    /// @notice Allows users to collect their accumulated trading fees
    /// @dev Converts fee basis points to actual token amounts and transfers them to the user
    /// @dev Requires minimum collection amounts to prevent dust transactions
    /// @dev Resets user's fee tracking after successful collection
    /// @return baseAmount The amount of base tokens collected as fees
    /// @return quoteAmount The amount of quote tokens collected as fees
    function collectFees() external nonReentrant returns (uint256 baseAmount, uint256 quoteAmount) {
        uint256 baseFeesInBasisPoints = baseFeesOwedInBasisPoints[msg.sender];
        uint256 quoteFeesInBasisPoints = quoteFeesOwedInBasisPoints[msg.sender];

        if (baseFeesInBasisPoints == 0 && quoteFeesInBasisPoints == 0) revert NoFeesToCollect();

        // Convert basis points to actual amounts
        baseAmount = baseFeesInBasisPoints / BASIS_POINTS_DENOMINATOR;
        quoteAmount = quoteFeesInBasisPoints / BASIS_POINTS_DENOMINATOR;

        // Ensure minimum collection amounts - allow collection if either amount meets minimum
        if (baseAmount < MINIMUM_COLLECTION_AMOUNT && quoteAmount < MINIMUM_COLLECTION_AMOUNT) {
            revert BelowMinimumCollectionAmount();
        }

        // Reset and Transfer fees
        if (baseAmount >= MINIMUM_COLLECTION_AMOUNT) {
            baseFeesOwedInBasisPoints[msg.sender] = 0;
            IERC20(baseToken).safeTransfer(msg.sender, baseAmount);
        }
        if (quoteAmount >= MINIMUM_COLLECTION_AMOUNT) {
            quoteFeesOwedInBasisPoints[msg.sender] = 0;
            IERC20(quoteToken).safeTransfer(msg.sender, quoteAmount);
        }

        emit FeesCollected(msg.sender, baseAmount, quoteAmount);
        return (baseAmount, quoteAmount);
    }

    /// @notice Allows admin to collect accumulated protocol fees
    /// @dev Can only be called by accounts with ADMIN_ROLE
    /// @dev Protocol fees are tracked in basis points and converted to actual token amounts on collection
    /// @dev Resets protocol fee tracking after successful collection
    /// @return baseAmount The amount of base tokens collected as protocol fees
    /// @return quoteAmount The amount of quote tokens collected as protocol fees
    function collectProtocolFees()
        external
        nonReentrant
        onlyRole(ADMIN_ROLE)
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        uint256 baseFeesInBasisPoints = protocolBaseFeesInBasisPoints;
        uint256 quoteFeesInBasisPoints = protocolQuoteFeesInBasisPoints;

        if (baseFeesInBasisPoints == 0 && quoteFeesInBasisPoints == 0) revert NoFeesToCollect();

        // Convert basis points to actual token amounts
        baseAmount = baseFeesInBasisPoints / BASIS_POINTS_DENOMINATOR;
        quoteAmount = quoteFeesInBasisPoints / BASIS_POINTS_DENOMINATOR;

        // Reset protocol fees tracking
        protocolBaseFeesInBasisPoints = 0;
        protocolQuoteFeesInBasisPoints = 0;

        // Transfer collected fees
        if (baseAmount > 0) {
            IERC20(baseToken).safeTransfer(msg.sender, baseAmount);
        }
        if (quoteAmount > 0) {
            IERC20(quoteToken).safeTransfer(msg.sender, quoteAmount);
        }

        emit ProtocolFeesCollected(baseAmount, quoteAmount);
        return (baseAmount, quoteAmount);
    }

    /// @notice Returns the pending fees for a given user that can be collected
    /// @dev Converts fee amounts from basis points to actual token amounts by dividing by BASIS_POINTS_DENOMINATOR
    /// @param user The address of the user to check pending fees for
    /// @return baseAmount The amount of base tokens available to collect as fees
    /// @return quoteAmount The amount of quote tokens available to collect as fees
    function getPendingFees(address user) external view returns (uint256 baseAmount, uint256 quoteAmount) {
        if (user == address(0)) revert ZeroAddress();

        uint256 baseFeesInBasisPoints = baseFeesOwedInBasisPoints[user];
        uint256 quoteFeesInBasisPoints = quoteFeesOwedInBasisPoints[user];

        baseAmount = baseFeesInBasisPoints / BASIS_POINTS_DENOMINATOR;
        quoteAmount = quoteFeesInBasisPoints / BASIS_POINTS_DENOMINATOR;

        return (baseAmount, quoteAmount);
    }

    /// @notice Calculates the amount of quote tokens that would be received for a given amount of base tokens
    /// @dev Uses the constant product formula (x * y = k) to calculate the exchange rate
    /// @param baseAmount The amount of base tokens to swap
    /// @return The amount of quote tokens that would be received
    /// @custom:throws InvalidReserves if either token balance is 0
    /// @custom:throws ZeroAmount if baseAmount is 0
    function getBaseToQuotePrice(uint256 baseAmount) external view returns (uint256) {
        if (baseAmount == 0) revert ZeroAmount();

        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        if (baseBalance == 0 || quoteBalance == 0) revert InvalidReserves();

        (uint256 netBaseAmount,,) = _calculateNetAmount(baseAmount);
        return _getAmountOfTokens(baseBalance, quoteBalance, netBaseAmount);
    }

    /// @notice Calculates the amount of base tokens that would be received for a given amount of quote tokens
    /// @dev Uses the constant product formula (x * y = k) to calculate the exchange rate
    /// @param quoteAmount The amount of quote tokens to swap
    /// @return The amount of base tokens that would be received
    /// @custom:throws InvalidReserves if either token balance is 0
    /// @custom:throws ZeroAmount if quoteAmount is 0
    function getQuoteToBasePrice(uint256 quoteAmount) external view returns (uint256) {
        if (quoteAmount == 0) revert ZeroAmount();

        uint256 baseBalance = getBaseTokenBalance();
        uint256 quoteBalance = getQuoteTokenBalance();

        if (baseBalance == 0 || quoteBalance == 0) revert InvalidReserves();

        (uint256 netQuoteAmount,,) = _calculateNetAmount(quoteAmount);
        return _getAmountOfTokens(quoteBalance, baseBalance, netQuoteAmount);
    }

    /// @notice Verifies that the actual token balances match the tracked balances within tolerance
    /// @dev Compares the contract's actual token balances against internally tracked balances
    /// @dev Uses AMOUNT_TOLERANCE to allow for small rounding differences
    /// @dev _trackedBaseBalance and _trackedQuoteBalance are internal state variables updated during swaps/liquidity
    /// changes
    /// @return true if actual balances are within AMOUNT_TOLERANCE of tracked balances, false otherwise
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

    /// @notice Calculates the output amount of tokens for a given input amount and reserves
    /// @dev Uses constant product formula (k = x * y) accounting for fees
    /// @param netInputAmount The input amount after fees have been deducted
    /// @param inputReserve The current reserve of input tokens
    /// @param outputReserve The current reserve of output tokens
    /// @return The amount of output tokens that will be received
    function _getAmountOfTokens(
        uint256 netInputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    )
        internal
        pure
        returns (uint256)
    {
        if (inputReserve == 0 || outputReserve == 0) revert InvalidReserves();
        if (netInputAmount == 0) revert ZeroAmount();

        uint256 numerator = netInputAmount * outputReserve;
        uint256 denominator = inputReserve + netInputAmount;

        if (denominator == 0) revert DivisionByZero();

        unchecked {
            return numerator / denominator;
        }
    }

    /// @notice Calculates the net amount and fees without distributing them
    /// @dev Pure function that handles fee calculations based on BASIS_POINTS_DENOMINATOR
    /// @param amount The amount to calculate fees for
    /// @return netAmount The amount after all fees are deducted
    /// @return lpFees The fee amount allocated to liquidity providers (90% of total fees)
    /// @return protocolFees The fee amount allocated to protocol (10% of total fees)
    function _calculateNetAmount(uint256 amount)
        internal
        pure
        returns (uint256 netAmount, uint256 lpFeesInBasisPoints, uint256 protocolFeesInBasisPoints)
    {
        if (amount == 0) return (0, 0, 0);

        uint256 feeTotalInBasisPoints = amount * swapFeeInBasisPoints;
        uint256 protocolFeesInBasisPoints =
            (feeTotalInBasisPoints * PROTOCOL_FEE_SHARE_IN_BASIS_POINTS) / BASIS_POINTS_DENOMINATOR;
        uint256 lpFeesInBasisPoints = feeTotalInBasisPoints - protocolFeesInBasisPoints;
        uint256 netAmount = amount - ((lpFeesInBasisPoints + protocolFeesInBasisPoints) / BASIS_POINTS_DENOMINATOR);

        return (netAmount, lpFeesInBasisPoints, protocolFeesInBasisPoints);
    }

    /// @notice Calculates and distributes trading fees between LPs and protocol
    /// @param baseAmount The amount of base tokens to calculate fees for
    /// @param quoteAmount The amount of quote tokens to calculate fees for
    /// @return netBaseAmount The base token amount after fees are deducted
    /// @return netQuoteAmount The quote token amount after fees are deducted
    function _handleFees(
        uint256 baseAmount,
        uint256 quoteAmount
    )
        internal
        returns (uint256 netBaseAmount, uint256 netQuoteAmount)
    {
        // Calculate all amounts and fees at once
        (netBaseAmount, uint256 baseLpFeesInBasisPoints, uint256 baseProtocolFeesInBasisPoints) =
            _calculateNetAmount(baseAmount);
        (netQuoteAmount, uint256 quoteLpFeesInBasisPoints, uint256 quoteProtocolFeesInBasisPoints) =
            _calculateNetAmount(quoteAmount);

        if (baseAmount > 0) {
            protocolBaseFeesInBasisPoints += baseProtocolFeesInBasisPoints;
        }
        if (quoteAmount > 0) {
            protocolQuoteFeesInBasisPoints += quoteProtocolFeesInBasisPoints;
        }

        uint256 totalLPSupply = totalSupply();
        if (totalLPSupply > 0 && (baseLpFeesInBasisPoints > 0 || quoteLpFeesInBasisPoints > 0)) {
            uint256 userLPShareInBasisPoints = (balanceOf(msg.sender) * BASIS_POINTS_DENOMINATOR) / totalLPSupply;

            if (baseLpFeesInBasisPoints > 0) {
                uint256 baseUserFeeShareInBasisPoints =
                    (baseLpFeesInBasisPoints * userLPShareInBasisPoints) / BASIS_POINTS_DENOMINATOR;
                baseFeesOwedInBasisPoints[msg.sender] += baseUserFeeShareInBasisPoints;
            }

            if (quoteLpFeesInBasisPoints > 0) {
                uint256 quoteUserFeeShareInBasisPoints =
                    (quoteLpFeesInBasisPoints * userLPShareInBasisPoints) / BASIS_POINTS_DENOMINATOR;
                quoteFeesOwedInBasisPoints[msg.sender] += quoteUserFeeShareInBasisPoints;
            }

            emit FeesAccrued(msg.sender, baseLpFeesInBasisPoints, quoteLpFeesInBasisPoints);
        }

        return (netBaseAmount, netQuoteAmount);
    }

    /// @notice Returns the absolute difference between two uint256 values
    /// @param a First value
    /// @param b Second value
    /// @return The absolute difference |a - b|
    function _absDifference(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a - b : b - a;
    }

    /// @notice Calculates liquidity value and validates against minimum requirement
    /// @dev Reverts if liquidity requirements are not met
    /// @param baseAmount The amount of base tokens
    /// @param quoteAmount The amount of quote tokens
    /// @return liquidity The calculated liquidity value (sqrt of token amounts product)
    function _calculateAndVerifyLiquidity(
        uint256 baseAmount,
        uint256 quoteAmount
    )
        private
        pure
        returns (uint256 liquidity)
    {
        if (baseAmount == 0 || quoteAmount == 0) revert ZeroAmount();

        // Check for multiplication overflow before sqrt
        uint256 product;
        unchecked {
            product = baseAmount * quoteAmount;
            if (product / baseAmount != quoteAmount) revert MaxTokenAmountExceeded();
        }

        liquidity = Math.sqrt(product);
        if (liquidity < MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();
        return liquidity;
    }
}

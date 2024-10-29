// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract StarterKitERC20Dex is ERC20, Ownable, Pausable {
    using SafeERC20 for IERC20;

    error SameTokenAddress(address token);
    error InvalidReserves();
    error AmountRatioMismatch(uint256 provided, uint256 expected);
    error ZeroAmount();
    error InsufficientLiquidityMinted();
    error InvalidTokenAmount(uint256 amount);
    error InvalidFee(uint256 fee);
    error FeeTooHigh(uint256 fee);
    error ContractLocked();
    error DeadlineExpired();
    error SlippageExceeded();
    error ZeroAddress();
    error InvalidERC20();
    error TokenDecimalsMismatch();
    error MaxTokenAmountExceeded();
    error BalanceMismatch();

    event Mint(
        address indexed sender,
        uint256 baseAmount,
        uint256 quoteAmount,
        uint256 liquidity
    );
    event Burn(
        address indexed sender,
        uint256 baseAmount,
        uint256 quoteAmount,
        address indexed to,
        uint256 liquidity
    );
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

    // Fee in basis points (1% = 100)
    uint256 public swapFee;
    uint256 public constant MAX_FEE = 1000; // (10%)

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant AMOUNT_TOLERANCE = 100; // 0.01% tolerance for amount comparisons
    bool private unlocked = true;

    uint256 public constant MAX_TOKEN_AMOUNT = type(uint128).max;

    modifier lock() {
        if (!unlocked) revert ContractLocked();
        unlocked = false;
        _;
        unlocked = true;
    }

    constructor(
        address _baseToken,
        address _quoteToken,
        uint256 _initialFee
    ) ERC20(name(), symbol()) Ownable(msg.sender) {
        if (_baseToken == address(0) || _quoteToken == address(0)) revert ZeroAddress();
        if (_baseToken == _quoteToken) revert SameTokenAddress(_baseToken);
        if (_initialFee > MAX_FEE) revert FeeTooHigh(_initialFee);
        if (_initialFee == 0) revert InvalidFee(_initialFee);

        // Verify both tokens are valid ERC20
        try IERC20(_baseToken).totalSupply() {} catch { revert InvalidERC20(); }
        try IERC20(_quoteToken).totalSupply() {} catch { revert InvalidERC20(); }

        // Verify token decimals are compatible
        uint8 baseDecimals = ERC20(_baseToken).decimals();
        uint8 quoteDecimals = ERC20(_quoteToken).decimals();
        if (baseDecimals != quoteDecimals) revert TokenDecimalsMismatch();

        baseToken = _baseToken;
        quoteToken = _quoteToken;
        swapFee = _initialFee;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setFee(uint256 _newFee) external onlyOwner {
        if (_newFee == 0) {
            revert InvalidFee(_newFee);
        }

        emit FeeUpdated(swapFee, _newFee);
        swapFee = _newFee;
    }

    function getBaseTokenBalance() public view returns (uint256) {
        return ERC20(baseToken).balanceOf(address(this));
    }

    function getQuoteTokenBalance() public view returns (uint256) {
        return ERC20(quoteToken).balanceOf(address(this));
    }

    function addLiquidity(uint256 baseAmount, uint256 quoteAmount) public lock returns (uint256) {
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
        return _liquidity;
    }

    function removeLiquidity(
        uint256 amount,
        uint256 minBaseAmount,
        uint256 minQuoteAmount,
        uint256 deadline
    ) public lock whenNotPaused returns (uint256, uint256) {
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

        return (baseAmount, quoteAmount);
    }

    function getAmountOfTokens(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public view returns (uint256) {
        if (inputReserve == 0 || outputReserve == 0) revert InvalidReserves();
        if (inputAmount == 0) revert InvalidTokenAmount(inputAmount);

        uint256 inputAmountWithFee = inputAmount * (10000 - swapFee);
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 10000) + inputAmountWithFee;

        unchecked {
            return numerator / denominator;
        }
    }

    function swapBaseToQuote(
        uint256 baseAmount,
        uint256 minQuoteAmount,
        uint256 deadline
    ) public lock whenNotPaused {
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
        IERC20(quoteToken).safeTransfer(msg.sender, quoteBought);
    }

    function swapQuoteToBase(
        uint256 quoteAmount,
        uint256 minBaseAmount,
        uint256 deadline
    ) public lock whenNotPaused {
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
        IERC20(baseToken).safeTransfer(msg.sender, baseBought);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(token, amount);
    }

    // Add view function for price calculation
    function getBaseToQuotePrice(uint256 baseAmount) external view returns (uint256) {
        return getAmountOfTokens(
            baseAmount,
            getBaseTokenBalance(),
            getQuoteTokenBalance()
        );
    }

    function verifyBalances() public view returns (bool) {
        uint256 baseBalance = IERC20(baseToken).balanceOf(address(this));
        uint256 quoteBalance = IERC20(quoteToken).balanceOf(address(this));

        // Calculate expected balances based on total supply and initial liquidity
        uint256 expectedBaseBalance = getBaseTokenBalance();
        uint256 expectedQuoteBalance = getQuoteTokenBalance();

        return baseBalance == expectedBaseBalance &&
               quoteBalance == expectedQuoteBalance;
    }

    function requireValidBalances() internal view {
        if (!verifyBalances()) revert BalanceMismatch();
    }
}

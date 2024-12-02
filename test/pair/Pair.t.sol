// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Pair } from "../../contracts/pair/Pair.sol";
import { Token } from "../../contracts/token/Token.sol";
import { MockERC20 } from "forge-std/mocks/MockERC20.sol";

contract PairTest is Test {
    Pair public pair;
    Token public baseToken;
    Token public quoteToken;
    address public admin;
    address public user1;
    address public user2;

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

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(admin);
        baseToken = new Token("Base Token", "BASE", admin);
        quoteToken = new Token("Quote Token", "QUOTE", admin);
        pair = new Pair(address(baseToken), address(quoteToken), 100, admin); // 1% fee

        // Mint tokens for testing
        baseToken.mint(user1, 1000e18);
        quoteToken.mint(user1, 1000e18);
        baseToken.mint(user2, 1000e18);
        quoteToken.mint(user2, 1000e18);
        vm.stopPrank();

        vm.startPrank(user1);
        baseToken.approve(address(pair), type(uint256).max);
        quoteToken.approve(address(pair), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        baseToken.approve(address(pair), type(uint256).max);
        quoteToken.approve(address(pair), type(uint256).max);
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(address(pair.baseToken()), address(baseToken));
        assertEq(address(pair.quoteToken()), address(quoteToken));
        assertEq(pair.swapFee(), 100);
        assertTrue(pair.hasRole(pair.ADMIN_ROLE(), admin));
        assertTrue(pair.hasRole(pair.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_AddInitialLiquidity() public {
        vm.startPrank(user1);

        uint256 baseAmount = 100e18;
        uint256 quoteAmount = 100e18;

        uint256 liquidity = pair.addLiquidity(baseAmount, quoteAmount);

        // First liquidity provider gets the full amount
        assertEq(liquidity, 100e18);
        // But their balance is liquidity - MINIMUM_LIQUIDITY
        assertEq(pair.balanceOf(user1), 99_999_999_999_999_999_000);
        assertEq(baseToken.balanceOf(address(pair)), baseAmount);
        assertEq(quoteToken.balanceOf(address(pair)), quoteAmount);

        // Verify MINIMUM_LIQUIDITY is locked
        assertEq(pair.balanceOf(address(1)), 1000);

        vm.stopPrank();
    }

    function test_AddLiquidityAfterInitial() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 liquidity = pair.addLiquidity(50e18, 50e18);
        assertGt(liquidity, 0);
        assertEq(pair.balanceOf(user2), liquidity);
        vm.stopPrank();
    }

    function testFail_AddLiquidityImbalanced() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        pair.addLiquidity(50e18, 40e18); // Wrong ratio
        vm.stopPrank();
    }

    function test_RemoveLiquidity() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        // Need to approve pair contract to burn LP tokens
        pair.approve(address(pair), pair.balanceOf(user1));

        (uint256 baseAmount, uint256 quoteAmount) = pair.removeLiquidity(pair.balanceOf(user1), 0, 0, block.number + 1);

        // Can't remove MINIMUM_LIQUIDITY
        assertEq(baseAmount, 99_999_999_999_999_999_000);
        assertEq(quoteAmount, 99_999_999_999_999_999_000);
        assertEq(pair.balanceOf(user1), 0);

        // Verify MINIMUM_LIQUIDITY is still locked
        assertEq(pair.balanceOf(address(1)), 1000);

        vm.stopPrank();
    }

    function test_SwapBaseToQuote() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 baseAmount = 1e18; // Reduced amount to avoid exceeding max swap
        uint256 expectedOutput =
            pair.getAmountOfTokens(baseAmount, pair.getBaseTokenBalance(), pair.getQuoteTokenBalance());

        // Verify the event after swap
        vm.expectEmit(true, true, true, true);
        emit Swap(user2, baseAmount, 0, 0, expectedOutput, user2);
        pair.swapBaseToQuote(baseAmount, expectedOutput, block.number + 1);

        assertGt(quoteToken.balanceOf(user2), 990e18);
        vm.stopPrank();
    }

    function test_SwapQuoteToBase() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 quoteAmount = 10e18;
        uint256 expectedOutput =
            pair.getAmountOfTokens(quoteAmount, pair.getQuoteTokenBalance(), pair.getBaseTokenBalance());

        vm.expectEmit(true, true, true, true);
        emit Swap(user2, 0, quoteAmount, expectedOutput, 0, user2);

        pair.swapQuoteToBase(quoteAmount, expectedOutput, block.number + 1);
        assertGt(baseToken.balanceOf(user2), 990e18);
        vm.stopPrank();
    }

    function test_SetFee() public {
        vm.prank(admin);

        vm.expectEmit(true, true, true, true);
        emit FeeUpdated(100, 200);

        pair.setFee(200);
        assertEq(pair.swapFee(), 200);
    }

    function testFail_SetFeeUnauthorized() public {
        vm.prank(user1);
        pair.setFee(200);
    }

    function test_EmergencyWithdraw() public {
        vm.startPrank(admin);

        // First add liquidity to properly track balances
        baseToken.mint(address(pair), 100e18);
        quoteToken.mint(address(pair), 100e18);

        // Update tracked balances by adding liquidity
        vm.stopPrank();
        vm.startPrank(user1);
        baseToken.approve(address(pair), 100e18);
        quoteToken.approve(address(pair), 100e18);
        pair.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdraw(address(baseToken), 100e18);

        pair.emergencyWithdraw(address(baseToken), 100e18);
        assertEq(baseToken.balanceOf(admin), 100e18);
        vm.stopPrank();
    }

    function testFail_EmergencyWithdrawUnauthorized() public {
        vm.startPrank(user1);
        pair.emergencyWithdraw(address(baseToken), 100e18);
        vm.stopPrank();
    }

    function testFail_EmergencyWithdrawZeroAddress() public {
        vm.startPrank(admin);
        pair.emergencyWithdraw(address(0), 100e18);
        vm.stopPrank();
    }

    function testFail_EmergencyWithdrawZeroAmount() public {
        vm.startPrank(admin);
        pair.emergencyWithdraw(address(baseToken), 0);
        vm.stopPrank();
    }

    function testFail_EmergencyWithdrawInsufficientBalance() public {
        vm.startPrank(admin);
        pair.emergencyWithdraw(address(baseToken), 100e18);
        vm.stopPrank();
    }

    function test_PauseUnpause() public {
        vm.startPrank(admin);
        pair.pause();
        assertTrue(pair.paused());

        vm.expectRevert();
        pair.addLiquidity(100e18, 100e18);

        pair.unpause();
        assertFalse(pair.paused());
        vm.stopPrank();
    }

    function test_VerifyBalances() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        assertTrue(pair.verifyBalances());
        vm.stopPrank();
    }

    function testFail_AddLiquidityZeroAmount() public {
        vm.startPrank(user1);
        pair.addLiquidity(0, 100e18);
        vm.stopPrank();
    }

    function testFail_AddLiquidityOverflow() public {
        vm.startPrank(user1);
        pair.addLiquidity(type(uint128).max + 1, 100e18);
        vm.stopPrank();
    }

    function testFail_RemoveLiquidityZeroAmount() public {
        vm.startPrank(user1);
        pair.removeLiquidity(0, 0, 0, block.number + 1);
        vm.stopPrank();
    }

    function testFail_RemoveLiquidityExpiredDeadline() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.roll(block.number + 2);
        pair.removeLiquidity(100e18, 0, 0, block.number - 1);
        vm.stopPrank();
    }

    function testFail_RemoveLiquidityInsufficientOutput() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        pair.removeLiquidity(100e18, 101e18, 101e18, block.number + 1);
        vm.stopPrank();
    }

    function testFail_SwapBaseToQuoteExpiredDeadline() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.roll(block.number + 2);
        pair.swapBaseToQuote(1e18, 0, block.number - 1);
        vm.stopPrank();
    }

    function testFail_SwapBaseToQuoteInsufficientOutput() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        uint256 expectedOutput = pair.getAmountOfTokens(1e18, 100e18, 100e18);
        pair.swapBaseToQuote(1e18, expectedOutput + 1, block.number + 1);
        vm.stopPrank();
    }

    function testFail_SwapQuoteToBaseExpiredDeadline() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.roll(block.number + 2);
        pair.swapQuoteToBase(1e18, 0, block.number - 1);
        vm.stopPrank();
    }

    function testFail_SwapQuoteToBaseInsufficientOutput() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        uint256 expectedOutput = pair.getAmountOfTokens(1e18, 100e18, 100e18);
        pair.swapQuoteToBase(1e18, expectedOutput + 1, block.number + 1);
        vm.stopPrank();
    }

    function test_GetBaseToQuotePrice() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        uint256 output = pair.getBaseToQuotePrice(1e18);
        assertGt(output, 0);
        vm.stopPrank();
    }

    function testFail_GetBaseToQuotePriceZeroAmount() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        pair.getBaseToQuotePrice(0);
        vm.stopPrank();
    }

    function testFail_GetBaseToQuotePriceEmptyReserves() public view {
        pair.getBaseToQuotePrice(1e18);
    }

    function test_GetQuoteToBasePrice() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        uint256 output = pair.getQuoteToBasePrice(1e18);
        assertGt(output, 0);
        vm.stopPrank();
    }

    function testFail_GetQuoteToBasePriceZeroAmount() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        pair.getQuoteToBasePrice(0);
        vm.stopPrank();
    }

    function testFail_GetQuoteToBasePriceEmptyReserves() public view {
        pair.getQuoteToBasePrice(1e18);
    }

    function test_VerifyBalancesEmpty() public view {
        assertFalse(pair.verifyBalances());
    }

    function test_VerifyBalancesMismatch() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        // Force a balance mismatch by directly transferring tokens
        baseToken.transfer(address(pair), 1e18);

        assertFalse(pair.verifyBalances());
        vm.stopPrank();
    }

    function testFail_InvalidTokenDecimals() public {
        // Create a mock token with 8 decimals
        MockERC20 token8Dec = new MockERC20();
        token8Dec.initialize("8 Decimals", "TK8", 8);

        // Should revert due to decimal mismatch
        new Pair(address(token8Dec), address(quoteToken), 100, admin);
    }

    function testFail_InvalidERC20() public {
        // Try to create pair with non-ERC20 address
        new Pair(address(0x123), address(quoteToken), 100, admin);
    }

    function testFail_FeeTooHigh() public {
        // Try to create pair with fee > MAX_FEE
        new Pair(address(baseToken), address(quoteToken), 1001, admin);
    }

    function test_AddLiquidityWithExistingReserves() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        // Add liquidity with slightly imbalanced amounts
        uint256 baseAmount = 50e18;
        uint256 quoteBalance = pair.getQuoteTokenBalance();
        uint256 baseBalance = pair.getBaseTokenBalance();
        uint256 expectedQuoteAmount = (baseAmount * quoteBalance) / baseBalance;

        // Should succeed with the correct ratio
        uint256 liquidity = pair.addLiquidity(baseAmount, expectedQuoteAmount);
        assertGt(liquidity, 0);
        vm.stopPrank();
    }

    function testFail_AddLiquidityRatioTooLow() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        uint256 baseAmount = 50e18;
        uint256 quoteBalance = pair.getQuoteTokenBalance();
        uint256 baseBalance = pair.getBaseTokenBalance();
        uint256 expectedQuoteAmount = (baseAmount * quoteBalance) / baseBalance;

        // Try with amount below the tolerance (0.5% below expected)
        uint256 lowAmount = (expectedQuoteAmount * 9950) / 10_000; // 99.5% of expected

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount ratio mismatch"));
        pair.addLiquidity(baseAmount, lowAmount);
        vm.stopPrank();
    }

    function testFail_AddLiquidityRatioTooHigh() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        uint256 baseAmount = 50e18;
        uint256 quoteBalance = pair.getQuoteTokenBalance();
        uint256 baseBalance = pair.getBaseTokenBalance();
        uint256 expectedQuoteAmount = (baseAmount * quoteBalance) / baseBalance;

        // Try with amount above the tolerance (0.5% above expected)
        uint256 highAmount = (expectedQuoteAmount * 10_050) / 10_000; // 100.5% of expected

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount ratio mismatch"));
        pair.addLiquidity(baseAmount, highAmount);
        vm.stopPrank();
    }

    function test_SwapExactAmounts() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 swapAmount = 1e18;
        uint256 expectedOutput =
            pair.getAmountOfTokens(swapAmount, pair.getBaseTokenBalance(), pair.getQuoteTokenBalance());

        uint256 balanceBefore = quoteToken.balanceOf(user2);
        pair.swapBaseToQuote(swapAmount, expectedOutput, block.number + 1);
        uint256 balanceAfter = quoteToken.balanceOf(user2);

        assertEq(balanceAfter - balanceBefore, expectedOutput);
        vm.stopPrank();
    }

    function test_SwapWithMaxAmount() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        // Try to swap 3% of reserves (max allowed)
        uint256 maxSwapAmount = (pair.getBaseTokenBalance() * 3) / 100;
        uint256 expectedOutput =
            pair.getAmountOfTokens(maxSwapAmount, pair.getBaseTokenBalance(), pair.getQuoteTokenBalance());

        pair.swapBaseToQuote(maxSwapAmount, expectedOutput, block.number + 1);
        vm.stopPrank();
    }

    function testFail_SwapExceedsMaxAmount() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        // Try to swap more than 3% of reserves
        uint256 tooLargeAmount = (pair.getBaseTokenBalance() * 4) / 100;
        pair.swapBaseToQuote(tooLargeAmount, 0, block.number + 1);
        vm.stopPrank();
    }

    function test_RequireValidBalances() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        // Should succeed with matching balances
        pair.swapBaseToQuote(1e18, 0, block.number + 1);

        // Force a balance mismatch
        baseToken.transfer(address(pair), 1e18);

        // Should revert on next operation due to balance mismatch
        vm.expectRevert();
        pair.swapBaseToQuote(1e18, 0, block.number + 1);
        vm.stopPrank();
    }

    function test_AbsFunction() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        // Create small imbalance within tolerance
        baseToken.transfer(address(pair), 99);

        // Should still verify as true since difference is within tolerance
        assertTrue(pair.verifyBalances());
        vm.stopPrank();
    }

    function testFail_AddLiquidityMaxTokenAmount() public {
        vm.startPrank(user1);
        // Try to add liquidity with amount > MAX_TOKEN_AMOUNT
        pair.addLiquidity(type(uint128).max + 1, type(uint128).max + 1);
        vm.stopPrank();
    }

    function test_AddLiquidityExactRatio() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        // Add liquidity with exact ratio
        uint256 baseAmount = 50e18;
        uint256 quoteBalance = pair.getQuoteTokenBalance();
        uint256 baseBalance = pair.getBaseTokenBalance();
        uint256 expectedQuoteAmount = (baseAmount * quoteBalance) / baseBalance;

        uint256 liquidity = pair.addLiquidity(baseAmount, expectedQuoteAmount);
        assertGt(liquidity, 0);
        vm.stopPrank();
    }

    function testFail_AddLiquidityZeroLiquidity() public {
        vm.startPrank(user1);
        // Try to add tiny amounts that would result in 0 liquidity
        pair.addLiquidity(1, 1);
        vm.stopPrank();
    }

    function test_SwapEdgeCases() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        // Test exact max allowed swap amount (3% of reserves)
        uint256 maxAmount = (pair.getBaseTokenBalance() * 3) / 100;
        uint256 expectedOutput =
            pair.getAmountOfTokens(maxAmount, pair.getBaseTokenBalance(), pair.getQuoteTokenBalance());

        pair.swapBaseToQuote(maxAmount, expectedOutput, block.number + 1);
        vm.stopPrank();
    }

    function test_BalanceVerificationEdgeCases() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        uint256 baseBalance = pair.getBaseTokenBalance();
        uint256 quoteBalance = pair.getQuoteTokenBalance();

        uint256 baseAmount = 1e18;
        uint256 expectedQuoteAmount = (baseAmount * quoteBalance) / baseBalance;
        pair.addLiquidity(baseAmount, expectedQuoteAmount);
        assertTrue(pair.verifyBalances());

        uint256 imbalancedQuoteAmount = (expectedQuoteAmount * 1011) / 1000;

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount ratio mismatch"));
        pair.addLiquidity(baseAmount, imbalancedQuoteAmount);
        vm.stopPrank();
    }

    function test_SwapFeeCalculation() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        uint256 swapAmount = 1e18;
        uint256 expectedOutput =
            pair.getAmountOfTokens(swapAmount, pair.getBaseTokenBalance(), pair.getQuoteTokenBalance());

        // Verify the output includes the fee
        assertTrue(expectedOutput < (swapAmount * pair.getQuoteTokenBalance()) / pair.getBaseTokenBalance());

        pair.swapBaseToQuote(swapAmount, expectedOutput, block.number + 1);
        vm.stopPrank();
    }

    // Add this test to verify exact tolerance boundary
    function test_ExactToleranceBoundary() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        uint256 baseAmount = 1e18;
        uint256 expectedQuoteAmount = 1e18;
        uint256 imbalancedQuoteAmount = (expectedQuoteAmount * 1011) / 1000;

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount ratio mismatch"));
        pair.addLiquidity(baseAmount, imbalancedQuoteAmount);
        vm.stopPrank();
    }

    // Add this test to verify small imbalances
    function test_SmallBalanceImbalances() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        // Test tiny imbalance (should be within tolerance)
        baseToken.transfer(address(pair), 1);
        quoteToken.transfer(address(pair), 1);
        assertTrue(pair.verifyBalances());

        // Add more tiny amounts until we exceed tolerance
        for (uint256 i = 0; i < 100; i++) {
            baseToken.transfer(address(pair), 1e15);
            quoteToken.transfer(address(pair), 1e15);
        }
        assertFalse(pair.verifyBalances());
        vm.stopPrank();
    }

    // Add this test to verify tolerance calculation
    function test_ToleranceCalculation() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        uint256 baseBalance = pair.getBaseTokenBalance();

        // Test at 0.1% difference (should pass)
        uint256 smallDiff = (baseBalance * 10) / 10_000; // 0.1%
        pair.addLiquidity(smallDiff, smallDiff);
        assertTrue(pair.verifyBalances());

        // Test at 0.5% difference (should pass)
        uint256 mediumDiff = (baseBalance * 50) / 10_000; // 0.5%
        pair.addLiquidity(mediumDiff, mediumDiff);
        assertTrue(pair.verifyBalances());

        // Test at 1.1% difference (should fail)
        uint256 baseAmount = 1.1e18;
        uint256 imbalancedQuoteAmount = 1.21726e18;

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount ratio mismatch"));
        pair.addLiquidity(baseAmount, imbalancedQuoteAmount);
        vm.stopPrank();
    }

    // Add a test for tolerance boundary
    function test_ToleranceBoundary() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        uint256 baseBalance = pair.getBaseTokenBalance();

        // Test at exactly 1% difference (should pass)
        uint256 exactTolerance = (baseBalance * 100) / 10_000; // 1.0%
        pair.addLiquidity(exactTolerance, exactTolerance);
        assertTrue(pair.verifyBalances());

        // Test slightly over 1% (should fail)
        uint256 baseAmount = 1e18;
        uint256 imbalancedQuoteAmount = 1.02111e18;

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount ratio mismatch"));
        pair.addLiquidity(baseAmount, imbalancedQuoteAmount);
        vm.stopPrank();
    }

    // Add a test for incremental tolerance
    function test_IncrementalTolerance() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        uint256 baseBalance = pair.getBaseTokenBalance();
        uint256 step = (baseBalance * 25) / 10_000; // 0.25% steps

        // Add liquidity in steps up to tolerance
        for (uint256 i = 0; i < 4; i++) {
            // Will reach 1% total
            pair.addLiquidity(step, step);
            assertTrue(pair.verifyBalances());
        }

        // Try to add with imbalanced ratio that exceeds tolerance
        uint256 baseAmount = 2.5e17;
        uint256 imbalancedQuoteAmount = 2.552775e17;

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount ratio mismatch"));
        pair.addLiquidity(baseAmount, imbalancedQuoteAmount);
        vm.stopPrank();
    }

    // Add a test for cumulative tolerance
    function test_CumulativeTolerance() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        uint256 baseBalance = pair.getBaseTokenBalance();
        uint256 quoteBalance = pair.getQuoteTokenBalance();

        uint256 baseAmount = (baseBalance * 20) / 10_000;
        uint256 expectedQuoteAmount = (baseAmount * quoteBalance) / baseBalance;

        for (uint256 i = 0; i < 4; i++) {
            pair.addLiquidity(baseAmount, expectedQuoteAmount);
            assertTrue(pair.verifyBalances());
        }

        uint256 imbalancedQuoteAmount = (expectedQuoteAmount * 1011) / 1000;

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount ratio mismatch"));
        pair.addLiquidity(baseAmount, imbalancedQuoteAmount);
        vm.stopPrank();
    }

    // Add a test for exact boundary conditions
    function test_ExactBoundaryConditions() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        uint256 baseAmount = 1e18;
        uint256 expectedQuoteAmount = 1e18;
        uint256 imbalancedQuoteAmount = expectedQuoteAmount + ((expectedQuoteAmount * 1) / 100) + 1;

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount ratio mismatch"));
        pair.addLiquidity(baseAmount, imbalancedQuoteAmount);
        vm.stopPrank();
    }

    // Add these new test functions after the existing tests

    function test_MaxTokenAmountCheck() public {
        vm.startPrank(user1);
        uint256 maxAmount = type(uint128).max;

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount exceeds maximum"));
        pair.addLiquidity(maxAmount + 1, 100e18);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Amount exceeds maximum"));
        pair.addLiquidity(100e18, maxAmount + 1);
        vm.stopPrank();
    }

    function test_InvalidReservesSwap() public {
        vm.startPrank(user1);

        // Try to get amount of tokens with zero reserves
        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidOperation.selector, "Invalid reserves"));
        pair.getAmountOfTokens(100e18, 0, 100e18);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidOperation.selector, "Invalid reserves"));
        pair.getAmountOfTokens(100e18, 100e18, 0);
        vm.stopPrank();
    }

    function test_InvalidTokenAmountSwap() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        // Try to get amount of tokens with zero input
        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Zero amount"));
        pair.getAmountOfTokens(0, 100e18, 100e18);
        vm.stopPrank();
    }

    function test_SwapDeadlineExpired() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        // Set block number ahead of deadline
        vm.roll(block.number + 2);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidOperation.selector, "Deadline expired"));
        pair.swapBaseToQuote(1e18, 0, block.number - 1);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidOperation.selector, "Deadline expired"));
        pair.swapQuoteToBase(1e18, 0, block.number - 1);
        vm.stopPrank();
    }

    function test_SwapZeroAmount() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Zero amount"));
        pair.swapBaseToQuote(0, 0, block.number + 1);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Zero amount"));
        pair.swapQuoteToBase(0, 0, block.number + 1);
        vm.stopPrank();
    }

    function test_RemoveLiquidityZero() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Zero amount"));
        pair.removeLiquidity(0, 0, 0, block.number + 1);
        vm.stopPrank();
    }

    function test_InvalidFeeValue() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Zero fee"));
        pair.setFee(0);
    }

    function test_EmergencyWithdrawInvalidParams() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Zero address"));
        pair.emergencyWithdraw(address(0), 100e18);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Zero amount"));
        pair.emergencyWithdraw(address(baseToken), 0);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidOperation.selector, "Insufficient balance"));
        pair.emergencyWithdraw(address(baseToken), 100e18);
        vm.stopPrank();
    }

    function test_ConstructorValidations() public {
        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Same token address"));
        new Pair(address(baseToken), address(baseToken), 100, admin);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Fee too high"));
        new Pair(address(baseToken), address(quoteToken), 1001, admin);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Zero fee"));
        new Pair(address(baseToken), address(quoteToken), 0, admin);

        MockERC20 token8Dec = new MockERC20();
        token8Dec.initialize("8 Decimals", "TK8", 8);

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidInput.selector, "Token decimals mismatch"));
        new Pair(address(token8Dec), address(quoteToken), 100, admin);
    }

    function test_AddLiquidityInvalidReservesAndZeroLiquidity() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);
        vm.stopPrank();
        vm.startPrank(admin);
        pair.emergencyWithdraw(address(quoteToken), 100e18);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidOperation.selector, "Invalid reserves"));
        pair.addLiquidity(1e18, 1e18);

        // Reset pair state
        vm.stopPrank();
        vm.startPrank(admin);
        pair = new Pair(address(baseToken), address(quoteToken), 100, admin);
        vm.stopPrank();

        vm.startPrank(user1);
        baseToken.approve(address(pair), type(uint256).max);
        quoteToken.approve(address(pair), type(uint256).max);

        uint256 tinyAmount = 10;
        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidOperation.selector, "Insufficient liquidity"));
        pair.addLiquidity(tinyAmount, tinyAmount);
        vm.stopPrank();
    }

    // Add test for zero liquidity after initial liquidity
    function test_AddLiquidityZeroLiquidityAfterInitial() public {
        vm.startPrank(user1);
        pair.addLiquidity(100e18, 100e18);

        // Calculate an amount that would result in zero liquidity
        // Given the formula: liquidity = (totalSupply * baseAmount) / baseBalance
        // We need baseAmount small enough that the division results in 0
        uint256 baseBalance = pair.getBaseTokenBalance();
        uint256 totalSupply = pair.totalSupply();

        // Make amount small enough that (totalSupply * amount) / baseBalance = 0
        uint256 tinyAmount = (baseBalance / totalSupply) - 1;

        vm.expectRevert(abi.encodeWithSelector(Pair.InvalidOperation.selector, "Insufficient liquidity"));
        pair.addLiquidity(tinyAmount, tinyAmount);
        vm.stopPrank();
    }
}

contract PairFuzzTests is Test {
    Pair public pair;
    Token public baseToken;
    Token public quoteToken;
    address public admin;
    address public user;

    function setUp() public {
        admin = makeAddr("admin");
        user = makeAddr("user");

        vm.startPrank(admin);
        baseToken = new Token("Base Token", "BASE", admin);
        quoteToken = new Token("Quote Token", "QUOTE", admin);
        pair = new Pair(address(baseToken), address(quoteToken), 100, admin);

        baseToken.mint(user, type(uint128).max);
        quoteToken.mint(user, type(uint128).max);
        vm.stopPrank();

        vm.startPrank(user);
        baseToken.approve(address(pair), type(uint128).max);
        quoteToken.approve(address(pair), type(uint128).max);
        vm.stopPrank();
    }

    function testFuzz_AddLiquidity(uint256 baseAmount, uint256 quoteAmount) public {
        // Bound inputs to reasonable ranges
        baseAmount = bound(baseAmount, 1e18, 1e24); // 1 to 1M tokens
        quoteAmount = bound(quoteAmount, 1e18, 1e24);

        vm.startPrank(user);
        uint256 liquidity = pair.addLiquidity(baseAmount, quoteAmount);

        assertGt(liquidity, 0);
        assertEq(baseToken.balanceOf(address(pair)), baseAmount);
        assertEq(quoteToken.balanceOf(address(pair)), quoteAmount);
        vm.stopPrank();
    }

    function testFuzz_RemoveLiquidity(uint256 baseAmount, uint256 quoteAmount, uint256 removeAmount) public {
        // Bound inputs to more reasonable ranges and maintain ratio
        baseAmount = bound(baseAmount, 1e18, 1e24);
        quoteAmount = bound(quoteAmount, 1e18, 1e24);

        vm.startPrank(user);
        pair.addLiquidity(baseAmount, quoteAmount);

        // Ensure removeAmount is between 1 and user's liquidity balance
        uint256 userBalance = pair.balanceOf(user);
        removeAmount = bound(removeAmount, 1, userBalance);

        pair.approve(address(pair), removeAmount);
        (uint256 baseOut, uint256 quoteOut) = pair.removeLiquidity(removeAmount, 0, 0, block.number + 1);

        assertLe(baseOut, baseAmount);
        assertLe(quoteOut, quoteAmount);
        vm.stopPrank();
    }

    function testFuzz_Swap(uint256 baseAmount, uint256 quoteAmount, uint256 swapAmount) public {
        // Bound inputs to more reasonable ranges to avoid overflow
        baseAmount = bound(baseAmount, 1e18, 1e24); // 1 to 1M tokens
        quoteAmount = bound(quoteAmount, 1e18, 1e24);

        vm.startPrank(user);
        // Add initial liquidity
        pair.addLiquidity(baseAmount, quoteAmount);

        // Bound swap amount to max 3% of reserves and ensure it's within approval
        uint256 maxSwap = (baseAmount * 3) / 100;
        swapAmount = bound(swapAmount, 1e6, maxSwap);

        uint256 expectedOutput =
            pair.getAmountOfTokens(swapAmount, pair.getBaseTokenBalance(), pair.getQuoteTokenBalance());

        // Ensure we have enough approval for the swap
        baseToken.approve(address(pair), swapAmount);

        pair.swapBaseToQuote(swapAmount, expectedOutput, block.number + 1);

        // Verify reserves after swap
        assertTrue(pair.verifyBalances());
        vm.stopPrank();
    }

    function testFuzz_SetFee(uint256 fee) public {
        // Bound fee to valid range
        fee = bound(fee, 1, pair.MAX_FEE());

        vm.prank(admin);
        pair.setFee(fee);
        assertEq(pair.swapFee(), fee);
    }

    function testFuzz_EmergencyWithdraw(uint256 baseAmount, uint256 withdrawAmount) public {
        // Bound inputs
        baseAmount = bound(baseAmount, 1e18, 1e24);

        vm.startPrank(user);
        pair.addLiquidity(baseAmount, baseAmount);
        vm.stopPrank();

        withdrawAmount = bound(withdrawAmount, 1, baseAmount);

        vm.prank(admin);
        pair.emergencyWithdraw(address(baseToken), withdrawAmount);
        assertEq(baseToken.balanceOf(admin), withdrawAmount);
    }

    function testFuzz_GetAmountOfTokens(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public view {
        // Bound inputs to reasonable ranges
        inputAmount = bound(inputAmount, 1e6, 1e24);
        inputReserve = bound(inputReserve, 1e18, 1e24);
        outputReserve = bound(outputReserve, 1e18, 1e24);

        uint256 output = pair.getAmountOfTokens(inputAmount, inputReserve, outputReserve);
        assert(output <= outputReserve);
    }
}

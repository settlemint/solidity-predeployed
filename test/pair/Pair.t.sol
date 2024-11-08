// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Pair} from "../../contracts/pair/Pair.sol";
import {Token} from "../../contracts/token/Token.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract PairTest is Test {
    Pair public pair;
    Token public baseToken;
    Token public quoteToken;
    address public admin;
    address public user1;
    address public user2;

    event Mint(address indexed sender, uint256 baseAmount, uint256 quoteAmount, uint256 liquidity);
    event Burn(address indexed sender, uint256 baseAmount, uint256 quoteAmount, address indexed to, uint256 liquidity);
    event Swap(address indexed sender, uint256 baseAmountIn, uint256 quoteAmountIn, uint256 baseAmountOut, uint256 quoteAmountOut, address indexed to);
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

    function test_InitialState() public {
        assertEq(address(pair.baseToken()), address(baseToken));
        assertEq(address(pair.quoteToken()), address(quoteToken));
        assertEq(pair.swapFee(), 100);
        assertTrue(pair.hasRole(pair.ADMIN_ROLE(), admin));
    }

    function test_AddInitialLiquidity() public {
        vm.startPrank(user1);
        
        uint256 baseAmount = 100e18;
        uint256 quoteAmount = 100e18;
        
        uint256 liquidity = pair.addLiquidity(baseAmount, quoteAmount);
        
        // First liquidity provider gets the full amount
        assertEq(liquidity, 100e18);
        // But their balance is liquidity - MINIMUM_LIQUIDITY
        assertEq(pair.balanceOf(user1), 99999999999999999000);
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
        uint256 liquidity = pair.addLiquidity(100e18, 100e18);
        
        // Need to approve pair contract to burn LP tokens
        pair.approve(address(pair), pair.balanceOf(user1));
        
        (uint256 baseAmount, uint256 quoteAmount) = pair.removeLiquidity(
            pair.balanceOf(user1),
            0,
            0,
            block.number + 1
        );
        
        // Can't remove MINIMUM_LIQUIDITY
        assertEq(baseAmount, 99999999999999999000);
        assertEq(quoteAmount, 99999999999999999000);
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
        uint256 expectedOutput = pair.getAmountOfTokens(
            baseAmount,
            pair.getBaseTokenBalance(),
            pair.getQuoteTokenBalance()
        );
        
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
        uint256 expectedOutput = pair.getAmountOfTokens(
            quoteAmount,
            pair.getQuoteTokenBalance(),
            pair.getBaseTokenBalance()
        );
        
        vm.expectEmit(true, true, true, true);
        emit Swap(user2, 0, quoteAmount, expectedOutput, 0, user2);
        
        pair.swapQuoteToBase(quoteAmount, expectedOutput, block.number + 1);
        assertGt(baseToken.balanceOf(user2), 990e18);
        vm.stopPrank();
    }

    function test_SetFee() public {
        vm.prank(address(pair.timelock()));
        
        vm.expectEmit(true, true, true, true);
        emit FeeUpdated(100, 200);
        
        pair.setFee(200);
        assertEq(pair.swapFee(), 200);
    }

    function testFail_SetFeeUnauthorized() public {
        vm.prank(admin);
        pair.setFee(200);
    }

    function test_EmergencyWithdraw() public {
        vm.startPrank(admin);
        baseToken.mint(address(pair), 100e18);
        
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdraw(address(baseToken), 100e18);
        
        pair.emergencyWithdraw(address(baseToken), 100e18);
        assertEq(baseToken.balanceOf(admin), 100e18);
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
}

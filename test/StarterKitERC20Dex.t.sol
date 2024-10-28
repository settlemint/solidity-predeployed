// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import {StarterKitERC20Dex} from "../contracts/StarterKitERC20Dex.sol";
import {StarterKitERC20} from "../contracts/StarterKitERC20.sol";

contract StarterKitERC20DexTest is Test {
  StarterKitERC20Dex internal dex;
  StarterKitERC20 internal baseToken;
  StarterKitERC20 internal quoteToken;
  address internal owner;
  address internal user1;
  address internal user2;

  uint256 internal constant INITIAL_FEE = 30; // 0.3%
  uint256 internal constant INITIAL_LIQUIDITY = 1000000 ether;

  function setUp() public {
    owner = address(this);
    user1 = makeAddr("user1");
    user2 = makeAddr("user2");

    baseToken = new StarterKitERC20("Base Token", "BASE", owner);
    quoteToken = new StarterKitERC20("Quote Token", "QUOTE", owner);

    dex = new StarterKitERC20Dex(
      address(baseToken),
      address(quoteToken),
      INITIAL_FEE
    );

    // Mint tokens to users
    baseToken.mint(owner, INITIAL_LIQUIDITY * 10);
    quoteToken.mint(owner, INITIAL_LIQUIDITY * 10);
    baseToken.mint(user1, INITIAL_LIQUIDITY);
    quoteToken.mint(user1, INITIAL_LIQUIDITY);
    baseToken.mint(user2, INITIAL_LIQUIDITY);
    quoteToken.mint(user2, INITIAL_LIQUIDITY);
  }

  function test_Constructor() public {
    assertEq(address(dex.baseToken()), address(baseToken));
    assertEq(address(dex.quoteToken()), address(quoteToken));
    assertEq(dex.swapFee(), INITIAL_FEE);
  }

  function test_RevertIf_SameTokenAddress() public {
    vm.expectRevert(abi.encodeWithSelector(StarterKitERC20Dex.SameTokenAddress.selector, address(baseToken)));
    new StarterKitERC20Dex(address(baseToken), address(baseToken), INITIAL_FEE);
  }

  function test_RevertIf_ZeroAddress() public {
    vm.expectRevert(StarterKitERC20Dex.ZeroAddress.selector);
    new StarterKitERC20Dex(address(0), address(quoteToken), INITIAL_FEE);

    vm.expectRevert(StarterKitERC20Dex.ZeroAddress.selector);
    new StarterKitERC20Dex(address(baseToken), address(0), INITIAL_FEE);
  }

  function test_AddInitialLiquidity() public {
    uint256 baseAmount = 1000 ether;
    uint256 quoteAmount = 1000 ether;

    baseToken.approve(address(dex), baseAmount);
    quoteToken.approve(address(dex), quoteAmount);

    uint256 liquidity = dex.addLiquidity(baseAmount, quoteAmount);
    assertEq(liquidity, baseAmount);
    assertEq(dex.balanceOf(address(this)), baseAmount);
    assertEq(dex.getBaseTokenBalance(), baseAmount);
    assertEq(dex.getQuoteTokenBalance(), quoteAmount);
  }

  function test_AddSubsequentLiquidity() public {
    // Add initial liquidity
    uint256 initialBase = 1000 ether;
    uint256 initialQuote = 1000 ether;
    baseToken.approve(address(dex), initialBase);
    quoteToken.approve(address(dex), initialQuote);
    dex.addLiquidity(initialBase, initialQuote);

    // Add more liquidity
    uint256 baseAmount = 500 ether;
    uint256 quoteAmount = 500 ether;
    baseToken.approve(address(dex), baseAmount);
    quoteToken.approve(address(dex), quoteAmount);

    uint256 liquidity = dex.addLiquidity(baseAmount, quoteAmount);
    assertEq(liquidity, 500 ether);
  }

  function test_RemoveLiquidity() public {
    uint256 baseAmount = 1000 ether;
    uint256 quoteAmount = 1000 ether;

    baseToken.approve(address(dex), baseAmount);
    quoteToken.approve(address(dex), quoteAmount);
    uint256 liquidity = dex.addLiquidity(baseAmount, quoteAmount);

    (uint256 baseReceived, uint256 quoteReceived) = dex.removeLiquidity(
      liquidity,
      0,
      0,
      block.timestamp + 1
    );

    assertEq(baseReceived, baseAmount);
    assertEq(quoteReceived, quoteAmount);
    assertEq(dex.balanceOf(address(this)), 0);
  }

  function test_SwapBaseToQuote() public {
    // Add initial liquidity
    uint256 baseAmount = 1000 ether;
    uint256 quoteAmount = 1000 ether;
    baseToken.approve(address(dex), baseAmount);
    quoteToken.approve(address(dex), quoteAmount);
    dex.addLiquidity(baseAmount, quoteAmount);

    // Perform swap
    uint256 swapAmount = 10 ether;
    baseToken.approve(address(dex), swapAmount);
    uint256 expectedOutput = dex.getAmountOfTokens(
      swapAmount,
      dex.getBaseTokenBalance(),
      dex.getQuoteTokenBalance()
    );

    vm.prank(user1);
    baseToken.approve(address(dex), swapAmount);
    vm.prank(user1);
    dex.swapBaseToQuote(swapAmount, expectedOutput, block.timestamp + 1);

    assertGt(quoteToken.balanceOf(user1), 0);
  }

  function test_SwapQuoteToBase() public {
    // Add initial liquidity
    uint256 baseAmount = 1000 ether;
    uint256 quoteAmount = 1000 ether;
    baseToken.approve(address(dex), baseAmount);
    quoteToken.approve(address(dex), quoteAmount);
    dex.addLiquidity(baseAmount, quoteAmount);

    // Perform swap
    uint256 swapAmount = 10 ether;
    uint256 expectedOutput = dex.getAmountOfTokens(
      swapAmount,
      dex.getQuoteTokenBalance(),
      dex.getBaseTokenBalance()
    );

    vm.startPrank(user1);
    quoteToken.approve(address(dex), swapAmount);
    dex.swapQuoteToBase(swapAmount, expectedOutput, block.timestamp + 1);
    vm.stopPrank();

    assertGt(baseToken.balanceOf(user1), 0);
  }

  function test_PauseUnpause() public {
    assertTrue(!dex.paused());

    dex.pause();
    assertTrue(dex.paused());

    dex.unpause();
    assertTrue(!dex.paused());
  }

  function test_RevertIf_NonOwnerPause() public {
    vm.prank(user1);
    vm.expectRevert();
    dex.pause();
  }

  function test_EmergencyWithdraw() public {
    uint256 baseAmount = 1000 ether;
    uint256 quoteAmount = 1000 ether;

    baseToken.approve(address(dex), baseAmount);
    quoteToken.approve(address(dex), quoteAmount);
    dex.addLiquidity(baseAmount, quoteAmount);

    uint256 withdrawAmount = 100 ether;
    uint256 balanceBefore = baseToken.balanceOf(address(this));
    dex.emergencyWithdraw(address(baseToken), withdrawAmount);
    uint256 balanceAfter = baseToken.balanceOf(address(this));

    assertEq(balanceAfter - balanceBefore, withdrawAmount);
  }

  function test_RevertIf_NonOwnerEmergencyWithdraw() public {
    vm.prank(user1);
    vm.expectRevert();
    dex.emergencyWithdraw(address(baseToken), 100 ether);
  }
}

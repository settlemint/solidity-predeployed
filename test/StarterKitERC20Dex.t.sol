// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StarterKitERC20Dex } from "../contracts/StarterKitERC20Dex.sol";
import { StarterKitERC20 } from "../contracts/StarterKitERC20.sol";

contract StarterKitERC20DexTest is Test {
    StarterKitERC20Dex public dex;
    StarterKitERC20 public baseToken;
    StarterKitERC20 public quoteToken;
    StarterKitERC20 public invalidDecimalToken;
    address public admin;
    uint256 public constant INITIAL_FEE = 30;

    function setUp() public {
        admin = address(this);
        baseToken = new StarterKitERC20(
            "Base Token",
            "BASE",
            admin
        );
        quoteToken = new StarterKitERC20(
            "Quote Token",
            "QUOTE",
            admin
        );

        dex = new StarterKitERC20Dex(
            address(baseToken),
            address(quoteToken),
            INITIAL_FEE,
            admin
        );

        // Mint initial tokens
        baseToken.mint(admin, 1000000e18);
        quoteToken.mint(admin, 1000000e18);
    }

    function testConstructorDecimalsMismatch() public {
        // Create a mock contract to simulate different decimals since we can't modify StarterKitERC20 decimals
        vm.mockCall(
            address(baseToken),
            abi.encodeWithSignature("decimals()"),
            abi.encode(6)
        );

        vm.expectRevert(StarterKitERC20Dex.TokenDecimalsMismatch.selector);
        new StarterKitERC20Dex(
            address(baseToken),
            address(quoteToken),
            INITIAL_FEE,
            admin
        );
    }

    function testAddLiquidityMaxTokenAmount() public {
        uint256 maxAmount = type(uint128).max;
        vm.expectRevert(StarterKitERC20Dex.MaxTokenAmountExceeded.selector);
        dex.addLiquidity(maxAmount + 1, 1000e18);
    }

    function testVerifyBalances() public {
        baseToken.approve(address(dex), 1000e18);
        quoteToken.approve(address(dex), 1000e18);
        dex.addLiquidity(1000e18, 1000e18);

        assertTrue(dex.verifyBalances());
    }

    function testSwapBaseToQuoteMaxAmount() public {
        // Add initial liquidity
        baseToken.approve(address(dex), 10000e18);
        quoteToken.approve(address(dex), 10000e18);
        dex.addLiquidity(10000e18, 10000e18);

        // Try to swap more than 3% of pool
        uint256 maxSwapAmount = (10000e18 * 3) / 100;
        vm.expectRevert(abi.encodeWithSelector(
            StarterKitERC20Dex.SwapAmountTooLarge.selector,
            maxSwapAmount + 1,
            maxSwapAmount
        ));
        dex.swapBaseToQuote(maxSwapAmount + 1, 0, block.number + 1);
    }

    function testGetBaseToQuotePrice() public {
        baseToken.approve(address(dex), 1000e18);
        quoteToken.approve(address(dex), 1000e18);
        dex.addLiquidity(1000e18, 1000e18);

        uint256 baseAmount = 100e18;
        uint256 expectedQuote = dex.getBaseToQuotePrice(baseAmount);
        assertTrue(expectedQuote > 0);
    }

    function testManipulateBalanceFails() public {
        baseToken.approve(address(dex), 1000e18);
        quoteToken.approve(address(dex), 1000e18);
        dex.addLiquidity(1000e18, 1000e18);

        // Try to manipulate balance by direct mint
        baseToken.mint(address(dex), 100e18);

        // Verify that balances are detected as invalid
        assertFalse(dex.verifyBalances());

        // Attempt to remove liquidity should fail
        vm.expectRevert(StarterKitERC20Dex.BalanceMismatch.selector);
        dex.removeLiquidity(100e18, 0, 0, block.number + 1);
    }

    function testBasicSwap() public {
        // Add initial liquidity
        baseToken.approve(address(dex), 1000e18);
        quoteToken.approve(address(dex), 1000e18);
        dex.addLiquidity(1000e18, 1000e18);

        // Perform swap
        uint256 swapAmount = 2e19;
        baseToken.approve(address(dex), swapAmount);
        uint256 expectedQuote = dex.getBaseToQuotePrice(swapAmount);

        uint256 balanceBefore = quoteToken.balanceOf(address(this));
        dex.swapBaseToQuote(swapAmount, expectedQuote * 95 / 100, block.number + 1);
        uint256 balanceAfter = quoteToken.balanceOf(address(this));

        assertTrue(balanceAfter > balanceBefore);
    }

    // Existing tests remain unchanged...
}

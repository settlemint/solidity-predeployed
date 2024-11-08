// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Sale} from "../../contracts/sale/Sale.sol";
import {Token} from "../../contracts/token/Token.sol";

contract SaleTest is Test {
    Sale public sale;
    Token public saleToken;
    Token public paymentToken;
    address public admin;
    address public user1;
    address public user2;

    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TokensSold(address indexed buyer, uint256 saleTokenAmount, uint256 paymentTokenAmount);
    event EmergencyWithdraw(address token, uint256 amount);
    event SaleTokensDeposited(uint256 amount);

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(admin);
        saleToken = new Token("Sale Token", "SALE", admin);
        paymentToken = new Token("Payment Token", "PAY", admin);
        sale = new Sale(address(saleToken), address(paymentToken), 1e18, admin);

        // Mint tokens for testing
        saleToken.mint(admin, 1000e18);
        paymentToken.mint(user1, 1000e18);

        // Approve sale contract
        saleToken.approve(address(sale), type(uint256).max);
        vm.stopPrank();

        vm.prank(user1);
        paymentToken.approve(address(sale), type(uint256).max);
    }

    function test_InitialState() public view {
        assertEq(address(sale.saleToken()), address(saleToken));
        assertEq(address(sale.paymentToken()), address(paymentToken));
        assertEq(sale.price(), 1e18);
        assertTrue(sale.hasRole(sale.ADMIN_ROLE(), admin));
    }

    function test_SetPrice() public {
        vm.startPrank(address(sale.timelock()));

        vm.expectEmit(true, true, true, true);
        emit PriceUpdated(1e18, 2e18);

        sale.setPrice(2e18);
        assertEq(sale.price(), 2e18);
        vm.stopPrank();
    }

    function testFail_SetPriceUnauthorized() public {
        vm.prank(admin);
        sale.setPrice(2e18);
    }

    function test_BuyTokens() public {
        vm.startPrank(admin);
        sale.depositSaleTokens(100e18);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 buyAmount = 10e18;
        uint256 paymentAmount = (buyAmount * sale.price()) / 1e18;

        vm.expectEmit(true, true, true, true);
        emit TokensSold(user1, buyAmount, paymentAmount);

        sale.buyTokens(buyAmount);

        assertEq(saleToken.balanceOf(user1), buyAmount);
        assertEq(paymentToken.balanceOf(address(sale)), paymentAmount);
        vm.stopPrank();
    }

    function testFail_BuyTokensInsufficientBalance() public {
        vm.prank(user1);
        sale.buyTokens(10e18);
    }

    function test_EmergencyWithdraw() public {
        vm.startPrank(admin);
        paymentToken.mint(address(sale), 100e18);

        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdraw(address(paymentToken), 100e18);

        sale.emergencyWithdraw(address(paymentToken), 100e18);
        assertEq(paymentToken.balanceOf(admin), 100e18);
        vm.stopPrank();
    }

    function test_DepositSaleTokens() public {
        vm.startPrank(admin);

        vm.expectEmit(true, true, true, true);
        emit SaleTokensDeposited(100e18);

        sale.depositSaleTokens(100e18);
        assertEq(saleToken.balanceOf(address(sale)), 100e18);
        vm.stopPrank();
    }

    function test_PauseUnpause() public {
        vm.startPrank(admin);
        sale.pause();
        assertTrue(sale.paused());

        vm.expectRevert();
        sale.buyTokens(1e18);

        sale.unpause();
        assertFalse(sale.paused());
        vm.stopPrank();
    }

    function test_RevertWhen_AdminIsZeroAddress() public {
        vm.expectRevert(Sale.ZeroAddress.selector);
        new Sale(address(saleToken), address(paymentToken), 1e18, address(0));
    }

    function test_RevertWhen_SaleTokenIsZeroAddress() public {
        vm.expectRevert(Sale.ZeroAddress.selector);
        new Sale(address(0), address(paymentToken), 1e18, admin);
    }

    function test_RevertWhen_PaymentTokenIsZeroAddress() public {
        vm.expectRevert(Sale.ZeroAddress.selector);
        new Sale(address(saleToken), address(0), 1e18, admin);
    }

    function test_RevertWhen_SameTokenAddresses() public {
        vm.expectRevert(abi.encodeWithSelector(Sale.SameTokenAddress.selector, address(saleToken)));
        new Sale(address(saleToken), address(saleToken), 1e18, admin);
    }

    function test_RevertWhen_InitialPriceIsZero() public {
        vm.expectRevert(Sale.InvalidPrice.selector);
        new Sale(address(saleToken), address(paymentToken), 0, admin);
    }

    function test_RevertWhen_SetPriceToZero() public {
        vm.prank(address(sale.timelock()));
        vm.expectRevert(Sale.InvalidPrice.selector);
        sale.setPrice(0);
    }

    function test_RevertWhen_EmergencyWithdrawZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(Sale.ZeroAddress.selector);
        sale.emergencyWithdraw(address(0), 100e18);
    }

    function test_RevertWhen_EmergencyWithdrawZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(Sale.InvalidAmount.selector);
        sale.emergencyWithdraw(address(paymentToken), 0);
    }

    function test_RevertWhen_EmergencyWithdrawInsufficientBalance() public {
        vm.prank(admin);
        vm.expectRevert(Sale.InsufficientBalance.selector);
        sale.emergencyWithdraw(address(paymentToken), 1000e18);
    }

    function test_RevertWhen_DepositZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(Sale.InvalidDepositAmount.selector);
        sale.depositSaleTokens(0);
    }

    function test_RevertWhen_BuyTokensAmountTooLarge() public {
        uint256 largeAmount = type(uint128).max;

        vm.startPrank(admin);
        // Mint and deposit sale tokens
        saleToken.mint(admin, largeAmount);
        sale.depositSaleTokens(largeAmount);

        // Mint payment tokens to user1
        paymentToken.mint(user1, largeAmount);
        vm.stopPrank();

        vm.startPrank(user1);
        // Approve large amount of payment tokens
        paymentToken.approve(address(sale), largeAmount);

        vm.expectRevert(Sale.AmountTooLarge.selector);
        sale.buyTokens(largeAmount + 1);
        vm.stopPrank();
    }

    function test_RevertWhen_BuyZeroTokens() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidTokenAmount.selector, 0));
        sale.buyTokens(0);
    }
}

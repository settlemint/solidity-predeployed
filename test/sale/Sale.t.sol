// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Sale } from "../../contracts/sale/Sale.sol";
import { Token } from "../../contracts/token/Token.sol";

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
        assertTrue(sale.hasRole(sale.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_SetPrice() public {
        vm.startPrank(admin);

        vm.expectEmit(true, true, true, true);
        emit PriceUpdated(1e18, 2e18);

        sale.setPrice(2e18);
        assertEq(sale.price(), 2e18);
        vm.stopPrank();
    }

    function testFail_SetPriceUnauthorized() public {
        vm.prank(user1);
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
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Zero admin address"));
        new Sale(address(saleToken), address(paymentToken), 1e18, address(0));
    }

    function test_RevertWhen_SaleTokenIsZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Zero token address"));
        new Sale(address(0), address(paymentToken), 1e18, admin);
    }

    function test_RevertWhen_PaymentTokenIsZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Zero token address"));
        new Sale(address(saleToken), address(0), 1e18, admin);
    }

    function test_RevertWhen_SameTokenAddresses() public {
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Same token address"));
        new Sale(address(saleToken), address(saleToken), 1e18, admin);
    }

    function test_RevertWhen_InitialPriceIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Zero price"));
        new Sale(address(saleToken), address(paymentToken), 0, admin);
    }

    function test_RevertWhen_SetPriceToZero() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Zero price"));
        sale.setPrice(0);
    }

    function test_RevertWhen_EmergencyWithdrawZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Zero token address"));
        sale.emergencyWithdraw(address(0), 100e18);
    }

    function test_RevertWhen_EmergencyWithdrawZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Zero amount"));
        sale.emergencyWithdraw(address(paymentToken), 0);
    }

    function test_RevertWhen_EmergencyWithdrawInsufficientBalance() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidOperation.selector, "Insufficient balance"));
        sale.emergencyWithdraw(address(paymentToken), 1000e18);
    }

    function test_RevertWhen_DepositZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Zero deposit amount"));
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

        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Amount too large"));
        sale.buyTokens(largeAmount + 1);
        vm.stopPrank();
    }

    function test_RevertWhen_BuyZeroTokens() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Sale.InvalidInput.selector, "Zero amount"));
        sale.buyTokens(0);
    }
}

contract SaleFuzzTests is Test {
    Sale public sale;
    Token public saleToken;
    Token public paymentToken;
    address public admin;
    address public user;

    function setUp() public {
        admin = makeAddr("admin");
        user = makeAddr("user");

        vm.startPrank(admin);
        saleToken = new Token("Sale Token", "SALE", admin);
        paymentToken = new Token("Payment Token", "PAY", admin);
        sale = new Sale(address(saleToken), address(paymentToken), 1e18, admin);

        // Mint tokens for testing
        saleToken.mint(admin, type(uint128).max);
        paymentToken.mint(user, type(uint128).max);

        // Approve sale contract
        saleToken.approve(address(sale), type(uint128).max);
        vm.stopPrank();

        vm.prank(user);
        paymentToken.approve(address(sale), type(uint128).max);
    }

    function testFuzz_BuyTokens(uint256 amount) public {
        // Bound amount to reasonable range
        amount = bound(amount, 1000, type(uint128).max);

        vm.startPrank(admin);
        sale.depositSaleTokens(amount);
        vm.stopPrank();

        vm.startPrank(user);
        sale.buyTokens(amount);

        assertEq(saleToken.balanceOf(user), amount);
        assertEq(paymentToken.balanceOf(address(sale)), (amount * sale.price()) / 1e18);
        vm.stopPrank();
    }

    function testFuzz_SetPrice(uint256 newPrice) public {
        // Bound price to reasonable range
        newPrice = bound(newPrice, 1, type(uint128).max);

        vm.startPrank(admin);
        sale.setPrice(newPrice);
        assertEq(sale.price(), newPrice);
        vm.stopPrank();
    }

    function testFuzz_EmergencyWithdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        // Bound amounts
        depositAmount = bound(depositAmount, 1000, type(uint128).max);

        vm.startPrank(admin);
        // Clear any previous balance
        uint256 initialBalance = saleToken.balanceOf(admin);
        if (initialBalance > 0) {
            saleToken.burn(admin, initialBalance);
        }

        // Mint exact amount needed for test
        saleToken.mint(admin, depositAmount);
        sale.depositSaleTokens(depositAmount);

        withdrawAmount = bound(withdrawAmount, 1, depositAmount);
        uint256 balanceBeforeWithdraw = saleToken.balanceOf(admin);

        sale.emergencyWithdraw(address(saleToken), withdrawAmount);

        // Check that admin's balance increased by exactly withdrawAmount
        assertEq(saleToken.balanceOf(admin), balanceBeforeWithdraw + withdrawAmount);
        vm.stopPrank();
    }

    function testFuzz_DepositSaleTokens(uint256 amount) public {
        // Bound amount
        amount = bound(amount, 1000, type(uint128).max);

        vm.startPrank(admin);
        sale.depositSaleTokens(amount);
        assertEq(saleToken.balanceOf(address(sale)), amount);
        vm.stopPrank();
    }
}

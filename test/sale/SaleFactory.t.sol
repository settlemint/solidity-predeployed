// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SaleFactory} from "../../contracts/sale/SaleFactory.sol";
import {Sale} from "../../contracts/sale/Sale.sol";
import {Token} from "../../contracts/token/Token.sol";

contract SaleFactoryTest is Test {
    SaleFactory public factory;
    Token public saleToken;
    Token public paymentToken;
    address public admin;
    address public user1;

    event SaleCreated(
        address indexed saleAddress,
        address indexed saleToken,
        address indexed paymentToken,
        uint256 price
    );

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");

        vm.startPrank(admin);
        factory = new SaleFactory(admin);
        saleToken = new Token("Sale Token", "SALE", admin);
        paymentToken = new Token("Payment Token", "PAY", admin);
        vm.stopPrank();
    }

    function test_CreateSale() public {
        vm.startPrank(admin);
        address sale = factory.createSale(address(saleToken), address(paymentToken), 100);

        assertNotEq(sale, address(0));
        assertEq(factory.getSale(address(saleToken)), sale);
        assertEq(factory.allSalesLength(), 1);
        assertEq(factory.allSales(0), sale);
        vm.stopPrank();
    }

    function test_CreateSaleWithZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(SaleFactory.InvalidInput.selector, "Zero address"));
        factory.createSale(address(0), address(paymentToken), 100);
        vm.stopPrank();
    }

    function test_CreateSaleWithIdenticalTokens() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(SaleFactory.InvalidInput.selector, "Identical addresses"));
        factory.createSale(address(saleToken), address(saleToken), 100);
        vm.stopPrank();
    }

    function test_CreateDuplicateSale() public {
        vm.startPrank(admin);
        factory.createSale(address(saleToken), address(paymentToken), 100);
        vm.expectRevert(abi.encodeWithSelector(SaleFactory.InvalidOperation.selector, "Sale exists"));
        factory.createSale(address(saleToken), address(paymentToken), 200);
        vm.stopPrank();
    }

    function test_AllSalesLength() public {
        assertEq(factory.allSalesLength(), 0);

        vm.startPrank(admin);
        Token newToken = new Token("New Token", "NEW", admin);

        factory.createSale(address(saleToken), address(paymentToken), 100);
        assertEq(factory.allSalesLength(), 1);

        factory.createSale(address(newToken), address(paymentToken), 100);
        assertEq(factory.allSalesLength(), 2);
        vm.stopPrank();
    }

    function testFail_CreateSaleUnauthorized() public {
        vm.prank(user1);
        factory.createSale(address(saleToken), address(paymentToken), 100);
    }
}

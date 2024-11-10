// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { SaleFactory } from "../../contracts/sale/SaleFactory.sol";
import { Sale } from "../../contracts/sale/Sale.sol";
import { Token } from "../../contracts/token/Token.sol";

contract SaleFactoryTest is Test {
    SaleFactory public factory;
    Token public saleToken;
    Token public paymentToken;
    address public admin;
    address public user1;
    address public user9;

    event SaleCreated(
        address indexed saleAddress, address indexed saleToken, address indexed paymentToken, uint256 price
    );

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user9 = makeAddr("user9");
        vm.startPrank(admin);
        factory = new SaleFactory();
        saleToken = new Token("Sale Token", "SALE", admin);
        paymentToken = new Token("Payment Token", "PAY", admin);
        vm.stopPrank();
    }

    function test_CreateSale() public {
        vm.startPrank(admin);
        address sale = factory.createSale(address(saleToken), address(paymentToken), 100, user9);

        assertNotEq(sale, address(0));
        assertEq(factory.getSale(address(saleToken)), sale);
        assertEq(factory.allSalesLength(), 1);
        assertEq(factory.allSales(0), sale);
        vm.stopPrank();
    }

    function test_CreateSaleWithZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(SaleFactory.InvalidInput.selector, "Zero address"));
        factory.createSale(address(0), address(paymentToken), 100, user9);
        vm.stopPrank();
    }

    function test_CreateSaleWithIdenticalTokens() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(SaleFactory.InvalidInput.selector, "Identical addresses"));
        factory.createSale(address(saleToken), address(saleToken), 100, user9);
        vm.stopPrank();
    }

    function test_CreateDuplicateSale() public {
        vm.startPrank(admin);
        factory.createSale(address(saleToken), address(paymentToken), 100, user9);
        vm.expectRevert(abi.encodeWithSelector(SaleFactory.InvalidOperation.selector, "Sale exists"));
        factory.createSale(address(saleToken), address(paymentToken), 200, user9);
        vm.stopPrank();
    }

    function test_AllSalesLength() public {
        assertEq(factory.allSalesLength(), 0);

        vm.startPrank(admin);
        Token newToken = new Token("New Token", "NEW", admin);

        factory.createSale(address(saleToken), address(paymentToken), 100, user9);
        assertEq(factory.allSalesLength(), 1);

        factory.createSale(address(newToken), address(paymentToken), 100, user9);
        assertEq(factory.allSalesLength(), 2);
        vm.stopPrank();
    }
}

contract SaleFactoryFuzzTests is Test {
    SaleFactory public factory;
    Token public saleToken;
    Token public paymentToken;
    address public admin;
    address public user9;

    function setUp() public {
        admin = makeAddr("admin");
        user9 = makeAddr("user9");
        factory = new SaleFactory();
        saleToken = new Token("Sale Token", "SALE", admin);
        paymentToken = new Token("Payment Token", "PAY", admin);
    }

    function testFuzz_CreateMultipleSales(uint256 numSales, uint256 initialPrice) public {
        // Bound inputs to reasonable ranges
        numSales = bound(numSales, 1, 10);
        initialPrice = bound(initialPrice, 1e6, 1e20);

        vm.startPrank(admin);
        address[] memory tokens = new address[](numSales);

        // Create tokens
        for (uint256 i = 0; i < numSales; i++) {
            Token newToken =
                new Token(string.concat("Token", vm.toString(i)), string.concat("TK", vm.toString(i)), admin);
            tokens[i] = address(newToken);
        }

        // Create sales for each token
        for (uint256 i = 0; i < numSales; i++) {
            address sale = factory.createSale(tokens[i], address(paymentToken), initialPrice, user9);
            assertNotEq(sale, address(0));
            assertEq(factory.getSale(tokens[i]), sale);
        }

        assertEq(factory.allSalesLength(), numSales);
        vm.stopPrank();
    }

    function testFuzz_CreateSaleWithDifferentPrices(uint256 price) public {
        // Bound price to reasonable range
        price = bound(price, 1e6, 1e20);

        vm.startPrank(admin);
        address sale = factory.createSale(address(saleToken), address(paymentToken), price, user9);
        assertNotEq(sale, address(0));
        vm.stopPrank();
    }
}

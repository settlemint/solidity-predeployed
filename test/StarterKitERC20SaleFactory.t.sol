// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StarterKitERC20SaleFactory} from "../contracts/StarterKitERC20SaleFactory.sol";
import {StarterKitERC20SaleRegistry} from "../contracts/StarterKitERC20SaleRegistry.sol";
import {StarterKitERC20Sale} from "../contracts/StarterKitERC20Sale.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StarterKitERC20} from "../contracts/StarterKitERC20.sol";

contract StarterKitERC20SaleFactoryTest is Test {
  StarterKitERC20SaleFactory public factory;
  StarterKitERC20SaleRegistry public registry;
  StarterKitERC20 public tokenForSale;
  StarterKitERC20 public tokenForPayment;

  address public owner;
  uint256 public constant PRICE_PER_TOKEN = 1e18;
  uint256 public constant MIN_PURCHASE = 100e18;
  uint256 public constant MAX_PURCHASE = 1000e18;

  function setUp() public {
    owner = makeAddr("owner");
    vm.startPrank(owner);

    registry = new StarterKitERC20SaleRegistry();
    factory = new StarterKitERC20SaleFactory(address(registry));

    tokenForSale = new StarterKitERC20("Sale Token", "SALE", owner);
    tokenForPayment = new StarterKitERC20("Payment Token", "PAY", owner);

    vm.stopPrank();
  }

  function test_CreateSale() public {
    vm.startPrank(owner);

    factory.createSale(
      IERC20(address(tokenForSale)),
      IERC20(address(tokenForPayment)),
      PRICE_PER_TOKEN,
      MIN_PURCHASE,
      MAX_PURCHASE
    );

    address[] memory sales = registry.getSaleList();
    assertEq(sales.length, 1);

    StarterKitERC20Sale sale = StarterKitERC20Sale(sales[0]);
    assertEq(address(sale.TOKEN_FOR_SALE()), address(tokenForSale));
    assertEq(address(sale.TOKEN_FOR_PAYMENT()), address(tokenForPayment));
    assertEq(sale.pricePerToken(), PRICE_PER_TOKEN);
    assertEq(sale.minPurchase(), MIN_PURCHASE);
    assertEq(sale.maxPurchase(), MAX_PURCHASE);
    assertEq(sale.owner(), owner);

    vm.stopPrank();
  }

  function test_CreateMultipleSales() public {
    vm.startPrank(owner);

    factory.createSale(
      IERC20(address(tokenForSale)),
      IERC20(address(tokenForPayment)),
      PRICE_PER_TOKEN,
      MIN_PURCHASE,
      MAX_PURCHASE
    );

    StarterKitERC20 newTokenForSale = new StarterKitERC20("New Sale Token", "NSALE", owner);
    StarterKitERC20 newTokenForPayment = new StarterKitERC20("New Payment Token", "NPAY", owner);

    factory.createSale(
      IERC20(address(newTokenForSale)),
      IERC20(address(newTokenForPayment)),
      PRICE_PER_TOKEN * 2,
      MIN_PURCHASE * 2,
      MAX_PURCHASE * 2
    );

    address[] memory sales = registry.getSaleList();
    assertEq(sales.length, 2);

    StarterKitERC20Sale sale1 = StarterKitERC20Sale(sales[0]);
    StarterKitERC20Sale sale2 = StarterKitERC20Sale(sales[1]);

    assertEq(address(sale1.TOKEN_FOR_SALE()), address(tokenForSale));
    assertEq(address(sale2.TOKEN_FOR_SALE()), address(newTokenForSale));

    vm.stopPrank();
  }
}

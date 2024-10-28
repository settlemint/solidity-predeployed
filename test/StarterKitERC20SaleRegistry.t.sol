// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StarterKitERC20SaleRegistry} from "../contracts/StarterKitERC20SaleRegistry.sol";

contract StarterKitERC20SaleRegistryTest is Test {
  StarterKitERC20SaleRegistry public registry;
  address public saleAddress1;
  address public saleAddress2;

  function setUp() public {
    registry = new StarterKitERC20SaleRegistry();
    saleAddress1 = makeAddr("sale1");
    saleAddress2 = makeAddr("sale2");
  }

  function test_InitialState() public view {
    assertEq(registry.getSaleList().length, 0);
  }

  function test_AddSale() public {
    registry.addSale(saleAddress1);

    address[] memory sales = registry.getSaleList();
    assertEq(sales.length, 1);
    assertEq(sales[0], saleAddress1);
  }

  function test_AddMultipleSales() public {
    registry.addSale(saleAddress1);
    registry.addSale(saleAddress2);

    address[] memory sales = registry.getSaleList();
    assertEq(sales.length, 2);
    assertEq(sales[0], saleAddress1);
    assertEq(sales[1], saleAddress2);
  }

  function test_RevertWhen_AddDuplicateSale() public {
    registry.addSale(saleAddress1);

    vm.expectRevert(abi.encodeWithSelector(
      StarterKitERC20SaleRegistry.SaleAddressAlreadyExists.selector,
      saleAddress1
    ));
    registry.addSale(saleAddress1);
  }

  function test_EmitSaleAddedEvent() public {
    vm.expectEmit(true, false, false, false);
    emit StarterKitERC20SaleRegistry.SaleAdded(saleAddress1);
    registry.addSale(saleAddress1);
  }
}

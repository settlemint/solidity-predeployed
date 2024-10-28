// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StarterKitERC20Sale} from "../contracts/StarterKitERC20Sale.sol";
import {StarterKitERC20} from "../contracts/StarterKitERC20.sol";

contract StarterKitERC20SaleTest is Test {
  StarterKitERC20Sale public sale;
  StarterKitERC20 public tokenForSale;
  StarterKitERC20 public tokenForPayment;

  address public owner;
  address public buyer;

  uint256 public constant INITIAL_SUPPLY = 1_000_000 * 1e18;
  uint256 public constant PRICE_PER_TOKEN = 2 * 1e18;
  uint256 public constant MIN_PURCHASE = 100 * 1e18;
  uint256 public constant MAX_PURCHASE = 10_000 * 1e18;

  function setUp() public {
    owner = makeAddr("owner");
    buyer = makeAddr("buyer");

    vm.startPrank(owner);

    tokenForSale = new StarterKitERC20("Sale Token", "SALE", owner);
    tokenForPayment = new StarterKitERC20("Payment Token", "PAY", owner);

    sale = new StarterKitERC20Sale(
      tokenForSale,
      tokenForPayment,
      PRICE_PER_TOKEN,
      MIN_PURCHASE,
      MAX_PURCHASE,
      owner
    );

    tokenForSale.mint(owner, INITIAL_SUPPLY);
    tokenForSale.approve(address(sale), INITIAL_SUPPLY);
    sale.deposit(INITIAL_SUPPLY);

    tokenForPayment.mint(buyer, INITIAL_SUPPLY);

    vm.stopPrank();
  }

  function test_InitialState() public view {
    assertEq(address(sale.TOKEN_FOR_SALE()), address(tokenForSale));
    assertEq(address(sale.TOKEN_FOR_PAYMENT()), address(tokenForPayment));
    assertEq(sale.pricePerToken(), PRICE_PER_TOKEN);
    assertEq(sale.minPurchase(), MIN_PURCHASE);
    assertEq(sale.maxPurchase(), MAX_PURCHASE);
    assertTrue(sale.saleActive());
    assertEq(sale.owner(), owner);
  }

  function test_Buy() public {
    uint256 purchaseAmount = 1000 * 1e18;
    uint256 cost = (purchaseAmount * PRICE_PER_TOKEN) / 1e18;

    vm.startPrank(buyer);
    tokenForPayment.approve(address(sale), cost);

    uint256 buyerInitialBalance = tokenForSale.balanceOf(buyer);
    uint256 ownerInitialBalance = tokenForPayment.balanceOf(owner);

    sale.buy(purchaseAmount);

    assertEq(tokenForSale.balanceOf(buyer), buyerInitialBalance + purchaseAmount);
    assertEq(tokenForPayment.balanceOf(owner), ownerInitialBalance + cost);
    vm.stopPrank();
  }

  function test_RevertWhen_BuyInactiveSale() public {
    vm.prank(owner);
    sale.setSaleStatus(false);

    vm.startPrank(buyer);
    uint256 purchaseAmount = 1000 * 1e18;
    uint256 cost = (purchaseAmount * PRICE_PER_TOKEN) / 1e18;
    tokenForPayment.approve(address(sale), cost);

    vm.expectRevert(StarterKitERC20Sale.SaleNotActive.selector);
    sale.buy(purchaseAmount);
    vm.stopPrank();
  }

  function test_RevertWhen_InsufficientAllowance() public {
    vm.startPrank(buyer);
    uint256 purchaseAmount = 1000 * 1e18;
    uint256 cost = (purchaseAmount * PRICE_PER_TOKEN) / 1e18;

    vm.expectRevert(abi.encodeWithSelector(
      StarterKitERC20Sale.InsufficientAllowance.selector,
      0,
      cost
    ));
    sale.buy(purchaseAmount);
    vm.stopPrank();
  }

  function test_RevertWhen_InvalidAmount() public {
    vm.startPrank(buyer);
    uint256 purchaseAmount = 10 * 1e18; // Below MIN_PURCHASE
    uint256 cost = purchaseAmount * PRICE_PER_TOKEN;
    tokenForPayment.approve(address(sale), cost);

    vm.expectRevert(abi.encodeWithSelector(
      StarterKitERC20Sale.InvalidAmount.selector,
      purchaseAmount
    ));
    sale.buy(purchaseAmount);
    vm.stopPrank();
  }

  function test_UpdatePrice() public {
    uint256 newPrice = 3 * 1e18;

    vm.prank(owner);
    sale.updatePrice(newPrice);

    assertEq(sale.pricePerToken(), newPrice);
  }

  function test_RevertWhen_UpdatePriceToZero() public {
    vm.prank(owner);
    vm.expectRevert(StarterKitERC20Sale.PriceNotGreaterThanZero.selector);
    sale.updatePrice(0);
  }

  function test_SetPurchaseLimits() public {
    uint256 newMin = 200 * 1e18;
    uint256 newMax = 20_000 * 1e18;

    vm.prank(owner);
    sale.setPurchaseLimits(newMin, newMax);

    assertEq(sale.minPurchase(), newMin);
    assertEq(sale.maxPurchase(), newMax);
  }

  function test_RevertWhen_MinExceedsMax() public {
    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(
      StarterKitERC20Sale.MinPurchaseExceedsMax.selector,
      2000 * 1e18,
      1000 * 1e18
    ));
    sale.setPurchaseLimits(2000 * 1e18, 1000 * 1e18);
  }

  function test_RescueToken() public {
    StarterKitERC20 randomToken = new StarterKitERC20("Random", "RND", owner);
    uint256 amount = 1000 * 1e18;

    vm.prank(owner);
    randomToken.mint(address(sale), amount);

    vm.prank(owner);
    sale.rescueToken(randomToken, amount);

    assertEq(randomToken.balanceOf(owner), amount);
  }
}

// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StarterKitERC20DexFactory } from "../contracts/StarterKitERC20DexFactory.sol";
import { StarterKitERC20 } from "../contracts/StarterKitERC20.sol";

contract StarterKitERC20DexFactoryTest is Test {
  StarterKitERC20DexFactory factory;
  StarterKitERC20 token1;
  StarterKitERC20 token2;
  address owner;
  address user1;

  uint256 constant INITIAL_FEE = 30; // 0.3%
  uint256 constant INITIAL_SUPPLY = 1000000 ether;

  function setUp() public {
    owner = address(this);
    user1 = makeAddr("user1");

    factory = new StarterKitERC20DexFactory();
    token1 = new StarterKitERC20("Token 1", "TK1", owner);
    token2 = new StarterKitERC20("Token 2", "TK2", owner);

    token1.mint(owner, INITIAL_SUPPLY);
    token2.mint(owner, INITIAL_SUPPLY);
  }

  function test_CreatePair() public {
    address pair = factory.createPair(address(token1), address(token2));

    assertEq(factory.allPairsLength(), 1);
    assertEq(factory.allPairs(0), pair);
    assertEq(factory.getPair(address(token1), address(token2)), pair);
    assertEq(factory.getPair(address(token2), address(token1)), pair);
  }

  function test_RevertIf_IdenticalAddresses() public {
    vm.expectRevert(StarterKitERC20DexFactory.IdenticalAddresses.selector);
    factory.createPair(address(token1), address(token1));
  }

  function test_RevertIf_ZeroAddress() public {
    vm.expectRevert(StarterKitERC20DexFactory.ZeroAddress.selector);
    factory.createPair(address(0), address(token1));

    vm.expectRevert(StarterKitERC20DexFactory.ZeroAddress.selector);
    factory.createPair(address(token1), address(0));
  }

  function test_RevertIf_PairExists() public {
    factory.createPair(address(token1), address(token2));

    vm.expectRevert(StarterKitERC20DexFactory.PairExists.selector);
    factory.createPair(address(token1), address(token2));
  }

}

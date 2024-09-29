// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StarterKitERC20 } from "../contracts/StarterKitERC20.sol";

contract StarterKitERC20Test is Test {
    StarterKitERC20 public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        token = new StarterKitERC20("Test Token", "TST", owner);
    }

    function testInitialState() public view {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TST");
        assertEq(token.owner(), owner);
        assertEq(token.totalSupply(), 0);
    }

    function testMint() public {
        uint256 amount = 1000 * 10 ** 18;
        token.mint(user1, amount);
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testMintOnlyOwner() public {
        uint256 amount = 1000 * 10 ** 18;
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        token.mint(user2, amount);
    }

    function testTransfer() public {
        uint256 amount = 1000 * 10 ** 18;
        token.mint(user1, amount);

        vm.prank(user1);
        token.transfer(user2, 500 * 10 ** 18);

        assertEq(token.balanceOf(user1), 500 * 10 ** 18);
        assertEq(token.balanceOf(user2), 500 * 10 ** 18);
    }

    function testApproveAndTransferFrom() public {
        uint256 amount = 1000 * 10 ** 18;
        token.mint(user1, amount);

        vm.prank(user1);
        token.approve(user2, 500 * 10 ** 18);

        vm.prank(user2);
        token.transferFrom(user1, user2, 500 * 10 ** 18);

        assertEq(token.balanceOf(user1), 500 * 10 ** 18);
        assertEq(token.balanceOf(user2), 500 * 10 ** 18);
    }
}

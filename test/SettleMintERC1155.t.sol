// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { SettleMintERC1155 } from "../contracts/SettleMintERC1155.sol";

contract SettleMintERC1155Test is Test {
    SettleMintERC1155 public settleMintERC1155;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        settleMintERC1155 = new SettleMintERC1155();
    }

    function testInitialState() public view {
        assertEq(settleMintERC1155.uri(0), "");
    }

    function testSetURI() public {
        string memory newURI = "https://example.com/token/";
        settleMintERC1155.setURI(newURI);
        assertEq(settleMintERC1155.uri(0), newURI);
    }

    function testMint() public {
        uint256 tokenId = 1;
        uint256 amount = 100;
        settleMintERC1155.mint(user1, tokenId, amount, "");
        assertEq(settleMintERC1155.balanceOf(user1, tokenId), amount);
    }

    function testMintBatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;
        settleMintERC1155.mintBatch(user1, ids, amounts, "");
        assertEq(settleMintERC1155.balanceOf(user1, 1), 100);
        assertEq(settleMintERC1155.balanceOf(user1, 2), 200);
    }

    function testBurn() public {
        uint256 tokenId = 1;
        uint256 amount = 100;
        settleMintERC1155.mint(user1, tokenId, amount, "");

        vm.prank(user1);
        settleMintERC1155.burn(user1, tokenId, amount);
        assertEq(settleMintERC1155.balanceOf(user1, tokenId), 0);
    }

    function testBurnBatch() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;
        settleMintERC1155.mintBatch(user1, ids, amounts, "");

        vm.prank(user1);
        settleMintERC1155.burnBatch(user1, ids, amounts);
        assertEq(settleMintERC1155.balanceOf(user1, 1), 0);
        assertEq(settleMintERC1155.balanceOf(user1, 2), 0);
    }

    function testSupply() public {
        uint256 tokenId = 1;
        uint256 amount = 100;
        settleMintERC1155.mint(user1, tokenId, amount, "");
        assertEq(settleMintERC1155.totalSupply(tokenId), amount);
    }

    function testExists() public {
        uint256 tokenId = 1;
        assertFalse(settleMintERC1155.exists(tokenId));
        settleMintERC1155.mint(user1, tokenId, 1, "");
        assertTrue(settleMintERC1155.exists(tokenId));
    }
}

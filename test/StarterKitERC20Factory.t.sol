// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StarterKitERC20Factory } from "../contracts/StarterKitERC20Factory.sol";
import { StarterKitERC20Registry } from "../contracts/StarterKitERC20Registry.sol";
import { StarterKitERC20 } from "../contracts/StarterKitERC20.sol";

contract StarterKitERC20FactoryTest is Test {
    StarterKitERC20Factory public factory;
    StarterKitERC20Registry public registry;
    address public owner;

    function setUp() public {
        owner = address(this);
        registry = new StarterKitERC20Registry();
        factory = new StarterKitERC20Factory(address(registry));
    }

    function testConstructor() public view {
        assertEq(address(factory.registry()), address(registry));
    }

    function testCreateToken() public {
        string memory name = "Test Token";
        string memory symbol = "TST";
        string memory extraData = "Some extra data";

        factory.createToken(name, symbol, extraData);

        StarterKitERC20Registry.Token memory token = registry.getTokenBySymbol(symbol);
        assertEq(token.symbol, symbol);
        assertEq(token.extraData, extraData);

        StarterKitERC20 createdToken = StarterKitERC20(token.tokenAddress);
        assertEq(createdToken.name(), name);
        assertEq(createdToken.symbol(), symbol);
        assertEq(createdToken.owner(), owner);
    }

    function testCreateMultipleTokens() public {
        factory.createToken("Token1", "TKN1", "Data1");
        factory.createToken("Token2", "TKN2", "Data2");

        assertEq(registry.getTokenList().length, 2);
    }

    function testFailCreateDuplicateSymbol() public {
        factory.createToken("Token1", "TKN", "Data1");
        factory.createToken("Token2", "TKN", "Data2"); // This should fail
    }

    function testRegistryIntegration() public {
        factory.createToken("Integration Token", "INT", "Integration Data");

        StarterKitERC20Registry.Token memory token = registry.getTokenBySymbol("INT");
        assertEq(token.symbol, "INT");
        assertEq(token.extraData, "Integration Data");
    }

    function testCreateMintAndTransfer() public {
        // Create a new token
        string memory name = "Transfer Test Token";
        string memory symbol = "TTT";
        string memory extraData = "Token for transfer testing";
        factory.createToken(name, symbol, extraData);

        // Get the created token from the registry
        StarterKitERC20Registry.Token memory registeredToken = registry.getTokenBySymbol(symbol);
        StarterKitERC20 token = StarterKitERC20(registeredToken.tokenAddress);

        // Set up test addresses
        address user1 = address(0x1);
        address user2 = address(0x2);

        // Mint tokens to user1
        uint256 mintAmount = 1000 * 10 ** 18; // 1000 tokens with 18 decimals
        token.mint(user1, mintAmount);

        // Check balance after minting
        assertEq(token.balanceOf(user1), mintAmount, "User1 balance should equal minted amount");

        // Transfer tokens from user1 to user2
        uint256 transferAmount = 300 * 10 ** 18; // 300 tokens
        vm.prank(user1);
        token.transfer(user2, transferAmount);

        // Check balances after transfer
        assertEq(
            token.balanceOf(user1), mintAmount - transferAmount, "User1 balance should be reduced by transfer amount"
        );
        assertEq(token.balanceOf(user2), transferAmount, "User2 balance should equal transferred amount");
    }
}

// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StarterKitERC20Registry } from "../contracts/StarterKitERC20Registry.sol";

contract StarterKitERC20RegistryTest is Test {
    StarterKitERC20Registry public registry;
    address public constant TOKEN_ADDRESS = address(0x1234);
    string public constant TOKEN_NAME = "Test Token";
    string public constant TOKEN_SYMBOL = "TKN";
    string public constant TOKEN_EXTRA_DATA = "Extra Data";
    address public constant FACTORY_ADDRESS = address(0x5678);

    function setUp() public {
        registry = new StarterKitERC20Registry();
    }

    function testAddToken() public {
        registry.addToken(TOKEN_ADDRESS, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_EXTRA_DATA, FACTORY_ADDRESS);

        StarterKitERC20Registry.Token memory token = registry.getTokenByAddress(TOKEN_ADDRESS);
        assertEq(token.tokenAddress, TOKEN_ADDRESS);
        assertEq(token.symbol, TOKEN_SYMBOL);
        assertEq(token.extraData, TOKEN_EXTRA_DATA);
    }

    function testAddTokenEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit StarterKitERC20Registry.TokenAdded(
            TOKEN_ADDRESS, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_EXTRA_DATA, FACTORY_ADDRESS
        );
        registry.addToken(TOKEN_ADDRESS, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_EXTRA_DATA, FACTORY_ADDRESS);
    }

    function testCannotAddDuplicateAddress() public {
        registry.addToken(TOKEN_ADDRESS, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_EXTRA_DATA, FACTORY_ADDRESS);

        vm.expectRevert(
            abi.encodeWithSelector(StarterKitERC20Registry.TokenAddressAlreadyExists.selector, TOKEN_ADDRESS)
        );
        registry.addToken(TOKEN_ADDRESS, "Different Name", "DIFFERENT", "Different Token", address(0x9999));
    }

    function testCannotAddDuplicateSymbol() public {
        registry.addToken(TOKEN_ADDRESS, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_EXTRA_DATA, FACTORY_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(StarterKitERC20Registry.TokenSymbolAlreadyExists.selector, TOKEN_SYMBOL));
        registry.addToken(address(0x5678), "Another Token", TOKEN_SYMBOL, "Another Token", address(0x9999));
    }

    function testGetTokenByAddress() public {
        registry.addToken(TOKEN_ADDRESS, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_EXTRA_DATA, FACTORY_ADDRESS);

        StarterKitERC20Registry.Token memory token = registry.getTokenByAddress(TOKEN_ADDRESS);
        assertEq(token.tokenAddress, TOKEN_ADDRESS);
        assertEq(token.symbol, TOKEN_SYMBOL);
        assertEq(token.extraData, TOKEN_EXTRA_DATA);
    }

    function testGetTokenBySymbol() public {
        registry.addToken(TOKEN_ADDRESS, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_EXTRA_DATA, FACTORY_ADDRESS);

        StarterKitERC20Registry.Token memory token = registry.getTokenBySymbol(TOKEN_SYMBOL);
        assertEq(token.tokenAddress, TOKEN_ADDRESS);
        assertEq(token.symbol, TOKEN_SYMBOL);
        assertEq(token.extraData, TOKEN_EXTRA_DATA);
    }

    function testGetTokenByIndex() public {
        registry.addToken(TOKEN_ADDRESS, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_EXTRA_DATA, FACTORY_ADDRESS);

        StarterKitERC20Registry.Token memory token = registry.getTokenByIndex(0);
        assertEq(token.tokenAddress, TOKEN_ADDRESS);
        assertEq(token.symbol, TOKEN_SYMBOL);
        assertEq(token.extraData, TOKEN_EXTRA_DATA);
    }

    function testGetTokenList() public {
        registry.addToken(TOKEN_ADDRESS, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_EXTRA_DATA, FACTORY_ADDRESS);
        address secondTokenAddress = address(0x5678);
        registry.addToken(secondTokenAddress, "Second Token", "TKN2", "Second Token Extra Data", address(0x9999));

        StarterKitERC20Registry.Token[] memory tokens = registry.getTokenList();
        assertEq(tokens.length, 2);
        assertEq(tokens[0].tokenAddress, TOKEN_ADDRESS);
        assertEq(tokens[1].tokenAddress, secondTokenAddress);
    }

    function testGetNonExistentTokenByAddress() public {
        vm.expectRevert(abi.encodeWithSelector(StarterKitERC20Registry.TokenNotFound.selector, address(0x9999)));
        registry.getTokenByAddress(address(0x9999));
    }

    function testGetNonExistentTokenBySymbol() public {
        vm.expectRevert(abi.encodeWithSelector(StarterKitERC20Registry.TokenNotFound.selector, address(0)));
        registry.getTokenBySymbol("NONEXISTENT");
    }

    function testGetTokenByInvalidIndex() public {
        vm.expectRevert(abi.encodeWithSelector(StarterKitERC20Registry.TokenIndexOutOfBounds.selector, 0));
        registry.getTokenByIndex(0);
    }
}

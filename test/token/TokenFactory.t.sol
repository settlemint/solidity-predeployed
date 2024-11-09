// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TokenFactory} from "../../contracts/token/TokenFactory.sol";
import {Token} from "../../contracts/token/Token.sol";

contract TokenFactoryTest is Test {
    TokenFactory public factory;
    address public admin;
    address public user1;

    event TokenCreated(address indexed tokenAddress, string name, string symbol);

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        vm.prank(admin);
        factory = new TokenFactory(admin);
    }

    function test_CreateToken() public {
        vm.startPrank(user1);
        address newToken = factory.createToken("Test Token", "TEST");

        assertNotEq(newToken, address(0));
        assertEq(factory.allTokensLength(), 1);
        assertEq(factory.allTokens(0), newToken);

        Token token = Token(newToken);
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), user1));
        vm.stopPrank();
    }

    function test_CreateTokenFromZeroAddress() public {
        vm.startPrank(address(0));
        vm.expectRevert(abi.encodeWithSelector(TokenFactory.InvalidInput.selector, "Zero sender address"));
        factory.createToken("Test Token", "TEST");
        vm.stopPrank();
    }

    function test_CreateMultipleTokens() public {
        vm.startPrank(user1);
        address token1 = factory.createToken("Token1", "TK1");
        address token2 = factory.createToken("Token2", "TK2");

        assertNotEq(token1, token2);
        assertEq(factory.allTokensLength(), 2);
        assertEq(factory.allTokens(0), token1);
        assertEq(factory.allTokens(1), token2);
        vm.stopPrank();
    }

    function test_AllTokensLength() public {
        assertEq(factory.allTokensLength(), 0);

        vm.startPrank(user1);
        factory.createToken("Token1", "TK1");
        assertEq(factory.allTokensLength(), 1);

        factory.createToken("Token2", "TK2");
        assertEq(factory.allTokensLength(), 2);
        vm.stopPrank();
    }
}

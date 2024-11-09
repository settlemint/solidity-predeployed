// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PairFactory} from "../../contracts/pair/PairFactory.sol";
import {Pair} from "../../contracts/pair/Pair.sol";
import {Token} from "../../contracts/token/Token.sol";

contract PairFactoryTest is Test {
    PairFactory public factory;
    Token public token0;
    Token public token1;
    address public admin;
    address public user1;

    event PairCreated(
        address indexed baseToken,
        address indexed quoteToken,
        address pair,
        uint256 pairCount
    );

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");

        factory = new PairFactory(admin);
        token0 = new Token("Token0", "TK0", admin);
        token1 = new Token("Token1", "TK1", admin);
    }

    function test_CreatePair() public {
        vm.startPrank(admin);
        address pair = factory.createPair(address(token0), address(token1));

        assertNotEq(pair, address(0));
        assertEq(factory.getPair(address(token0), address(token1)), pair);
        assertEq(factory.getPair(address(token1), address(token0)), pair);
        assertEq(factory.allPairs(0), pair);
        assertEq(factory.allPairsLength(), 1);
        vm.stopPrank();
    }

    function test_CreatePairWithZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(PairFactory.InvalidInput.selector, "Zero address"));
        factory.createPair(address(0), address(token1));
        vm.stopPrank();
    }

    function test_CreatePairWithIdenticalTokens() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(PairFactory.InvalidInput.selector, "Identical addresses"));
        factory.createPair(address(token0), address(token0));
        vm.stopPrank();
    }

    function test_CreateDuplicatePair() public {
        vm.startPrank(admin);
        factory.createPair(address(token0), address(token1));
        
        // Use expectRevert with the correct error selector and message
        vm.expectRevert(abi.encodeWithSelector(PairFactory.InvalidOperation.selector, "Pair exists"));
        factory.createPair(address(token0), address(token1));
        vm.stopPrank();
    }

    function test_CreateMultiplePairs() public {
        vm.startPrank(admin);
        Token token2 = new Token("Token2", "TK2", admin);

        address pair1 = factory.createPair(address(token0), address(token1));
        address pair2 = factory.createPair(address(token0), address(token2));
        address pair3 = factory.createPair(address(token1), address(token2));

        assertNotEq(pair1, pair2);
        assertNotEq(pair2, pair3);
        assertNotEq(pair1, pair3);
        assertEq(factory.allPairsLength(), 3);
        vm.stopPrank();
    }

    function testFail_CreatePairUnauthorized() public {
        vm.prank(user1);
        factory.createPair(address(token0), address(token1));
    }
}

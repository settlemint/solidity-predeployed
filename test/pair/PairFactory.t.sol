// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DexFactory} from "../../contracts/pair/PairFactory.sol";
import {Pair} from "../../contracts/pair/Pair.sol";
import {Token} from "../../contracts/token/Token.sol";

contract DexFactoryTest is Test {
    DexFactory public factory;
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

        factory = new DexFactory();
        token0 = new Token("Token0", "TK0", admin);
        token1 = new Token("Token1", "TK1", admin);
    }

    function test_CreatePair() public {
        // Expect the event before creating the pair
        vm.expectEmit(true, true, true, true);
        bytes32 salt = keccak256(abi.encodePacked(address(token0), address(token1)));
        bytes memory creationCode = abi.encodePacked(
            type(Pair).creationCode,
            abi.encode(address(token0), address(token1), 100, address(this))
        );
        address expectedAddress = vm.computeCreate2Address(
            salt,
            keccak256(creationCode),
            address(factory)
        );
        emit PairCreated(address(token0), address(token1), expectedAddress, 1);

        address pair = factory.createPair(address(token0), address(token1));

        assertNotEq(pair, address(0));
        assertEq(factory.getPair(address(token0), address(token1)), pair);
        assertEq(factory.getPair(address(token1), address(token0)), pair);
        assertEq(factory.allPairs(0), pair);
        assertEq(factory.allPairsLength(), 1);
    }

    function testFail_CreatePairWithZeroAddress() public {
        factory.createPair(address(0), address(token1));
    }

    function testFail_CreatePairWithIdenticalTokens() public {
        factory.createPair(address(token0), address(token0));
    }

    function testFail_CreateDuplicatePair() public {
        factory.createPair(address(token0), address(token1));
        factory.createPair(address(token0), address(token1));
    }

    function test_CreateMultiplePairs() public {
        Token token2 = new Token("Token2", "TK2", admin);

        address pair1 = factory.createPair(address(token0), address(token1));
        address pair2 = factory.createPair(address(token0), address(token2));
        address pair3 = factory.createPair(address(token1), address(token2));

        assertNotEq(pair1, pair2);
        assertNotEq(pair2, pair3);
        assertNotEq(pair1, pair3);

        assertEq(factory.allPairsLength(), 3);
    }

    function test_TokenOrdering() public {
        // Test that tokens are ordered correctly regardless of input order
        address pair1 = factory.createPair(address(token0), address(token1));
        Token token2 = new Token("Token2", "TK2", admin);
        address pair2 = factory.createPair(address(token2), address(token0));

        // Verify pairs are created with ordered tokens
        Pair pairContract1 = Pair(pair1);
        Pair pairContract2 = Pair(pair2);

        assertTrue(address(token0) < address(token1));
        assertEq(pairContract1.baseToken(), address(token0));
        assertEq(pairContract1.quoteToken(), address(token1));

        // For pair2, verify tokens are ordered regardless of input order
        assertTrue(
            (pairContract2.baseToken() < pairContract2.quoteToken()) ||
            (address(token0) == pairContract2.baseToken() && address(token2) == pairContract2.quoteToken()) ||
            (address(token0) == pairContract2.quoteToken() && address(token2) == pairContract2.baseToken())
        );
    }

    function test_AllPairsLength() public {
        assertEq(factory.allPairsLength(), 0);

        factory.createPair(address(token0), address(token1));
        assertEq(factory.allPairsLength(), 1);

        Token token2 = new Token("Token2", "TK2", admin);
        factory.createPair(address(token0), address(token2));
        assertEq(factory.allPairsLength(), 2);
    }
}

// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { StarterKitERC20Dex } from "./StarterKitERC20Dex.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract StarterKitERC20DexFactory is Ownable {
    error InvalidToken();
    error PairExists();
    error IdenticalAddresses();
    error ZeroAddress();

    event PairCreated(
        address indexed baseToken,
        address indexed quoteToken,
        address pair,
        uint256 pairCount
    );

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    uint256 public initialFee;

    constructor(uint256 _initialFee) Ownable(msg.sender) {
        initialFee = _initialFee;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(
        address baseToken,
        address quoteToken
    ) external returns (address pair) {
        if (baseToken == quoteToken) revert IdenticalAddresses();
        if (baseToken == address(0) || quoteToken == address(0)) revert ZeroAddress();

        (address token0, address token1) = baseToken < quoteToken
            ? (baseToken, quoteToken)
            : (quoteToken, baseToken);

        if (getPair[token0][token1] != address(0)) revert PairExists();

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        StarterKitERC20Dex newPair = new StarterKitERC20Dex{salt: salt}(
            token0,
            token1,
            initialFee,
            msg.sender
        );

        pair = address(newPair);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setInitialFee(uint256 _newFee) external onlyOwner {
        initialFee = _newFee;
    }
}
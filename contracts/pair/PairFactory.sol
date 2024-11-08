// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Pair } from "./Pair.sol";

/// @title DexFactory
/// @notice Factory contract for creating and managing Dex pairs
/// @dev Creates and tracks ERC20-ERC20 trading pairs
contract DexFactory {
    /// @notice Thrown when an invalid token address is provided
    error InvalidToken();
    /// @notice Thrown when attempting to create a pair that already exists
    error PairExists();
    /// @notice Thrown when same address is used for both tokens
    error IdenticalAddresses();
    /// @notice Thrown when zero address is provided
    error ZeroAddress();

    /// @notice Emitted when a new trading pair is created
    /// @param baseToken Address of the base token
    /// @param quoteToken Address of the quote token
    /// @param pair Address of the created pair contract
    /// @param pairCount Total number of pairs after creation
    event PairCreated(
        address indexed baseToken,
        address indexed quoteToken,
        address pair,
        uint256 pairCount
    );

    /// @notice Maps token addresses to their trading pair contracts
    /// @dev Maps token0 => token1 => pair address
    mapping(address => mapping(address => address)) public getPair;

    /// @notice Array containing addresses of all created pairs
    address[] public allPairs;

    /// @notice Returns the total number of pairs created
    /// @return Number of pairs in existence
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /// @notice Creates a new trading pair for two tokens
    /// @param baseToken Address of the base token
    /// @param quoteToken Address of the quote token
    /// @return pair Address of the newly created pair
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
        Pair newPair = new Pair{salt: salt}(
            token0,
            token1,
            100,
            msg.sender
        );

        pair = address(newPair);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}

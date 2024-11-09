// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Pair } from "./Pair.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title DexFactory
/// @notice Factory contract for creating and managing Dex pairs
/// @dev Creates and tracks ERC20-ERC20 trading pairs
contract PairFactory is AccessControl {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    /// @notice Thrown when input validation fails
    error InvalidInput(string message);
    /// @notice Thrown when operation validation fails
    error InvalidOperation(string message);

    /// @notice Emitted when a new trading pair is created
    /// @param baseToken Address of the base token
    /// @param quoteToken Address of the quote token
    /// @param pair Address of the created pair contract
    /// @param pairCount Total number of pairs after creation
    event PairCreated(address indexed baseToken, address indexed quoteToken, address pair, uint256 pairCount);

    /// @notice Maps token addresses to their trading pair contracts
    /// @dev Maps token0 => token1 => pair address
    mapping(address => mapping(address => address)) public getPair;

    /// @notice Array containing addresses of all created pairs
    address[] public allPairs;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FACTORY_ROLE, msg.sender);
    }

    /// @notice Returns the total number of pairs created
    /// @return Number of pairs in existence
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /// @notice Creates a new trading pair for two tokens
    /// @param baseToken Address of the base token
    /// @param quoteToken Address of the quote token
    /// @return pair Address of the newly created pair
    function createPair(address baseToken, address quoteToken) external onlyRole(FACTORY_ROLE) returns (address pair) {
        if (baseToken == quoteToken) {
            revert InvalidInput("Identical addresses");
        }
        if (baseToken == address(0) || quoteToken == address(0)) {
            revert InvalidInput("Zero address");
        }

        (address token0, address token1) = baseToken < quoteToken ? (baseToken, quoteToken) : (quoteToken, baseToken);

        if (getPair[token0][token1] != address(0)) {
            revert InvalidOperation("Pair exists");
        }

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        Pair newPair = new Pair{ salt: salt }(token0, token1, 100, msg.sender);

        pair = address(newPair);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}

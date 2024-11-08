// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Token } from "./Token.sol";

/// @title Factory
/// @dev A factory contract for creating  tokens
/// @custom:security-contact security@settlemint.com
contract TokenFactory {
    /// @notice Thrown when zero address provided
    error ZeroAddress();

    /// @dev Emitted when a new token is created
    /// @param tokenAddress The address of the newly created token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    event TokenCreated(address indexed tokenAddress, string name, string symbol);

    /// @notice Array of all created tokens
    address[] public allTokens;

    /// @notice Creates a new  token
    /// @param name_ The name of the new token
    /// @param symbol_ The symbol of the new token
    /// @return token The address of the newly created token
    function createToken(
        string calldata name_,
        string calldata symbol_
    ) external returns (address token) {
        if (msg.sender == address(0)) revert ZeroAddress();

        bytes32 salt = keccak256(abi.encodePacked(name_, symbol_, msg.sender));
        Token newToken = new Token{salt: salt}(
            name_,
            symbol_,
            msg.sender
        );

        token = address(newToken);
        allTokens.push(token);

        emit TokenCreated(token, name_, symbol_);
    }

    /// @notice Returns the total number of tokens created
    /// @return The length of the allTokens array
    function allTokensLength() external view returns (uint256) {
        return allTokens.length;
    }
}

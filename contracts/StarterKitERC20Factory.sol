// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { StarterKitERC20Registry } from "./StarterKitERC20Registry.sol";
import { StarterKitERC20 } from "./StarterKitERC20.sol";

/// @title StarterKitERC20Factory
/// @dev A factory contract for creating and managing StarterKitERC20 tokens.
/// @notice This contract allows for the creation of new StarterKitERC20 tokens and registers them in a registry.
/// @custom:security-contact security@settlemint.com
contract StarterKitERC20Factory {
    /// @dev The registry where created tokens are stored
    StarterKitERC20Registry public _registry = StarterKitERC20Registry(0x5E771E1417100000000000000000000000000001);

    /// @dev Emitted when a new token is created
    /// @param tokenAddress The address of the newly created token
    /// @param symbol The symbol of the newly created token
    event TokenCreated(address tokenAddress, string symbol);

    /// @notice Returns the address of the token registry
    /// @return The StarterKitERC20Registry interface
    function registry() external view returns (StarterKitERC20Registry) {
        return _registry;
    }

    /// @notice Creates a new StarterKitERC20 token
    /// @dev Creates a new token, adds it to the registry, and emits a TokenCreated event
    /// @param name_ The name of the new token
    /// @param symbol_ The symbol of the new token
    /// @param extraData_ Additional data to be stored with the token in the registry
    function createToken(string calldata name_, string calldata symbol_, string calldata extraData_) external {
        StarterKitERC20 token = new StarterKitERC20(name_, symbol_, msg.sender);

        _registry.addToken(address(token), symbol_, extraData_);
        emit TokenCreated(address(token), symbol_);
    }
}

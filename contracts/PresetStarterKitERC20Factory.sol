// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { StarterKitERC20Factory } from "./StarterKitERC20Factory.sol";

/// @title PresetStarterKitERC20Factory
/// @dev A factory contract for creating and managing StarterKitERC20 tokens.
/// @notice This contract allows for the creation of new StarterKitERC20 tokens and registers them in a registry.
/// @custom:security-contact security@settlemint.com
contract PresetStarterKitERC20Factory is StarterKitERC20Factory {
    constructor() StarterKitERC20Factory(0x5E771E1417100000000000000000000000000001) { }
}

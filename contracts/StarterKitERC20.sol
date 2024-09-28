// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title StarterKitERC20 Token
/// @dev Extends ERC20 with permit functionality and ownership control.
/// @custom:security-contact support@settlemint.com
contract StarterKitERC20 is ERC20, Ownable, ERC20Permit {
    /// @notice Initializes the contract by setting a name, symbol, and owner for the token
    /// @dev Sets up the token with name, symbol, and initializes OpenZeppelin's Ownable and ERC20Permit functionalities
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param owner The address that will be set as the owner of the contract
    constructor(
        string memory name,
        string memory symbol,
        address owner
    )
        ERC20(name, symbol)
        Ownable(owner)
        ERC20Permit(name)
    { }

    /// @notice Mints new tokens and assigns them to a specified address
    /// @dev Increases the total supply of the token
    /// @param to The address that will receive the minted tokens
    /// @param amount The quantity of tokens to be minted
    /// @custom:requires The caller must be the contract owner
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /// @notice Internal function to update token balances during transfers
    /// @dev Overrides the `_update` function from ERC20 to ensure proper functionality
    /// @param from The address from which tokens are being transferred
    /// @param to The address to which tokens are being transferred
    /// @param value The amount of tokens being transferred
    function _update(address from, address to, uint256 value) internal override(ERC20) {
        super._update(from, to, value);
    }
}

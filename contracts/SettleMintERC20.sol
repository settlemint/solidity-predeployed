// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title A basic ERC20 Token without authorization solution
/// @dev Implements a basic ERC20 token with minting functionality.
/// @custom:security-contact support@settlemint.com
contract SettleMintERC20 is ERC20 {
    /// @dev Initializes the contract by setting a `name` and a `symbol` to the token.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }

    /// @dev Mints `amount` tokens and assigns them to `to`, increasing the total supply.
    /// @param to The address to mint tokens to.
    /// @param amount The number of tokens to be minted.
    /// @notice This function can be called by anyone. Consider adding access control if needed.
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

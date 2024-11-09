// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title  Token
/// @dev Extends ERC20 with permit functionality and access control
/// @custom:security-contact support@settlemint.com
contract Token is ERC20, ERC20Permit, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Role identifier for administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Emitted during emergency withdrawals
    /// @param token The token being withdrawn
    /// @param amount The amount withdrawn
    event EmergencyWithdraw(address token, uint256 amount);

    /// @notice Thrown when input validation fails
    error InvalidInput(string message);
    /// @notice Thrown when operation validation fails
    error InvalidOperation(string message);

    constructor(string memory name, string memory symbol, address admin) ERC20(name, symbol) ERC20Permit(name) {
        if (admin == address(0)) revert InvalidInput("Zero admin address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /// @notice Mints new tokens and assigns them to a specified address
    /// @param to The address that will receive the minted tokens
    /// @param amount The quantity of tokens to be minted
    function mint(address to, uint256 amount) public onlyRole(ADMIN_ROLE) {
        if (to == address(0)) revert InvalidInput("Zero recipient address");
        if (amount == 0) revert InvalidInput("Zero amount");
        _mint(to, amount);
    }

    /// @notice Internal function to update token balances during transfers
    /// @dev Overrides the `_update` function from ERC20 to ensure proper functionality
    function _update(address from, address to, uint256 value) internal override(ERC20) whenNotPaused {
        super._update(from, to, value);
    }

    /// @notice Emergency withdrawal of tokens
    /// @param token The address of the token to be withdrawn
    /// @param amount The quantity of tokens to be withdrawn
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        if (token == address(0)) revert InvalidInput("Zero token address");
        if (amount == 0) revert InvalidInput("Zero amount");
        if (amount > IERC20(token).balanceOf(address(this))) {
            revert InvalidOperation("Insufficient balance");
        }

        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(token, amount);
    }

    /// @notice Pauses token transfers
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses token transfers
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Burns tokens from a specified address
    /// @param from The address from which tokens will be burned
    /// @param amount The quantity of tokens to be burned
    function burn(address from, uint256 amount) public onlyRole(ADMIN_ROLE) {
        if (from == address(0)) revert InvalidInput("Zero address");
        if (amount == 0) revert InvalidInput("Zero amount");
        if (amount > balanceOf(from)) {
            revert InvalidOperation("Insufficient balance");
        }
        _burn(from, amount);
    }
}

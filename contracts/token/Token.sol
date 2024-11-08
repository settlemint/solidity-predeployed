// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title  Token
/// @dev Extends ERC20 with permit functionality and access control
/// @custom:security-contact support@settlemint.com
contract Token is ERC20, ERC20Permit, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Role identifier for minting privileges
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice Role identifier for admin privileges
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    /// @notice Role identifier for pauser privileges
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @notice Role identifier for burner privileges
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Address of timelock controller
    TimelockController public immutable timelock;

    /// @notice Emitted during emergency withdrawals
    /// @param token The token being withdrawn
    /// @param amount The amount withdrawn
    event EmergencyWithdraw(address token, uint256 amount);

    /// @notice Thrown when caller is not timelock contract
    error UnauthorizedTimelock();
    /// @notice Thrown when zero address is provided
    error ZeroAddress();
    /// @notice Thrown when amount is invalid
    error InvalidAmount();
    /// @notice Thrown when balance is insufficient
    error InsufficientBalance();

    constructor(
        string memory name,
        string memory symbol,
        address admin
    ) ERC20(name, symbol) ERC20Permit(name) {
        if(admin == address(0)) revert ZeroAddress();

        // Batch role assignments in one operation
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(BURNER_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = admin;
        executors[0] = admin;
        timelock = new TimelockController(2 days, proposers, executors, admin);
    }

    /// @notice Mints new tokens and assigns them to a specified address
    /// @param to The address that will receive the minted tokens
    /// @param amount The quantity of tokens to be minted
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        if(to == address(0)) revert ZeroAddress();
        if(amount == 0) revert InvalidAmount();
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
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        if(token == address(0)) revert ZeroAddress();
        if(amount == 0) revert InvalidAmount();
        if(amount > IERC20(token).balanceOf(address(this))) revert InsufficientBalance();
        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(token, amount);
    }

    /// @notice Pauses token transfers
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpauses token transfers
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Burns tokens from a specified address
    /// @param from The address from which tokens will be burned
    /// @param amount The quantity of tokens to be burned
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        if(from == address(0)) revert ZeroAddress();
        if(amount == 0) revert InvalidAmount();
        if(amount > balanceOf(from)) revert InsufficientBalance();
        _burn(from, amount);
    }
}

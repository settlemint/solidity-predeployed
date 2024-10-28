// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

/// @title StarterKitERC20SaleRegistry
/// @notice Registry contract for tracking ERC20 token sales created by the StarterKitERC20SaleFactory
/// @dev Maintains a list of sale contract addresses and provides lookup functionality
/// @custom:security-contact security@settlemint.com
contract StarterKitERC20SaleRegistry {
    /// @notice Emitted when a new sale contract is registered
    /// @param saleAddress The address of the newly registered sale contract
    event SaleAdded(address indexed saleAddress);

    /// @notice Thrown when attempting to register a sale address that already exists
    /// @param saleAddress The duplicate sale address that was attempted to be registered
    error SaleAddressAlreadyExists(address saleAddress);

    /// @notice Array storing all registered sale contract addresses
    /// @dev Zero-based indexing
    address[] private sales;

    /// @notice Mapping of sale address to its index in the sales array
    /// @dev One-based indexing (0 means not found)
    mapping(address => uint256) private addressToIndex;

    /// @notice Registers a new sale contract in the registry
    /// @dev Only callable by the factory contract
    /// @param saleAddress The address of the sale contract to register
    /// @custom:throws SaleAddressAlreadyExists if the sale is already registered
    function addSale(address saleAddress) external {
        if (addressToIndex[saleAddress] != 0) revert SaleAddressAlreadyExists(saleAddress);

        uint256 index = sales.length + 1;
        sales.push(saleAddress);
        addressToIndex[saleAddress] = index;

        emit SaleAdded(saleAddress);
    }

    /// @notice Gets all registered sale contract addresses
    /// @return Array of all registered sale contract addresses
    function getSaleList() external view returns (address[] memory) {
        return sales;
    }
}

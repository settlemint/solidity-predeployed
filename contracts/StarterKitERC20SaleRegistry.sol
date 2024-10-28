// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

/// @title StarterKitERC20SaleRegistry
/// @dev A contract for managing a registry of ERC20 token sales
/// @notice This contract allows for the registration and retrieval of ERC20 token sales
/// @custom:security-contact security@settlemint.com
contract StarterKitERC20SaleRegistry {
    /// @notice Event emitted when a sale is added to the registry
    /// @dev This event is triggered when a new sale is successfully registered
    /// @param saleAddress The address of the sale contract being added
    event SaleAdded(address indexed saleAddress);

    /// @dev Error thrown when a sale is already found in the registry
    /// @param saleAddress The address of the sale that was found
    error SaleAddressAlreadyExists(address saleAddress);

    /// @dev The list of sales in the registry, the index to use for the array is 0-based
    address[] private sales;

    /// @dev The index of a sale in the registry based on the address, the index to use for the array is 1-based
    mapping(address => uint256) private addressToIndex;

    /// @notice Adds a new sale to the registry
    /// @dev Reverts if the sale address already exists in the registry
    /// @param saleAddress The address of the sale to be added
    /// @custom:throws SaleAddressAlreadyExists if the sale address is already registered
    function addSale(address saleAddress) external {
        if (addressToIndex[saleAddress] != 0) revert SaleAddressAlreadyExists(saleAddress);

        uint256 index = sales.length + 1;
        sales.push(saleAddress);
        addressToIndex[saleAddress] = index;

        emit SaleAdded(saleAddress);
    }

    /// @notice Retrieves the list of all sales in the registry
    /// @dev Returns an array containing all registered sale addresses
    /// @return An array of all sale addresses in the registry
    function getSaleList() external view returns (address[] memory) {
        return sales;
    }
}

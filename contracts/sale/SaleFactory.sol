// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Sale } from "./Sale.sol";

/// @title SaleFactory
/// @dev A factory contract for creating and managing token sales
/// @notice This contract allows for the creation of new token sales with access control
contract SaleFactory {
    /// @notice Thrown when input validation fails
    error InvalidInput(string message);
    /// @notice Thrown when operation validation fails
    error InvalidOperation(string message);

    /// @notice Emitted when a new sale is created
    /// @param saleAddress The address of the newly created sale contract
    /// @param saleToken The token being sold
    /// @param paymentToken The token used for payment
    /// @param price The initial price set for the sale
    /// @param paymentRecipient The address of the payment recipient
    event SaleCreated(
        address indexed saleAddress,
        address indexed saleToken,
        address indexed paymentToken,
        uint256 price,
        address paymentRecipient
    );

    /// @notice Maps sale token to its sale contract address
    mapping(address => address) public getSale;
    /// @notice Array of all created sale contracts
    address[] public allSales;

    /// @notice Creates a new token sale contract
    /// @param saleToken The token to be sold
    /// @param paymentToken The token used for payment
    /// @param initialPrice The initial price per token
    /// @param paymentRecipient The address of the payment recipient
    /// @return sale The address of the newly created sale contract
    function createSale(
        address saleToken,
        address paymentToken,
        uint256 initialPrice,
        address paymentRecipient
    )
        external
        returns (address sale)
    {
        if (saleToken == address(0) || paymentToken == address(0)) {
            revert InvalidInput("Zero address");
        }
        if (saleToken == paymentToken) {
            revert InvalidInput("Identical addresses");
        }
        if (getSale[saleToken] != address(0)) {
            revert InvalidOperation("Sale exists");
        }

        bytes32 salt = keccak256(abi.encodePacked(saleToken, paymentToken, msg.sender));
        Sale newSale = new Sale{ salt: salt }(saleToken, paymentToken, initialPrice, msg.sender, paymentRecipient);

        sale = address(newSale);
        getSale[saleToken] = sale;
        allSales.push(sale);

        emit SaleCreated(sale, saleToken, paymentToken, initialPrice, paymentRecipient);
    }

    /// @notice Returns the total number of sales created
    /// @return The length of the allSales array
    function allSalesLength() external view returns (uint256) {
        return allSales.length;
    }
}

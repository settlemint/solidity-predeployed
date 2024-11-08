// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { Sale } from "./Sale.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title SaleFactory
/// @dev A factory contract for creating and managing token sales
/// @notice This contract allows for the creation of new token sales with access control
contract SaleFactory is AccessControl {
    /// @notice Role identifier for administrators
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Thrown when zero address provided
    error ZeroAddress();
    /// @notice Thrown when sale already exists for token
    error SaleExists();
    /// @notice Thrown when identical token addresses provided
    error IdenticalAddresses();

    /// @notice Emitted when a new sale is created
    /// @param saleAddress The address of the newly created sale contract
    /// @param saleToken The token being sold
    /// @param paymentToken The token used for payment
    /// @param price The initial price set for the sale
    event SaleCreated(
        address indexed saleAddress,
        address indexed saleToken,
        address indexed paymentToken,
        uint256 price
    );

    /// @notice Maps sale token to its sale contract address
    mapping(address => address) public getSale;
    /// @notice Array of all created sale contracts
    address[] public allSales;

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /// @notice Creates a new token sale contract
    /// @param saleToken The token to be sold
    /// @param paymentToken The token used for payment
    /// @param initialPrice The initial price per token
    /// @return sale The address of the newly created sale contract
    function createSale(
        address saleToken,
        address paymentToken,
        uint256 initialPrice
    ) external onlyRole(ADMIN_ROLE) returns (address sale) {
        if (saleToken == address(0) || paymentToken == address(0)) revert ZeroAddress();
        if (saleToken == paymentToken) revert IdenticalAddresses();
        if (getSale[saleToken] != address(0)) revert SaleExists();

        bytes32 salt = keccak256(abi.encodePacked(saleToken, paymentToken, msg.sender));
        Sale newSale = new Sale{salt: salt}(
            saleToken,
            paymentToken,
            initialPrice,
            msg.sender
        );

        sale = address(newSale);
        getSale[saleToken] = sale;
        allSales.push(sale);

        emit SaleCreated(sale, saleToken, paymentToken, initialPrice);
    }

    /// @notice Returns the total number of sales created
    /// @return The length of the allSales array
    function allSalesLength() external view returns (uint256) {
        return allSales.length;
    }
}
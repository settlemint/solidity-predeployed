// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { StarterKitERC20SaleRegistry } from "./StarterKitERC20SaleRegistry.sol";
import { StarterKitERC20Sale } from "./StarterKitERC20Sale.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title StarterKitERC20SaleFactory
/// @notice Factory contract for creating new ERC20 token sales
/// @dev Creates and registers new StarterKitERC20Sale contracts
/// @custom:security-contact support@settlemint.com
contract StarterKitERC20SaleFactory {
    /// @notice The registry contract where created sales are stored
    StarterKitERC20SaleRegistry public _registry;


    /// @dev Emitted when a new sale is created
    /// @param saleAddress The address of the newly created sale
    event SaleCreated(address saleAddress);

    /// @notice Initializes the factory with a registry contract
    /// @param registryAddress The address of the StarterKitERC20SaleRegistry contract
    constructor(address registryAddress) {
        _registry = StarterKitERC20SaleRegistry(registryAddress);
    }

    /// @notice Creates and registers a new token sale contract
    /// @dev Deploys a new StarterKitERC20Sale contract and registers it in the registry
    /// @param tokenForSale The ERC20 token being sold
    /// @param tokenForPayment The ERC20 token accepted as payment
    /// @param pricePerToken The price per token in payment token units (18 decimals)
    /// @param minPurchase The minimum purchase amount in sale token units
    /// @param maxPurchase The maximum purchase amount in sale token units
    /// @return sale The address of the newly created sale contract
    function createSale(
        IERC20 tokenForSale,
        IERC20 tokenForPayment,
        uint256 pricePerToken,
        uint256 minPurchase,
        uint256 maxPurchase
    )
        external
        returns (address sale)
    {
        sale = address(
            new StarterKitERC20Sale(tokenForSale, tokenForPayment, pricePerToken, minPurchase, maxPurchase, msg.sender)
        );
        _registry.addSale(sale);
        emit SaleCreated(sale);
    }
}

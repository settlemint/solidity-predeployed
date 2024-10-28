// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import { StarterKitERC20SaleRegistry } from "./StarterKitERC20SaleRegistry.sol";
import { StarterKitERC20Sale } from "./StarterKitERC20Sale.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title StarterKitERC20 Token
/// @dev Extends ERC20 with permit functionality and ownership control.
/// @custom:security-contact support@settlemint.com
contract StarterKitERC20SaleFactory {
    /// @dev The registry where created tokens are stored
    StarterKitERC20SaleRegistry public _registry;

    constructor(address registryAddress) {
        _registry = StarterKitERC20SaleRegistry(registryAddress);
    }

    /// @notice Creates a new StarterKitERC20Sale token
    /// @dev Creates a new sale, adds it to the registry, and emits a SaleCreated event
    /// @param tokenForSale The address of the token being sold
    /// @param tokenForPayment The address of the token accepted as payment
    /// @param pricePerToken The price per token in payment token units
    /// @param minPurchase The minimum purchase amount
    /// @param maxPurchase The maximum purchase amount
    function createSale(
        IERC20 tokenForSale,
        IERC20 tokenForPayment,
        uint256 pricePerToken,
        uint256 minPurchase,
        uint256 maxPurchase
    )
        external
    {
        address sale = address(
            new StarterKitERC20Sale(tokenForSale, tokenForPayment, pricePerToken, minPurchase, maxPurchase, msg.sender)
        );
        _registry.addSale(sale);
    }
}

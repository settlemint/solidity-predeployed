// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

/// @title StarterKitERC20Registry
/// @dev A contract for managing a registry of ERC20 tokens.
/// @notice This contract allows for the registration and retrieval of ERC20 tokens.
/// @custom:security-contact security@settlemint.com
contract StarterKitERC20Registry {
    /// @notice Event emitted when a token is added to the registry
    /// @dev This event is triggered when a new token is successfully registered
    /// @param tokenAddress The address of the token contract being added
    /// @param symbol The symbol of the token being added
    /// @param extraData Any extra data associated with the token
    event TokenAdded(address tokenAddress, string name, string symbol, string extraData, address factoryAddress);

    /// @dev Error thrown when a token is not found in the registry
    /// @param tokenAddress The address of the token that was not found
    error TokenNotFound(address tokenAddress);

    /// @dev Error thrown when an index does not exist in the registry
    /// @param index The index that does not exist
    error TokenIndexOutOfBounds(uint256 index);

    /// @dev Error thrown when a token is already found in the registry
    /// @param tokenAddress The address of the token that was found
    error TokenAddressAlreadyExists(address tokenAddress);

    /// @dev Error thrown when a symbol is already found in the registry
    /// @param symbol The symbol of the token that was found
    error TokenSymbolAlreadyExists(string symbol);

    /// @dev Struct to store token information
    struct Token {
        address tokenAddress;
        string symbol;
        string extraData;
    }

    /// @dev The list of tokens in the registry, the index to use for the array is 0-based
    Token[] private tokens;

    /// @dev The index of a token in the registry based on the address, the index to use for the array is 1-based
    mapping(address => uint256) private addressToIndex;

    /// @dev The index of a token in the registry based on the symbol, the index to use for the array is 1-based
    mapping(string => uint256) private symbolToIndex;

    /// @notice Adds a new token to the registry
    /// @dev Reverts if the token address or symbol already exists in the registry
    /// @param tokenAddress The address of the token to be added
    /// @param symbol The symbol of the token to be added
    /// @param extraData Additional data associated with the token
    /// @custom:throws TokenAddressAlreadyExists if the token address is already registered
    /// @custom:throws TokenSymbolAlreadyExists if the token symbol is already registered
    function addToken(
        address tokenAddress,
        string calldata name,
        string calldata symbol,
        string calldata extraData,
        address factoryAddress
    )
        public
        virtual
    {
        if (addressToIndex[tokenAddress] != 0) revert TokenAddressAlreadyExists(tokenAddress);
        if (symbolToIndex[symbol] != 0) revert TokenSymbolAlreadyExists(symbol);

        uint256 index = tokens.length + 1;
        tokens.push(Token(tokenAddress, symbol, extraData));
        addressToIndex[tokenAddress] = index;
        symbolToIndex[symbol] = index;

        emit TokenAdded(tokenAddress, name, symbol, extraData, factoryAddress);
    }

    /// @notice Retrieves a token by its address
    /// @dev Reverts if the token is not found in the registry
    /// @param tokenAddress The address of the token to retrieve
    /// @return token The token information
    /// @custom:throws TokenNotFound if the token address is not registered
    function getTokenByAddress(address tokenAddress) external view returns (Token memory token) {
        uint256 index = addressToIndex[tokenAddress];
        if (index == 0) revert TokenNotFound(tokenAddress);
        return tokens[index - 1];
    }

    /// @notice Retrieves a token by its symbol
    /// @dev Reverts if the token is not found in the registry
    /// @param symbol The symbol of the token to retrieve
    /// @return token The token information
    /// @custom:throws TokenNotFound if the token symbol is not registered
    function getTokenBySymbol(string calldata symbol) external view returns (Token memory token) {
        uint256 index = symbolToIndex[symbol];
        if (index == 0) revert TokenNotFound(address(0));
        return tokens[index - 1];
    }

    /// @notice Retrieves a token by its index in the registry
    /// @dev Reverts if the index is out of bounds
    /// @param index The index of the token in the registry (0-based)
    /// @return token The token information
    /// @custom:throws TokenIndexOutOfBounds if the provided index is greater than or equal to the number of registered
    /// tokens
    function getTokenByIndex(uint256 index) external view returns (Token memory token) {
        if (index >= tokens.length) revert TokenIndexOutOfBounds(index);
        return tokens[index];
    }

    /// @notice Retrieves the list of all tokens in the registry
    /// @return An array of all token information in the registry
    function getTokenList() external view returns (Token[] memory) {
        return tokens;
    }
}

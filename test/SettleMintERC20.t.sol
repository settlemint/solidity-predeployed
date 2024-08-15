// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/SettleMintERC20.sol";

contract SettleMintERC20Test is Test {
    SettleMintERC20 token;
    address owner;
    address recipient;

    function setUp() public {
        owner = address(this);
        recipient = address(0x1);
        token = new SettleMintERC20("SettleMint", "STTLMNT");
    }

    function testMint() public {
        uint256 mintAmount = 1000 * 10 ** token.decimals();
        token.mint(owner, mintAmount);
        uint256 newOwnerBalance = token.balanceOf(owner);
        assertEq(newOwnerBalance, 101_000 * 10 ** token.decimals());
    }
}

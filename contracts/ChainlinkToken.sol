// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

contract ChainlinkToken is LinkToken {
    constructor() LinkToken() { }
}

// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {OperatorFactory} from "@chainlink/contracts/src/v0.8/operatorforwarder/OperatorFactory.sol";

contract ChainlinkOperatorFactory is OperatorFactory {
    constructor(address linkAddress) OperatorFactory(linkAddress) { }
}

// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.24;

import {ChainlinkOperatorFactory} from "./ChainlinkOperatorFactory.sol";

contract PresetChainlinkOperatorFactory is ChainlinkOperatorFactory {
    constructor() ChainlinkOperatorFactory(0x5e771e1417100000000000000000000000000004) { }
}

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const ContractsModule = buildModule("ContractsModule", (m) => {
  // ERC20
  const registry = m.contract("StarterKitERC20Registry");
  const factory = m.contract("StarterKitERC20Factory", [registry]);

  // DEX
  const dexFactory = m.contract("StarterKitERC20DexFactory");

  // Chainlink
  const chainlinkToken = m.contract("ChainlinkToken");
  const chainlinkOperatorFactory = m.contract("ChainlinkOperatorFactory", [chainlinkToken]);

  return { registry, factory, dexFactory, chainlinkToken, chainlinkOperatorFactory };
});

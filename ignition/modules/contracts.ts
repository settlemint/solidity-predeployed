import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const ContractsModule = buildModule("ContractsModule", (m) => {
  const registry = m.contract("StarterKitERC20Registry");
  const factory = m.contract("StarterKitERC20Factory", [registry]);

  const dexFactory = m.contract("StarterKitERC20DexFactory", [30]);

  return { registry, factory, dexFactory };
});
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const ContractsModule = buildModule("ContractsModule", (m) => {
  const registry = m.contract("Registry");
  const factory = m.contract("Factory", [registry]);

  const dexFactory = m.contract("DexFactory");

  return { registry, factory, dexFactory };
});
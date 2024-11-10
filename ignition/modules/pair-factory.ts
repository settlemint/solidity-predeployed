import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const PairFactoryModule = buildModule("PairFactoryModule", (m) => {
  const pairFactory = m.contract("PairFactory");

  return { pairFactory };
});

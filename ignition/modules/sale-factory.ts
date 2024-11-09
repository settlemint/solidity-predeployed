import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

export const SaleFactoryModule = buildModule("SaleFactoryModule", (m) => {
  const saleFactory = m.contract("SaleFactory");

  return {saleFactory};
});

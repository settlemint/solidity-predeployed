import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

export const TokenFactoryModule = buildModule("TokenFactoryModule", (m) => {
  const tokenFactory = m.contract("TokenFactory");

  return { tokenFactory };
});

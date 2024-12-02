import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { DemoModule } from "./demo";
import { PairFactoryModule } from "./pair-factory";
import { SaleFactoryModule } from "./sale-factory";
import { TokenFactoryModule } from "./token-factory";
import { TokensModule } from "./tokens";

export default buildModule("MainModule", (m) => {
  const { tokenFactory } = m.useModule(TokenFactoryModule);
  const { pairFactory } = m.useModule(PairFactoryModule);
  const { saleFactory } = m.useModule(SaleFactoryModule);
  const { usdc, usdt, dai, bond, option, future, swap, synthetic } =
    m.useModule(TokensModule);
  m.useModule(DemoModule);

  return {
    tokenFactory,
    pairFactory,
    saleFactory,
    usdc,
    usdt,
    dai,
    bond,
    option,
    future,
    swap,
    synthetic,
  };
});

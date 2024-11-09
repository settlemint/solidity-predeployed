import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { PairFactoryModule } from './pair-factory';
import { PairsModule } from './pairs';
import { SaleFactoryModule } from './sale-factory';
import { SalesModule } from './sales';
import { TokenFactoryModule } from './token-factory';
import { TokensModule } from './tokens';

export default buildModule("MainModule", (m) => {
  const { tokenFactory } = m.useModule(TokenFactoryModule);
  const { pairFactory } = m.useModule(PairFactoryModule);
  const { saleFactory } = m.useModule(SaleFactoryModule);
  const { usdc, usdt, dai, bond, option, future, swap, synthetic } = m.useModule(TokensModule);
  const { usdtSale, daiSale, bondSale, optionSale, futureSale, swapSale, syntheticSale } = m.useModule(SalesModule);
  const { bondUsdcPair, bondUsdtPair, bondDaiPair, optionUsdcPair, optionUsdtPair, optionDaiPair, futureUsdcPair, futureUsdtPair, futureDaiPair, swapUsdcPair, swapUsdtPair, swapDaiPair, syntheticUsdcPair, syntheticUsdtPair } = m.useModule(PairsModule);

  return {
    tokenFactory,
    pairFactory,
    saleFactory,
    usdc, usdt, dai, bond, option, future, swap, synthetic,
    usdtSale, daiSale, bondSale, optionSale, futureSale, swapSale, syntheticSale,
    bondUsdcPair, bondUsdtPair, bondDaiPair, optionUsdcPair, optionUsdtPair, optionDaiPair, futureUsdcPair, futureUsdtPair, futureDaiPair, swapUsdcPair, swapUsdtPair, swapDaiPair, syntheticUsdcPair, syntheticUsdtPair
  };
});

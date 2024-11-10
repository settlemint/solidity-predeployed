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
  const { bondUsdcPair, bondUsdtPair, bondDaiPair, optionUsdcPair, optionUsdtPair, optionDaiPair, futureUsdcPair, futureUsdtPair, futureDaiPair, swapUsdcPair, swapUsdtPair, swapDaiPair, syntheticUsdcPair, syntheticUsdtPair, syntheticDaiPair } = m.useModule(PairsModule);

  // Get test accounts
  const testAccounts = Array.from({ length: 9 }, (_, i) => m.getAccount(i + 1));

  // Random amounts for each account (reduced amounts)
  const randomAmounts = {
    bond: ["4", "6", "7", "4", "10", "3", "5", "4", "6"],
    option: ["7", "10", "3", "9", "4", "12", "6", "8", "7"],
    future: ["1", "2", "3", "1", "2", "2", "1", "2", "2"],
    usdc: ["400", "600", "750", "475", "1000", "375", "550", "450", "650"]
  };

  // Simulate different transactions for each account
  testAccounts.forEach((account, i) => {
    // Random selection of actions (not all accounts do everything)
    const doBondSale = Math.random() < 0.7;
    const doOptionSale = Math.random() < 0.6;
    const doFutureSale = Math.random() < 0.5;
    const doBondSwap = Math.random() < 0.8;
    const doOptionSwap = Math.random() < 0.7;
    const doFutureSwap = Math.random() < 0.6;
    const doSwapBack = Math.random() < 0.5;

    // Buy from sales (with smaller amounts)
    if (doBondSale) {
      const amount = `${randomAmounts.bond[i]}000000000000000000`;
      m.call(usdc, "approve", [bondSale.address, `${parseInt(randomAmounts.usdc[i]) * 100}000000000000000000`], { id: `approveBondSale${i}`, from: account });
      m.call(bondSale, "buyTokens", [amount], { id: `buyBond${i}`, from: account });
    }

    if (doOptionSale) {
      const amount = `${randomAmounts.option[i]}000000000000000000`;
      m.call(usdc, "approve", [optionSale.address, `${parseInt(randomAmounts.usdc[i]) * 50}000000000000000000`], { id: `approveOptionSale${i}`, from: account });
      m.call(optionSale, "buyTokens", [amount], { id: `buyOption${i}`, from: account });
    }

    if (doFutureSale) {
      const amount = `${randomAmounts.future[i]}000000000000000000`;
      m.call(usdc, "approve", [futureSale.address, `${parseInt(randomAmounts.usdc[i]) * 500}000000000000000000`], { id: `approveFutureSale${i}`, from: account });
      m.call(futureSale, "buyTokens", [amount], { id: `buyFuture${i}`, from: account });
    }

    // Swap in pairs (with 20% slippage tolerance)
    if (doBondSwap) {
      const usdcAmount = `${randomAmounts.usdc[i]}000000000000000000`;
      const minBondOut = `${Math.floor(parseInt(randomAmounts.usdc[i]) * 0.8 / 100)}000000000000000000`; // 80% of expected output
      m.call(usdc, "approve", [bondUsdcPair.address, usdcAmount], { id: `approveBondPair${i}`, from: account });
      m.call(bondUsdcPair, "swapBaseToQuote", [usdcAmount, minBondOut, "999999999999999"], { id: `swapToBond${i}`, from: account });
    }

    if (doOptionSwap) {
      const usdcAmount = `${Math.floor(parseInt(randomAmounts.usdc[i]) * 0.5)}000000000000000000`; // 50% of USDC amount
      const minOptionOut = `${Math.floor(parseInt(randomAmounts.usdc[i]) * 0.5 * 0.016)}000000000000000000`; // 80% of expected output
      m.call(usdc, "approve", [optionUsdcPair.address, usdcAmount], { id: `approveOptionPair${i}`, from: account });
      m.call(optionUsdcPair, "swapBaseToQuote", [usdcAmount, minOptionOut, "999999999999999"], { id: `swapToOption${i}`, from: account });
    }

    if (doFutureSwap) {
      const usdcAmount = `${Math.floor(parseInt(randomAmounts.usdc[i]) * 0.8)}000000000000000000`; // 80% of USDC amount
      const minFutureOut = `${Math.floor(parseInt(randomAmounts.usdc[i]) * 0.8 * 0.0016)}000000000000000000`; // 80% of expected output
      m.call(usdc, "approve", [futureUsdcPair.address, usdcAmount], { id: `approveFuturePair${i}`, from: account });
      m.call(futureUsdcPair, "swapBaseToQuote", [usdcAmount, minFutureOut, "999999999999999"], { id: `swapToFuture${i}`, from: account });
    }

    // Swap back with 20% slippage tolerance
    if (doSwapBack) {
      if (doBondSale || doBondSwap) {
        const bondAmount = `${Math.floor(parseInt(randomAmounts.bond[i]) * 0.3)}000000000000000000`; // 30% of held BOND
        const minUsdcOut = `${Math.floor(parseInt(randomAmounts.bond[i]) * 0.3 * 80)}000000000000000000`; // 80% of expected output
        m.call(bond, "approve", [bondUsdcPair.address, bondAmount], { id: `approveBondSwapBack${i}`, from: account });
        m.call(bondUsdcPair, "swapQuoteToBase", [bondAmount, minUsdcOut, "999999999999999"], { id: `swapFromBond${i}`, from: account });
      }

      if (doOptionSale || doOptionSwap) {
        const optionAmount = `${Math.floor(parseInt(randomAmounts.option[i]) * 0.2)}000000000000000000`; // 20% of held CALL
        const minUsdcOut = `${Math.floor(parseInt(randomAmounts.option[i]) * 0.2 * 40)}000000000000000000`; // 80% of expected output
        m.call(option, "approve", [optionUsdcPair.address, optionAmount], { id: `approveOptionSwapBack${i}`, from: account });
        m.call(optionUsdcPair, "swapQuoteToBase", [optionAmount, minUsdcOut, "999999999999999"], { id: `swapFromOption${i}`, from: account });
      }

      if (doFutureSale || doFutureSwap) {
        const futureAmount = `${Math.floor(parseInt(randomAmounts.future[i]) * 0.3)}000000000000000000`; // 30% of held BTCF
        const minUsdcOut = `${Math.floor(parseInt(randomAmounts.future[i]) * 0.3 * 400)}000000000000000000`; // 80% of expected output
        m.call(future, "approve", [futureUsdcPair.address, futureAmount], { id: `approveFutureSwapBack${i}`, from: account });
        m.call(futureUsdcPair, "swapQuoteToBase", [futureAmount, minUsdcOut, "999999999999999"], { id: `swapFromFuture${i}`, from: account });
      }
    }
  });

  return {
    tokenFactory,
    pairFactory,
    saleFactory,
    usdc, usdt, dai, bond, option, future, swap, synthetic,
    usdtSale, daiSale, bondSale, optionSale, futureSale, swapSale, syntheticSale,
    bondUsdcPair, bondUsdtPair, bondDaiPair, optionUsdcPair, optionUsdtPair, optionDaiPair,
    futureUsdcPair, futureUsdtPair, futureDaiPair, swapUsdcPair, swapUsdtPair, swapDaiPair,
    syntheticUsdcPair, syntheticUsdtPair, syntheticDaiPair
  };
});

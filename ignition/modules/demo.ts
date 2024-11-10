import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { NamedArtifactContractAtFuture } from "@nomicfoundation/ignition-core";
import { PairFactoryModule } from "./pair-factory";
import { SaleFactoryModule } from "./sale-factory";
import { TokensModule } from "./tokens";

interface PairConfig {
  quoteToken: NamedArtifactContractAtFuture<"Token">;
  baseToken: NamedArtifactContractAtFuture<"Token">;
  quoteTokens: bigint; // Amount in tokens (not wei)
  baseTokens: bigint; // Amount in tokens (not wei)
  namePrefix: string;
  afterDependency?: any;
}

interface SaleConfig {
  saleToken: NamedArtifactContractAtFuture<"Token">;
  paymentToken: NamedArtifactContractAtFuture<"Token">;
  priceTokens: bigint; // Price per token (not wei)
  depositTokens: bigint; // Amount to deposit (not wei)
  namePrefix: string;
  afterDependency?: any;
}

export const DemoModule = buildModule("DemoModule", (m) => {
  const { saleFactory } = m.useModule(SaleFactoryModule);
  const { pairFactory } = m.useModule(PairFactoryModule);
  const { usdc, usdt, dai, bond, option, future, swap, synthetic } =
    m.useModule(TokensModule);

  // Base amounts for stablecoins (10M each)
  const BASE_TOKENS = 10_000_000n;
  const DECIMALS = 10n ** 18n;

  function createPairWithLiquidity(config: PairConfig) {
    const {
      quoteToken,
      baseToken,
      quoteTokens,
      baseTokens,
      namePrefix,
      afterDependency,
    } = config;

    // Convert tokens to wei (all tokens use 18 decimals)
    const quoteAmount = (quoteTokens * DECIMALS).toString();
    const baseAmount = (baseTokens * DECIMALS).toString();

    const createPair = m.call(
      pairFactory,
      "createPair",
      [baseToken.address, quoteToken.address],
      { id: `create${namePrefix}Pair` }
    );

    const pairAddress = m.readEventArgument(createPair, "PairCreated", "pair", {
      id: `read${namePrefix}PairAddress`,
    });
    const pair = m.contractAt("Pair", pairAddress, {
      id: `contract${namePrefix}Pair`,
    });

    const quoteApproval = m.call(
      quoteToken,
      "approve",
      [pairAddress, quoteAmount],
      {
        id: `approve${namePrefix}Quote`,
        after: afterDependency ? [afterDependency] : undefined,
      }
    );

    const baseApproval = m.call(
      baseToken,
      "approve",
      [pairAddress, baseAmount],
      {
        id: `approve${namePrefix}Base`,
        after: afterDependency ? [afterDependency] : undefined,
      }
    );

    const addLiquidity = m.call(
      pair,
      "addLiquidity",
      [baseAmount, quoteAmount],
      {
        id: `addLiquidity${namePrefix}`,
        after: [quoteApproval, baseApproval],
      }
    );

    return { pair, addLiquidity };
  }

  function createSaleWithDeposit(config: SaleConfig) {
    const {
      saleToken,
      paymentToken,
      priceTokens,
      depositTokens,
      namePrefix,
      afterDependency,
    } = config;

    const paymentRecipient = m.getAccount(0);
    const toWei = (tokens: bigint) => (tokens * 10n ** 18n).toString();

    const priceAmount = toWei(priceTokens);
    const depositAmount = toWei(depositTokens);

    const createSale = m.call(
      saleFactory,
      "createSale",
      [saleToken.address, paymentToken.address, priceAmount, paymentRecipient],
      {
        id: `create${namePrefix}Sale`,
        after: afterDependency ? [afterDependency] : undefined,
      }
    );

    const saleAddress = m.readEventArgument(
      createSale,
      "SaleCreated",
      "saleAddress",
      { id: `read${namePrefix}SaleAddress` }
    );
    const sale = m.contractAt("Sale", saleAddress, {
      id: `contract${namePrefix}Sale`,
    });

    const approval = m.call(
      saleToken,
      "approve",
      [saleAddress, depositAmount],
      {
        id: `approve${namePrefix}Sale`,
        after: [createSale],
      }
    );

    const deposit = m.call(sale, "depositSaleTokens", [depositAmount], {
      id: `deposit${namePrefix}Sale`,
      after: [approval],
    });

    return { sale, deposit };
  }

  // BOND pairs ($100 each)
  const bondUsdc = createPairWithLiquidity({
    quoteToken: bond,
    baseToken: usdc,
    quoteTokens: 120_000n, // 120k BOND
    baseTokens: BASE_TOKENS,
    namePrefix: "BondUSDC",
  });

  const bondUsdt = createPairWithLiquidity({
    quoteToken: bond,
    baseToken: usdt,
    quoteTokens: 130_000n, // 130k BOND
    baseTokens: BASE_TOKENS,
    namePrefix: "BondUSDT",
    afterDependency: bondUsdc.addLiquidity,
  });

  const bondDai = createPairWithLiquidity({
    quoteToken: bond,
    baseToken: dai,
    quoteTokens: 140_000n, // 140k BOND
    baseTokens: BASE_TOKENS,
    namePrefix: "BondDAI",
    afterDependency: bondUsdt.addLiquidity,
  });

  // OPTION pairs ($50 each)
  const optionUsdc = createPairWithLiquidity({
    quoteToken: option,
    baseToken: usdc,
    quoteTokens: 200_000n, // 200k OPTION
    baseTokens: BASE_TOKENS,
    namePrefix: "OptionUSDC",
    afterDependency: bondDai.addLiquidity,
  });

  const optionUsdt = createPairWithLiquidity({
    quoteToken: option,
    baseToken: usdt,
    quoteTokens: 200_000n, // 200k OPTION
    baseTokens: BASE_TOKENS,
    namePrefix: "OptionUSDT",
    afterDependency: optionUsdc.addLiquidity,
  });

  const optionDai = createPairWithLiquidity({
    quoteToken: option,
    baseToken: dai,
    quoteTokens: 200_000n, // 200k OPTION
    baseTokens: BASE_TOKENS,
    namePrefix: "OptionDAI",
    afterDependency: optionUsdt.addLiquidity,
  });

  // FUTURE pairs ($500 each)
  const futureUsdc = createPairWithLiquidity({
    quoteToken: future,
    baseToken: usdc,
    quoteTokens: 20_000n, // 20k FUTURE
    baseTokens: BASE_TOKENS,
    namePrefix: "FutureUSDC",
    afterDependency: optionDai.addLiquidity,
  });

  const futureUsdt = createPairWithLiquidity({
    quoteToken: future,
    baseToken: usdt,
    quoteTokens: 20_000n, // 20k FUTURE
    baseTokens: BASE_TOKENS,
    namePrefix: "FutureUSDT",
    afterDependency: futureUsdc.addLiquidity,
  });

  const futureDai = createPairWithLiquidity({
    quoteToken: future,
    baseToken: dai,
    quoteTokens: 20_000n, // 20k FUTURE
    baseTokens: BASE_TOKENS,
    namePrefix: "FutureDAI",
    afterDependency: futureUsdt.addLiquidity,
  });

  // SWAP pairs ($20 each)
  const swapUsdc = createPairWithLiquidity({
    quoteToken: swap,
    baseToken: usdc,
    quoteTokens: 500_000n, // 500k SWAP
    baseTokens: BASE_TOKENS,
    namePrefix: "SwapUSDC",
    afterDependency: futureDai.addLiquidity,
  });

  const swapUsdt = createPairWithLiquidity({
    quoteToken: swap,
    baseToken: usdt,
    quoteTokens: 500_000n, // 500k SWAP
    baseTokens: BASE_TOKENS,
    namePrefix: "SwapUSDT",
    afterDependency: swapUsdc.addLiquidity,
  });

  const swapDai = createPairWithLiquidity({
    quoteToken: swap,
    baseToken: dai,
    quoteTokens: 500_000n, // 500k SWAP
    baseTokens: BASE_TOKENS,
    namePrefix: "SwapDAI",
    afterDependency: swapUsdt.addLiquidity,
  });

  // SYNTHETIC pairs ($2000 each)
  const syntheticUsdc = createPairWithLiquidity({
    quoteToken: synthetic,
    baseToken: usdc,
    quoteTokens: 5_000n, // 5k SYNTHETIC
    baseTokens: BASE_TOKENS,
    namePrefix: "SyntheticUSDC",
    afterDependency: swapDai.addLiquidity,
  });

  const syntheticUsdt = createPairWithLiquidity({
    quoteToken: synthetic,
    baseToken: usdt,
    quoteTokens: 5_000n, // 5k SYNTHETIC
    baseTokens: BASE_TOKENS,
    namePrefix: "SyntheticUSDT",
    afterDependency: syntheticUsdc.addLiquidity,
  });

  const syntheticDai = createPairWithLiquidity({
    quoteToken: synthetic,
    baseToken: dai,
    quoteTokens: 5_000n, // 5k SYNTHETIC
    baseTokens: BASE_TOKENS,
    namePrefix: "SyntheticDAI",
    afterDependency: syntheticUsdt.addLiquidity,
  });

  // USDT/USDC Sale - deposit 500k USDT ($1.00)
  const usdtSale = createSaleWithDeposit({
    saleToken: usdt,
    paymentToken: usdc,
    priceTokens: 1n,
    depositTokens: 500_000n,
    namePrefix: "USDT",
    afterDependency: syntheticDai.addLiquidity,
  });

  // DAI/USDC Sale - deposit 500k DAI ($1.00)
  const daiSale = createSaleWithDeposit({
    saleToken: dai,
    paymentToken: usdc,
    priceTokens: 1n,
    depositTokens: 500_000n,
    namePrefix: "DAI",
    afterDependency: usdtSale.deposit,
  });

  // BOND/USDC Sale - deposit 50k BOND ($100.00)
  const bondSale = createSaleWithDeposit({
    saleToken: bond,
    paymentToken: usdc,
    priceTokens: 100n,
    depositTokens: 50_000n,
    namePrefix: "Bond",
    afterDependency: daiSale.deposit,
  });

  // OPTION/USDC Sale - deposit 50k CALL ($50.00)
  const optionSale = createSaleWithDeposit({
    saleToken: option,
    paymentToken: usdc,
    priceTokens: 50n,
    depositTokens: 50_000n,
    namePrefix: "Option",
    afterDependency: bondSale.deposit,
  });

  // FUTURE/USDC Sale - deposit 5k BTCF ($500.00)
  const futureSale = createSaleWithDeposit({
    saleToken: future,
    paymentToken: usdc,
    priceTokens: 500n,
    depositTokens: 5_000n,
    namePrefix: "Future",
    afterDependency: optionSale.deposit,
  });

  // SWAP/USDC Sale - deposit 50k SWAP ($20.00)
  const swapSale = createSaleWithDeposit({
    saleToken: swap,
    paymentToken: usdc,
    priceTokens: 20n,
    depositTokens: 50_000n,
    namePrefix: "Swap",
    afterDependency: futureSale.deposit,
  });

  // SYNTHETIC/USDC Sale - deposit 25k XAUT ($2000.00)
  const syntheticSale = createSaleWithDeposit({
    saleToken: synthetic,
    paymentToken: usdc,
    priceTokens: 2_000n,
    depositTokens: 25_000n,
    namePrefix: "Synthetic",
    afterDependency: swapSale.deposit,
  });

  // Get test accounts
  const testAccounts = Array.from({ length: 9 }, (_, i) => m.getAccount(i + 1));

  // Mint tokens to test accounts
  const mintUsdcToAccount1 = m.call(
    usdc,
    "mint",
    [
      testAccounts[0],
      (10000n * DECIMALS).toString(), // 10k USDC
    ],
    {
      id: "mintUsdcToAccount1",
      after: [syntheticSale.deposit],
    }
  );

  const mintUsdcToAccount2 = m.call(
    usdc,
    "mint",
    [
      testAccounts[1],
      (10000n * DECIMALS).toString(), // 10k USDC
    ],
    {
      id: "mintUsdcToAccount2",
      after: [mintUsdcToAccount1],
    }
  );

  const mintUsdtToAccount3 = m.call(
    usdt,
    "mint",
    [
      testAccounts[2],
      (20000n * DECIMALS).toString(), // 20k USDT
    ],
    {
      id: "mintUsdtToAccount3",
      after: [mintUsdcToAccount2],
    }
  );

  // Test account 1 buys BOND with USDC (1000 USDC for BOND)
  const buyBondApproval = m.call(
    usdc,
    "approve",
    [
      bondUsdc.pair.address,
      (1000n * DECIMALS).toString(), // 1000 tokens in wei
    ],
    {
      id: "approveBondSwap",
      from: testAccounts[0],
      after: [mintUsdtToAccount3],
    }
  );

  const buyBond = m.call(
    bondUsdc.pair,
    "swapBaseToQuote",
    [
      (1000n * DECIMALS).toString(), // 1000 tokens in wei
      0n,
      999999999n,
    ],
    {
      id: "executeBondSwap",
      from: testAccounts[0],
      after: [buyBondApproval],
    }
  );

  const bondAmount = 50n * DECIMALS; // Want to buy 50 BOND
  const usdcAmount = 5000n * DECIMALS; // Need to pay 5000 USDC (50 BOND * 100 USDC/BOND)

  // Test account 2 buys from BOND sale (5000 USDC worth)
  const buyBondSaleApproval = m.call(
    usdc,
    "approve",
    [
      bondSale.sale.address,
      usdcAmount.toString(), // Approve 5000 USDC
    ],
    {
      id: "approveBondSaleUSDC",
      from: testAccounts[1],
      after: [buyBond],
    }
  );

  const buyFromBondSale = m.call(
    bondSale.sale,
    "buyTokens",
    [
      bondAmount.toString(), // Buy 50 BOND
    ],
    {
      id: "executeBondSaleBuy",
      from: testAccounts[1],
      after: [buyBondSaleApproval],
    }
  );

  // Test account 3 buys SYNTHETIC with USDT (10000 USDT)
  const buySyntheticApproval = m.call(
    usdt,
    "approve",
    [
      syntheticUsdt.pair.address,
      (10000n * DECIMALS).toString(), // 10000 tokens in wei
    ],
    {
      id: "approveSyntheticSwap",
      from: testAccounts[2],
      after: [buyFromBondSale],
    }
  );

  const buySynthetic = m.call(
    syntheticUsdt.pair,
    "swapBaseToQuote",
    [
      (10000n * DECIMALS).toString(), // 10000 tokens in wei
      0n,
      999999999n,
    ],
    {
      id: "executeSyntheticSwap",
      from: testAccounts[2],
      after: [buySyntheticApproval],
    }
  );

  return {
    bondUsdcPair: bondUsdc.pair,
    bondUsdtPair: bondUsdt.pair,
    bondDaiPair: bondDai.pair,
    optionUsdcPair: optionUsdc.pair,
    optionUsdtPair: optionUsdt.pair,
    optionDaiPair: optionDai.pair,
    futureUsdcPair: futureUsdc.pair,
    futureUsdtPair: futureUsdt.pair,
    futureDaiPair: futureDai.pair,
    swapUsdcPair: swapUsdc.pair,
    swapUsdtPair: swapUsdt.pair,
    swapDaiPair: swapDai.pair,
    syntheticUsdcPair: syntheticUsdc.pair,
    syntheticUsdtPair: syntheticUsdt.pair,
    syntheticDaiPair: syntheticDai.pair,
    usdtSale: usdtSale.sale,
    daiSale: daiSale.sale,
    bondSale: bondSale.sale,
    optionSale: optionSale.sale,
    futureSale: futureSale.sale,
    swapSale: swapSale.sale,
    syntheticSale: syntheticSale.sale,
  };
});

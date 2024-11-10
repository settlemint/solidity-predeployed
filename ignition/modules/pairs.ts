import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { PairFactoryModule } from './pair-factory';
import { TokensModule } from './tokens';

export const PairsModule = buildModule("PairsModule", (m) => {
  const { pairFactory } = m.useModule(PairFactoryModule);
  const {
    usdc, usdt, dai,
    bond, option, future,
    swap, synthetic
  } = m.useModule(TokensModule);

  // BOND pairs ($100 each)
  const createBondUsdcPair = m.call(pairFactory, "createPair", [
    bond.address, usdc.address
  ], { id: "createBondUSDCPair" });
  const bondUsdcPairAddress = m.readEventArgument(createBondUsdcPair, "PairCreated", "pair", { id: "readBondUSDCPairAddress" });
  const bondUsdcPair = m.contractAt("Pair", bondUsdcPairAddress, { id: "contractBondUSDCPair" });

  const bondUsdcApproval = m.call(bond, "approve", [bondUsdcPairAddress, "100000000000000000000000"], { id: "approveBondUSDCPair" });
  const usdcBondApproval = m.call(usdc, "approve", [bondUsdcPairAddress, "10000000000000000000000000"], { id: "approveUSDCBondPair" });
  const addLiquidityBondUSDC = m.call(bondUsdcPair, "addLiquidity", [
    "10000000000000000000000000", // 10M USDC (base)
    "100000000000000000000000", // 100k BOND (quote)
  ], {
    id: "addLiquidityBondUSDC",
    after: [bondUsdcApproval, usdcBondApproval]
  });

  const createBondUsdtPair = m.call(pairFactory, "createPair", [
    bond.address, usdt.address
  ], { id: "createBondUSDTPair" });
  const bondUsdtPairAddress = m.readEventArgument(createBondUsdtPair, "PairCreated", "pair", { id: "readBondUSDTPairAddress" });
  const bondUsdtPair = m.contractAt("Pair", bondUsdtPairAddress, { id: "contractBondUSDTPair" });

  const bondUsdtApproval = m.call(bond, "approve", [bondUsdtPairAddress, "10000000000000000000000000"], { id: "approveBondUSDTPair",after: [addLiquidityBondUSDC] });
  const usdtBondApproval = m.call(usdt, "approve", [bondUsdtPairAddress, "100000000000000000000000"], { id: "approveUSDTBondPair",after: [addLiquidityBondUSDC] });
  const addLiquidityBondUSDT = m.call(bondUsdtPair, "addLiquidity", [
    "10000000000000000000000000", // 10M USDT (base)
    "100000000000000000000000", // 100k BOND (quote)
  ], {
    id: "addLiquidityBondUSDT",
    after: [bondUsdtApproval, usdtBondApproval]
  });

  const createBondDaiPair = m.call(pairFactory, "createPair", [
    bond.address, dai.address
  ], { id: "createBondDAIPair" });
  const bondDaiPairAddress = m.readEventArgument(createBondDaiPair, "PairCreated", "pair", { id: "readBondDAIPairAddress" });
  const bondDaiPair = m.contractAt("Pair", bondDaiPairAddress, { id: "contractBondDAIPair" });

  const bondDaiApproval = m.call(bond, "approve", [bondDaiPairAddress, "100000000000000000000000"], { id: "approveBondDAIPair",after: [addLiquidityBondUSDC] });
  const daiBondApproval = m.call(dai, "approve", [bondDaiPairAddress, "10000000000000000000000000"], { id: "approveDAIBondPair",after: [addLiquidityBondUSDC] });
  const addLiquidityBondDAI = m.call(bondDaiPair, "addLiquidity", [
    "10000000000000000000000000", // 10M DAI (base)
    "100000000000000000000000", // 100k BOND (quote)
  ], {
    id: "addLiquidityBondDAI",
    after: [bondDaiApproval, daiBondApproval]
  });

  // OPTION pairs ($50 each)
  const createOptionUsdcPair = m.call(pairFactory, "createPair", [
    option.address, usdc.address
  ], { id: "createOptionUSDCPair" });
  const optionUsdcPairAddress = m.readEventArgument(createOptionUsdcPair, "PairCreated", "pair", { id: "readOptionUSDCPairAddress" });
  const optionUsdcPair = m.contractAt("Pair", optionUsdcPairAddress, { id: "contractOptionUSDCPair" });

  const optionUsdcApproval = m.call(option, "approve", [optionUsdcPairAddress, "200000000000000000000000"], { id: "approveOptionUSDCPair",after: [addLiquidityBondUSDC] });
  const usdcOptionApproval = m.call(usdc, "approve", [optionUsdcPairAddress, "10000000000000000000000000"], { id: "approveUSDCOptionPair",after: [addLiquidityBondUSDC] });
  const addLiquidityOptionUSDC = m.call(optionUsdcPair, "addLiquidity", [
    "10000000000000000000000000", // 10M USDC (base)
    "200000000000000000000000", // 200k CALL (quote)
  ], {
    id: "addLiquidityOptionUSDC",
    after: [addLiquidityBondUSDC, optionUsdcApproval, usdcOptionApproval]
  });

  const createOptionUsdtPair = m.call(pairFactory, "createPair", [
    option.address, usdt.address
  ], { id: "createOptionUSDTPair" });
  const optionUsdtPairAddress = m.readEventArgument(createOptionUsdtPair, "PairCreated", "pair", { id: "readOptionUSDTPairAddress" });
  const optionUsdtPair = m.contractAt("Pair", optionUsdtPairAddress, { id: "contractOptionUSDTPair" });

  const optionUsdtApproval = m.call(option, "approve", [optionUsdtPairAddress, "200000000000000000000000"], { id: "approveOptionUSDTPair",after: [addLiquidityBondUSDT] });
  const usdtOptionApproval = m.call(usdt, "approve", [optionUsdtPairAddress, "10000000000000000000000000"], { id: "approveUSDTOptionPair",after: [addLiquidityBondUSDT] });
  const addLiquidityOptionUSDT = m.call(optionUsdtPair, "addLiquidity", [
    "10000000000000000000000000", // 10M USDT (base)
    "200000000000000000000000", // 200k CALL (quote)
  ], {
    id: "addLiquidityOptionUSDT",
    after: [addLiquidityBondUSDT,optionUsdtApproval, usdtOptionApproval]
  });

  const createOptionDaiPair = m.call(pairFactory, "createPair", [
    option.address, dai.address
  ], { id: "createOptionDAIPair" });
  const optionDaiPairAddress = m.readEventArgument(createOptionDaiPair, "PairCreated", "pair", { id: "readOptionDAIPairAddress" });
  const optionDaiPair = m.contractAt("Pair", optionDaiPairAddress, { id: "contractOptionDAIPair" });

  const optionDaiApproval = m.call(option, "approve", [optionDaiPairAddress, "10000000000000000000000000"], { id: "approveOptionDAIPair",after: [addLiquidityBondDAI] });
  const daiOptionApproval = m.call(dai, "approve", [optionDaiPairAddress, "10000000000000000000000000"], { id: "approveDAIOptionPair",after: [addLiquidityBondDAI] });
  const addLiquidityOptionDAI = m.call(optionDaiPair, "addLiquidity", [
    "10000000000000000000000000", // 10M DAI (base)
    "200000000000000000000000", // 200k CALL (quote)
  ], {
    id: "addLiquidityOptionDAI",
    after: [addLiquidityBondDAI, optionDaiApproval, daiOptionApproval]
  });

  // FUTURE pairs ($500 each)
  const createFutureUsdcPair = m.call(pairFactory, "createPair", [
    future.address, usdc.address
  ], { id: "createFutureUSDCPair" });
  const futureUsdcPairAddress = m.readEventArgument(createFutureUsdcPair, "PairCreated", "pair", { id: "readFutureUSDCPairAddress" });
  const futureUsdcPair = m.contractAt("Pair", futureUsdcPairAddress, { id: "contractFutureUSDCPair" });

  const futureUsdcApproval = m.call(future, "approve", [futureUsdcPairAddress, "200000000000000000000000"], { id: "approveFutureUSDCPair",after: [addLiquidityOptionUSDC] });
  const usdcFutureApproval = m.call(usdc, "approve", [futureUsdcPairAddress, "10000000000000000000000000"], { id: "approveUSDCFuturePair",after: [addLiquidityOptionUSDC] });
  const addLiquidityFutureUSDC = m.call(futureUsdcPair, "addLiquidity", [
    "10000000000000000000000000", // 10M USDC (base)
    "20000000000000000000000", // 20k BTCF (quote)
  ], {
    id: "addLiquidityFutureUSDC",
    after: [addLiquidityOptionUSDC, futureUsdcApproval, usdcFutureApproval]
  });

  const createFutureUsdtPair = m.call(pairFactory, "createPair", [
    future.address, usdt.address
  ], { id: "createFutureUSDTPair" });
  const futureUsdtPairAddress = m.readEventArgument(createFutureUsdtPair, "PairCreated", "pair", { id: "readFutureUSDTPairAddress" });
  const futureUsdtPair = m.contractAt("Pair", futureUsdtPairAddress, { id: "contractFutureUSDTPair" });

  const futureUsdtApproval = m.call(future, "approve", [futureUsdtPairAddress, "10000000000000000000000000"], { id: "approveFutureUSDTPair",after: [addLiquidityOptionUSDT] });
  const usdtFutureApproval = m.call(usdt, "approve", [futureUsdtPairAddress, "20000000000000000000000000"], { id: "approveUSDTFuturePair",after: [addLiquidityOptionUSDT] });
  const addLiquidityFutureUSDT = m.call(futureUsdtPair, "addLiquidity", [
    "10000000000000000000000000", // 10M USDT (base)
    "20000000000000000000000", // 20k BTCF (quote)
  ], {
    id: "addLiquidityFutureUSDT",
    after: [addLiquidityOptionUSDT,futureUsdtApproval, usdtFutureApproval]
  });

  const createFutureDaiPair = m.call(pairFactory, "createPair", [
    future.address, dai.address
  ], { id: "createFutureDAIPair" });
  const futureDaiPairAddress = m.readEventArgument(createFutureDaiPair, "PairCreated", "pair", { id: "readFutureDAIPairAddress" });
  const futureDaiPair = m.contractAt("Pair", futureDaiPairAddress, { id: "contractFutureDAIPair" });

  const futureDaiApproval = m.call(future, "approve", [futureDaiPairAddress, "10000000000000000000000000"], { id: "approveFutureDAIPair",after: [addLiquidityOptionDAI] });
  const daiFutureApproval = m.call(dai, "approve", [futureDaiPairAddress, "10000000000000000000000000"], { id: "approveDAIFuturePair",after: [addLiquidityOptionDAI] });
  const addLiquidityFutureDAI = m.call(futureDaiPair, "addLiquidity", [
    "10000000000000000000000000", // 10M DAI (base)
    "20000000000000000000000", // 20k BTCF (quote)
  ], {
    id: "addLiquidityFutureDAI",
    after: [addLiquidityOptionDAI, futureDaiApproval, daiFutureApproval]
  });

  // SWAP pairs ($20 each)
  const createSwapUsdcPair = m.call(pairFactory, "createPair", [
    swap.address, usdc.address
  ], { id: "createSwapUSDCPair" });
  const swapUsdcPairAddress = m.readEventArgument(createSwapUsdcPair, "PairCreated", "pair", { id: "readSwapUSDCPairAddress" });
  const swapUsdcPair = m.contractAt("Pair", swapUsdcPairAddress, { id: "contractSwapUSDCPair" });

  const swapUsdcApproval = m.call(swap, "approve", [swapUsdcPairAddress, "500000000000000000000000"], { id: "approveSwapUSDCPair",after: [addLiquidityFutureUSDC] });
  const usdcSwapApproval = m.call(usdc, "approve", [swapUsdcPairAddress, "10000000000000000000000000"], { id: "approveUSDCSwapPair",after: [addLiquidityFutureUSDC] });
  const addLiquiditySwapUSDC = m.call(swapUsdcPair, "addLiquidity", [
    "10000000000000000000000000", // 10M USDC (base)
    "500000000000000000000000", // 500k SWAP (quote)
  ], {
    id: "addLiquiditySwapUSDC",
    after: [addLiquidityFutureUSDC, swapUsdcApproval, usdcSwapApproval]
  });

  const createSwapUsdtPair = m.call(pairFactory, "createPair", [
    swap.address, usdt.address
  ], { id: "createSwapUSDTPair" });
  const swapUsdtPairAddress = m.readEventArgument(createSwapUsdtPair, "PairCreated", "pair", { id: "readSwapUSDTPairAddress" });
  const swapUsdtPair = m.contractAt("Pair", swapUsdtPairAddress, { id: "contractSwapUSDTPair" });

  const swapUsdtApproval = m.call(swap, "approve", [swapUsdtPairAddress, "500000000000000000000000"], { id: "approveSwapUSDTPair",after: [addLiquidityFutureUSDT] });
  const usdtSwapApproval = m.call(usdt, "approve", [swapUsdtPairAddress, "10000000000000000000000000"], { id: "approveUSDTSwapPair",after: [addLiquidityFutureUSDT] });
  const addLiquiditySwapUSDT = m.call(swapUsdtPair, "addLiquidity", [
    "10000000000000000000000000", // 10M USDT (base)
    "500000000000000000000000", // 500k SWAP (quote)
  ], {
    id: "addLiquiditySwapUSDT",
    after: [addLiquidityFutureUSDT,swapUsdtApproval, usdtSwapApproval]
  });

  const createSwapDaiPair = m.call(pairFactory, "createPair", [
    swap.address, dai.address
  ], { id: "createSwapDAIPair" });
  const swapDaiPairAddress = m.readEventArgument(createSwapDaiPair, "PairCreated", "pair", { id: "readSwapDAIPairAddress" });
  const swapDaiPair = m.contractAt("Pair", swapDaiPairAddress, { id: "contractSwapDAIPair" });

  const swapDaiApproval = m.call(swap, "approve", [swapDaiPairAddress, "10000000000000000000000000"], { id: "approveSwapDAIPair",after: [addLiquidityFutureDAI] });
  const daiSwapApproval = m.call(dai, "approve", [swapDaiPairAddress, "50000000000000000000000000"], { id: "approveDAISwapPair",after: [addLiquidityFutureDAI] });
  const addLiquiditySwapDAI = m.call(swapDaiPair, "addLiquidity", [
    "10000000000000000000000000", // 10M DAI (base)
    "500000000000000000000000", // 500k SWAP (quote)
  ], {
    id: "addLiquiditySwapDAI",
    after: [addLiquidityFutureDAI, swapDaiApproval, daiSwapApproval]
  });

  // SYNTHETIC pairs ($2000 each)
  const createSyntheticUsdcPair = m.call(pairFactory, "createPair", [
    synthetic.address, usdc.address
  ], { id: "createSyntheticUSDCPair" });
  const syntheticUsdcPairAddress = m.readEventArgument(createSyntheticUsdcPair, "PairCreated", "pair", { id: "readSyntheticUSDCPairAddress" });
  const syntheticUsdcPair = m.contractAt("Pair", syntheticUsdcPairAddress, { id: "contractSyntheticUSDCPair" });

  const syntheticUsdcApproval = m.call(synthetic, "approve", [syntheticUsdcPairAddress, "500000000000000000000000"], { id: "approveSyntheticUSDCPair",after: [addLiquiditySwapUSDC] });
  const usdcSyntheticApproval = m.call(usdc, "approve", [syntheticUsdcPairAddress, "10000000000000000000000000"], { id: "approveUSDCSyntheticPair",after: [addLiquiditySwapUSDC] });
  m.call(syntheticUsdcPair, "addLiquidity", [
    "10000000000000000000000000", // 10M USDC (base)
    "5000000000000000000000", // 5k XAUT (quote)
  ], {
    id: "addLiquiditySyntheticUSDC",
    after: [addLiquiditySwapUSDC, syntheticUsdcApproval, usdcSyntheticApproval]
  });

  const createSyntheticUsdtPair = m.call(pairFactory, "createPair", [
    synthetic.address, usdt.address
  ], { id: "createSyntheticUSDTPair" });
  const syntheticUsdtPairAddress = m.readEventArgument(createSyntheticUsdtPair, "PairCreated", "pair", { id: "readSyntheticUSDTPairAddress" });
  const syntheticUsdtPair = m.contractAt("Pair", syntheticUsdtPairAddress, { id: "contractSyntheticUSDTPair" });

  const syntheticUsdtApproval = m.call(synthetic, "approve", [syntheticUsdtPairAddress, "500000000000000000000000"], { id: "approveSyntheticUSDTPair",after: [addLiquiditySwapUSDT] });
  const usdtSyntheticApproval = m.call(usdt, "approve", [syntheticUsdtPairAddress, "10000000000000000000000000"], { id: "approveUSDTSyntheticPair",after: [addLiquiditySwapUSDT] });
  m.call(syntheticUsdtPair, "addLiquidity", [
    "10000000000000000000000000", // 10M USDT (base)
    "5000000000000000000000", // 5k XAUT (quote)
  ], {
    id: "addLiquiditySyntheticUSDT",
    after: [addLiquiditySwapUSDT, syntheticUsdtApproval, usdtSyntheticApproval]
  });

  const createSyntheticDaiPair = m.call(pairFactory, "createPair", [
    synthetic.address, dai.address
  ], { id: "createSyntheticDAIPair" });
  const syntheticDaiPairAddress = m.readEventArgument(createSyntheticDaiPair, "PairCreated", "pair", { id: "readSyntheticDAIPairAddress" });
  const syntheticDaiPair = m.contractAt("Pair", syntheticDaiPairAddress, { id: "contractSyntheticDAIPair" });

  const syntheticDaiApproval = m.call(synthetic, "approve", [syntheticDaiPairAddress, "10000000000000000000000000"], { id: "approveSyntheticDAIPair",after: [addLiquiditySwapDAI] });
  const daiSyntheticApproval = m.call(dai, "approve", [syntheticDaiPairAddress, "10000000000000000000000000"], { id: "approveDAISyntheticPair",after: [addLiquiditySwapDAI] });
  m.call(syntheticDaiPair, "addLiquidity", [
    "10000000000000000000000000", // 10M DAI (base)
    "5000000000000000000000", // 5k XAUT (quote)
  ], {
    id: "addLiquiditySyntheticDAI",
    after: [addLiquiditySwapDAI, syntheticDaiApproval, daiSyntheticApproval]
  });

  return {
    bondUsdcPair,
    bondUsdtPair,
    bondDaiPair,
    optionUsdcPair,
    optionUsdtPair,
    optionDaiPair,
    futureUsdcPair,
    futureUsdtPair,
    futureDaiPair,
    swapUsdcPair,
    swapUsdtPair,
    swapDaiPair,
    syntheticUsdcPair,
    syntheticUsdtPair,
    syntheticDaiPair
  };
});

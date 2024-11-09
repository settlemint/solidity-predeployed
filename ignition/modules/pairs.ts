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

  m.call(bond, "approve", [bondUsdcPairAddress, "100000000000000000000000"], { id: "approveBondUSDCPair" });
  m.call(usdc, "approve", [bondUsdcPairAddress, "100000000000000000000000"], { id: "approveUSDCBondPair" });
  m.call(bondUsdcPair, "addLiquidity", [
    "1000000000000000000000", // 1000 BOND
    "100000000000000000000000" // 100,000 USDC
  ], { id: "addLiquidityBondUSDC" });

  const createBondUsdtPair = m.call(pairFactory, "createPair", [
    bond.address, usdt.address
  ], { id: "createBondUSDTPair" });
  const bondUsdtPairAddress = m.readEventArgument(createBondUsdtPair, "PairCreated", "pair", { id: "readBondUSDTPairAddress" });
  const bondUsdtPair = m.contractAt("Pair", bondUsdtPairAddress, { id: "contractBondUSDTPair" });

  m.call(bond, "approve", [bondUsdtPairAddress, "100000000000000000000000"], { id: "approveBondUSDTPair" });
  m.call(usdt, "approve", [bondUsdtPairAddress, "100000000000000000000000"], { id: "approveUSDTBondPair" });
  m.call(bondUsdtPair, "addLiquidity", [
    "1000000000000000000000", // 1000 BOND
    "100000000000000000000000" // 100,000 USDT
  ], { id: "addLiquidityBondUSDT" });

  const createBondDaiPair = m.call(pairFactory, "createPair", [
    bond.address, dai.address
  ], { id: "createBondDAIPair" });
  const bondDaiPairAddress = m.readEventArgument(createBondDaiPair, "PairCreated", "pair", { id: "readBondDAIPairAddress" });
  const bondDaiPair = m.contractAt("Pair", bondDaiPairAddress, { id: "contractBondDAIPair" });

  m.call(bond, "approve", [bondDaiPairAddress, "100000000000000000000000"], { id: "approveBondDAIPair" });
  m.call(dai, "approve", [bondDaiPairAddress, "100000000000000000000000"], { id: "approveDAIBondPair" });
  m.call(bondDaiPair, "addLiquidity", [
    "1000000000000000000000", // 1000 BOND
    "100000000000000000000000" // 100,000 DAI
  ], { id: "addLiquidityBondDAI" });

  // OPTION pairs ($50 each)
  const createOptionUsdcPair = m.call(pairFactory, "createPair", [
    option.address, usdc.address
  ], { id: "createOptionUSDCPair" });
  const optionUsdcPairAddress = m.readEventArgument(createOptionUsdcPair, "PairCreated", "pair", { id: "readOptionUSDCPairAddress" });
  const optionUsdcPair = m.contractAt("Pair", optionUsdcPairAddress, { id: "contractOptionUSDCPair" });

  m.call(option, "approve", [optionUsdcPairAddress, "2000000000000000000000"], { id: "approveOptionUSDCPair" });
  m.call(usdc, "approve", [optionUsdcPairAddress, "100000000000000000000000"], { id: "approveUSDCOptionPair" });
  m.call(optionUsdcPair, "addLiquidity", [
    "2000000000000000000000", // 2000 CALL
    "100000000000" // 100,000 USDC
  ], { id: "addLiquidityOptionUSDC" });

  const createOptionUsdtPair = m.call(pairFactory, "createPair", [
    option.address, usdt.address
  ], { id: "createOptionUSDTPair" });
  const optionUsdtPairAddress = m.readEventArgument(createOptionUsdtPair, "PairCreated", "pair", { id: "readOptionUSDTPairAddress" });
  const optionUsdtPair = m.contractAt("Pair", optionUsdtPairAddress, { id: "contractOptionUSDTPair" });

  m.call(option, "approve", [optionUsdtPairAddress, "2000000000000000000000"], { id: "approveOptionUSDTPair" });
  m.call(usdt, "approve", [optionUsdtPairAddress, "100000000000000000000000"], { id: "approveUSDTOptionPair" });
  m.call(optionUsdtPair, "addLiquidity", [
    "2000000000000000000000", // 2000 CALL
    "100000000000" // 100,000 USDT
  ], { id: "addLiquidityOptionUSDT" });

  const createOptionDaiPair = m.call(pairFactory, "createPair", [
    option.address, dai.address
  ], { id: "createOptionDAIPair" });
  const optionDaiPairAddress = m.readEventArgument(createOptionDaiPair, "PairCreated", "pair", { id: "readOptionDAIPairAddress" });
  const optionDaiPair = m.contractAt("Pair", optionDaiPairAddress, { id: "contractOptionDAIPair" });

  m.call(option, "approve", [optionDaiPairAddress, "100000000000000000000000"], { id: "approveOptionDAIPair" });
  m.call(dai, "approve", [optionDaiPairAddress, "100000000000000000000000"], { id: "approveDAIOptionPair" });
  m.call(optionDaiPair, "addLiquidity", [
    "2000000000000000000000", // 2000 CALL
    "100000000000000000000000" // 100,000 DAI
  ], { id: "addLiquidityOptionDAI" });

  // FUTURE pairs ($500 each)
  const createFutureUsdcPair = m.call(pairFactory, "createPair", [
    future.address, usdc.address
  ], { id: "createFutureUSDCPair" });
  const futureUsdcPairAddress = m.readEventArgument(createFutureUsdcPair, "PairCreated", "pair", { id: "readFutureUSDCPairAddress" });
  const futureUsdcPair = m.contractAt("Pair", futureUsdcPairAddress, { id: "contractFutureUSDCPair" });

  m.call(future, "approve", [futureUsdcPairAddress, "200000000000000000000"], { id: "approveFutureUSDCPair" });
  m.call(usdc, "approve", [futureUsdcPairAddress, "100000000000000000000000"], { id: "approveUSDCFuturePair" });
  m.call(futureUsdcPair, "addLiquidity", [
    "200000000000000000000", // 200 BTCF
    "100000000000" // 100,000 USDC
  ], { id: "addLiquidityFutureUSDC" });

  const createFutureUsdtPair = m.call(pairFactory, "createPair", [
    future.address, usdt.address
  ], { id: "createFutureUSDTPair" });
  const futureUsdtPairAddress = m.readEventArgument(createFutureUsdtPair, "PairCreated", "pair", { id: "readFutureUSDTPairAddress" });
  const futureUsdtPair = m.contractAt("Pair", futureUsdtPairAddress, { id: "contractFutureUSDTPair" });

  m.call(future, "approve", [futureUsdtPairAddress, "100000000000000000000000"], { id: "approveFutureUSDTPair" });
  m.call(usdt, "approve", [futureUsdtPairAddress, "200000000000000000000000"], { id: "approveUSDTFuturePair" });
  m.call(futureUsdtPair, "addLiquidity", [
    "200000000000000000000", // 200 BTCF
    "100000000000" // 100,000 USDT
  ], { id: "addLiquidityFutureUSDT" });

  const createFutureDaiPair = m.call(pairFactory, "createPair", [
    future.address, dai.address
  ], { id: "createFutureDAIPair" });
  const futureDaiPairAddress = m.readEventArgument(createFutureDaiPair, "PairCreated", "pair", { id: "readFutureDAIPairAddress" });
  const futureDaiPair = m.contractAt("Pair", futureDaiPairAddress, { id: "contractFutureDAIPair" });

  m.call(future, "approve", [futureDaiPairAddress, "100000000000000000000000"], { id: "approveFutureDAIPair" });
  m.call(dai, "approve", [futureDaiPairAddress, "100000000000000000000000"], { id: "approveDAIFuturePair" });
  m.call(futureDaiPair, "addLiquidity", [
    "200000000000000000000", // 200 BTCF
    "100000000000000000000000" // 100,000 DAI
  ], { id: "addLiquidityFutureDAI" });

  // SWAP pairs ($20 each)
  const createSwapUsdcPair = m.call(pairFactory, "createPair", [
    swap.address, usdc.address
  ], { id: "createSwapUSDCPair" });
  const swapUsdcPairAddress = m.readEventArgument(createSwapUsdcPair, "PairCreated", "pair", { id: "readSwapUSDCPairAddress" });
  const swapUsdcPair = m.contractAt("Pair", swapUsdcPairAddress, { id: "contractSwapUSDCPair" });

  m.call(swap, "approve", [swapUsdcPairAddress, "5000000000000000000000"], { id: "approveSwapUSDCPair" });
  m.call(usdc, "approve", [swapUsdcPairAddress, "100000000000000000000000"], { id: "approveUSDCSwapPair" });
  m.call(swapUsdcPair, "addLiquidity", [
    "5000000000000000000000", // 5000 SWAP
    "100000000000" // 100,000 USDC
  ], { id: "addLiquiditySwapUSDC" });

  const createSwapUsdtPair = m.call(pairFactory, "createPair", [
    swap.address, usdt.address
  ], { id: "createSwapUSDTPair" });
  const swapUsdtPairAddress = m.readEventArgument(createSwapUsdtPair, "PairCreated", "pair", { id: "readSwapUSDTPairAddress" });
  const swapUsdtPair = m.contractAt("Pair", swapUsdtPairAddress, { id: "contractSwapUSDTPair" });

  m.call(swap, "approve", [swapUsdtPairAddress, "5000000000000000000000"], { id: "approveSwapUSDTPair" });
  m.call(usdt, "approve", [swapUsdtPairAddress, "100000000000000000000000"], { id: "approveUSDTSwapPair" });
  m.call(swapUsdtPair, "addLiquidity", [
    "5000000000000000000000", // 5000 SWAP
    "100000000000" // 100,000 USDT
  ], { id: "addLiquiditySwapUSDT" });

  const createSwapDaiPair = m.call(pairFactory, "createPair", [
    swap.address, dai.address
  ], { id: "createSwapDAIPair" });
  const swapDaiPairAddress = m.readEventArgument(createSwapDaiPair, "PairCreated", "pair", { id: "readSwapDAIPairAddress" });
  const swapDaiPair = m.contractAt("Pair", swapDaiPairAddress, { id: "contractSwapDAIPair" });

  m.call(swap, "approve", [swapDaiPairAddress, "100000000000000000000000"], { id: "approveSwapDAIPair" });
  m.call(dai, "approve", [swapDaiPairAddress, "5000000000000000000000"], { id: "approveDAISwapPair" });
  m.call(swapDaiPair, "addLiquidity", [
    "5000000000000000000000", // 5000 SWAP
    "100000000000000000000000" // 100,000 DAI
  ], { id: "addLiquiditySwapDAI" });

  // SYNTHETIC pairs ($2000 each)
  const createSyntheticUsdcPair = m.call(pairFactory, "createPair", [
    synthetic.address, usdc.address
  ], { id: "createSyntheticUSDCPair" });
  const syntheticUsdcPairAddress = m.readEventArgument(createSyntheticUsdcPair, "PairCreated", "pair", { id: "readSyntheticUSDCPairAddress" });
  const syntheticUsdcPair = m.contractAt("Pair", syntheticUsdcPairAddress, { id: "contractSyntheticUSDCPair" });

  m.call(synthetic, "approve", [syntheticUsdcPairAddress, "50000000000000000000"], { id: "approveSyntheticUSDCPair" });
  m.call(usdc, "approve", [syntheticUsdcPairAddress, "100000000000000000000000"], { id: "approveUSDCSyntheticPair" });
  m.call(syntheticUsdcPair, "addLiquidity", [
    "50000000000000000000", // 50 XAUT
    "100000000000" // 100,000 USDC
  ], { id: "addLiquiditySyntheticUSDC" });

  const createSyntheticUsdtPair = m.call(pairFactory, "createPair", [
    synthetic.address, usdt.address
  ], { id: "createSyntheticUSDTPair" });
  const syntheticUsdtPairAddress = m.readEventArgument(createSyntheticUsdtPair, "PairCreated", "pair", { id: "readSyntheticUSDTPairAddress" });
  const syntheticUsdtPair = m.contractAt("Pair", syntheticUsdtPairAddress, { id: "contractSyntheticUSDTPair" });

  m.call(synthetic, "approve", [syntheticUsdtPairAddress, "50000000000000000000"], { id: "approveSyntheticUSDTPair" });
  m.call(usdt, "approve", [syntheticUsdtPairAddress, "100000000000000000000000"], { id: "approveUSDTSyntheticPair" });
  m.call(syntheticUsdtPair, "addLiquidity", [
    "50000000000000000000", // 50 XAUT
    "100000000000" // 100,000 USDT
  ], { id: "addLiquiditySyntheticUSDT" });

  const createSyntheticDaiPair = m.call(pairFactory, "createPair", [
    synthetic.address, dai.address
  ], { id: "createSyntheticDAIPair" });
  const syntheticDaiPairAddress = m.readEventArgument(createSyntheticDaiPair, "PairCreated", "pair", { id: "readSyntheticDAIPairAddress" });
  const syntheticDaiPair = m.contractAt("Pair", syntheticDaiPairAddress, { id: "contractSyntheticDAIPair" });

  m.call(synthetic, "approve", [syntheticDaiPairAddress, "100000000000000000000000"], { id: "approveSyntheticDAIPair" });
  m.call(dai, "approve", [syntheticDaiPairAddress, "100000000000000000000000"], { id: "approveDAISyntheticPair" });
  m.call(syntheticDaiPair, "addLiquidity", [
    "50000000000000000000", // 50 XAUT
    "100000000000000000000000" // 100,000 DAI
  ], { id: "addLiquiditySyntheticDAI" });

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

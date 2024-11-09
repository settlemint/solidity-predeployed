import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { SaleFactoryModule } from './sale-factory';
import { TokensModule } from './tokens';

export const SalesModule = buildModule("SalesModule", (m) => {
  const { saleFactory } = m.useModule(SaleFactoryModule);
  const {
    usdc, usdt, dai,
    bond, option, future,
    swap, synthetic
  } = m.useModule(TokensModule);

  // USDT/USDC Sale - deposit 500k USDT
  const createUSDTSale = m.call(saleFactory, "createSale", [
    usdt.address,
    usdc.address,
    "1000000", // $1.00 (6 decimals)
  ], { id: "createUSDTSale" });
  const usdtSaleAddress = m.readEventArgument(createUSDTSale, "SaleCreated", "saleAddress", { id: "readUSDTSaleAddress" });
  const usdtSale = m.contractAt("Sale", usdtSaleAddress, { id: "contractUSDTSale" });
  m.call(usdt, "approve", [usdtSaleAddress, "500000000000"], { id: "approveUSDTSale" });
  m.call(usdtSale, "depositSaleTokens", ["500000000000"], { id: "depositUSDTSale" });

  // DAI/USDC Sale - deposit 500k DAI
  const createDAISale = m.call(saleFactory, "createSale", [
    dai.address,
    usdc.address,
    "1000000000000000000", // $1.00 (18 decimals)
  ], { id: "createDAISale" });
  const daiSaleAddress = m.readEventArgument(createDAISale, "SaleCreated", "saleAddress", { id: "readDAISaleAddress" });
  const daiSale = m.contractAt("Sale", daiSaleAddress, { id: "contractDAISale" });
  m.call(dai, "approve", [daiSaleAddress, "500000000000000000000000"], { id: "approveDAISale" });
  m.call(daiSale, "depositSaleTokens", ["500000000000000000000000"], { id: "depositDAISale" });

  // BOND/USDC Sale - deposit 50k BOND
  const createBondSale = m.call(saleFactory, "createSale", [
    bond.address,
    usdc.address,
    "100000000000000000000", // $100.00 (18 decimals)
  ], { id: "createBondSale" });
  const bondSaleAddress = m.readEventArgument(createBondSale, "SaleCreated", "saleAddress", { id: "readBondSaleAddress" });
  const bondSale = m.contractAt("Sale", bondSaleAddress, { id: "contractBondSale" });
  m.call(bond, "approve", [bondSaleAddress, "50000000000000000000000"], { id: "approveBondSale" });
  m.call(bondSale, "depositSaleTokens", ["50000000000000000000000"], { id: "depositBondSale" });

  // OPTION/USDC Sale - deposit 50k CALL
  const createOptionSale = m.call(saleFactory, "createSale", [
    option.address,
    usdc.address,
    "50000000000000000000", // $50.00 (18 decimals)
  ], { id: "createOptionSale" });
  const optionSaleAddress = m.readEventArgument(createOptionSale, "SaleCreated", "saleAddress", { id: "readOptionSaleAddress" });
  const optionSale = m.contractAt("Sale", optionSaleAddress, { id: "contractOptionSale" });
  m.call(option, "approve", [optionSaleAddress, "50000000000000000000000"], { id: "approveOptionSale" });
  m.call(optionSale, "depositSaleTokens", ["50000000000000000000000"], { id: "depositOptionSale" });

  // FUTURE/USDC Sale - deposit 5k BTCF
  const createFutureSale = m.call(saleFactory, "createSale", [
    future.address,
    usdc.address,
    "500000000000000000000", // $500.00 (18 decimals)
  ], { id: "createFutureSale" });
  const futureSaleAddress = m.readEventArgument(createFutureSale, "SaleCreated", "saleAddress", { id: "readFutureSaleAddress" });
  const futureSale = m.contractAt("Sale", futureSaleAddress, { id: "contractFutureSale" });
  m.call(future, "approve", [futureSaleAddress, "5000000000000000000000"], { id: "approveFutureSale" });
  m.call(futureSale, "depositSaleTokens", ["5000000000000000000000"], { id: "depositFutureSale" });

  // SWAP/USDC Sale - deposit 50k SWAP
  const createSwapSale = m.call(saleFactory, "createSale", [
    swap.address,
    usdc.address,
    "20000000000000000000", // $20.00 (18 decimals)
  ], { id: "createSwapSale" });
  const swapSaleAddress = m.readEventArgument(createSwapSale, "SaleCreated", "saleAddress", { id: "readSwapSaleAddress" });
  const swapSale = m.contractAt("Sale", swapSaleAddress, { id: "contractSwapSale" });
  m.call(swap, "approve", [swapSaleAddress, "100000000000000000000000"], { id: "approveSwapSale" });
  m.call(swapSale, "depositSaleTokens", ["50000000000000000000000"], { id: "depositSwapSale" });

  // XAUT/USDC Sale - deposit 25k XAUT
  const createSyntheticSale = m.call(saleFactory, "createSale", [
    synthetic.address,
    usdc.address,
    "2000000000000000000000", // $2000.00 (18 decimals)
  ], { id: "createSyntheticSale" });
  const syntheticSaleAddress = m.readEventArgument(createSyntheticSale, "SaleCreated", "saleAddress", { id: "readSyntheticSaleAddress" });
  const syntheticSale = m.contractAt("Sale", syntheticSaleAddress, { id: "contractSyntheticSale" });
  m.call(synthetic, "approve", [syntheticSaleAddress, "25000000000000000000000"], { id: "approveSyntheticSale" });
  m.call(syntheticSale, "depositSaleTokens", ["25000000000000000000000"], { id: "depositSyntheticSale" });

  return {
    usdtSale,
    daiSale,
    bondSale,
    optionSale,
    futureSale,
    swapSale,
    syntheticSale
  };
});

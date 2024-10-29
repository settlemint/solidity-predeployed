import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ContractsModule } from "./contracts";
import { TokenModule } from "./tokens";

export const DexModule = buildModule("DexModule", (m) => {
  const { dexFactory } = m.useModule(ContractsModule);
  const { token1, token2 } = m.useModule(TokenModule);

  const createPair = m.call(dexFactory, "createPair", [token1, token2], {
    id: "createDexPair"
  });

  const pairAddress = m.readEventArgument(createPair, "PairCreated", "pair", {
    id: "readPairAddress"
  });

  const pair = m.contractAt("StarterKitERC20Dex", pairAddress, {
    id: "contractPairInstance"
  });

  // Add liquidity
  const approveToken1 = m.call(token1, "approve", [pair, 100000000000000000000n], {
    id: "approveToken1ForLiquidity"
  });

  const approveToken2 = m.call(token2, "approve", [pair, 100000000000000000000n], {
    id: "approveToken2ForLiquidity"
  });

  const addLiquidity = m.call(pair, "addLiquidity", [
    100000000000000000000n,
    100000000000000000000n
  ], {
    id: "addInitialLiquidity",
    after: [approveToken1, approveToken2]
  });

  // Do a swap (only after liquidity is added)
  const approveSwap = m.call(token1, "approve", [pair, 10000000000000000000n], {
    id: "approveToken1ForSwap",
    after: [addLiquidity]
  });

  const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour from now

  const executeSwap = m.call(pair, "swapBaseToQuote", [
    3000000000000000000n,
    66666666666666667n,
    deadline
  ], {
    id: "executeSwap",
    after: [approveSwap]
  });

  // Remove liquidity (only after swap is complete)
  // m.call(pair, "removeLiquidity", [
  //   100000000000000000000n,
  //   90000000000000000000n,
  //   90000000000000000000n,
  //   deadline
  // ], {
  //   id: "removeLiquidity",
  //   after: [executeSwap]
  // });

  return { pair };
});

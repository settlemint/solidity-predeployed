import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { TokenFactoryModule } from './token-factory';

export const TokensModule = buildModule("TokensModule", (m) => {
  const { tokenFactory } = m.useModule(TokenFactoryModule);
  const deployer = m.getAccount(0);

  // USDC (18 decimals) - 1 million USDC
  const createUSDC = m.call(tokenFactory, "createToken",
    ["USD Coin", "USDC"],
    { id: "createUSDC" }
  );
  const usdcAddress = m.readEventArgument(createUSDC, "TokenCreated", "tokenAddress",
    { id: "readUSDCAddress" }
  );
  const usdc = m.contractAt("Token", usdcAddress, { id: "contractUSDC" });
  m.call(usdc, "mint", [deployer, "1000000000000000000000000000"], { id: "mintUSDC" });

  // USDT (18 decimals) - 1 million USDT
  const createUSDT = m.call(tokenFactory, "createToken",
    ["Tether USD", "USDT"],
    { id: "createUSDT" }
  );
  const usdtAddress = m.readEventArgument(createUSDT, "TokenCreated", "tokenAddress",
    { id: "readUSDTAddress" }
  );
  const usdt = m.contractAt("Token", usdtAddress, { id: "contractUSDT" });
  m.call(usdt, "mint", [deployer, "1000000000000000000000000000"], { id: "mintUSDT" });

  // DAI (18 decimals) - 1 million DAI
  const createDAI = m.call(tokenFactory, "createToken",
    ["Dai Stablecoin", "DAI"],
    { id: "createDAI" }
  );
  const daiAddress = m.readEventArgument(createDAI, "TokenCreated", "tokenAddress",
    { id: "readDAIAddress" }
  );
  const dai = m.contractAt("Token", daiAddress, { id: "contractDAI" });
  m.call(dai, "mint", [deployer, "1000000000000000000000000000"], { id: "mintDAI" });

  // BOND (18 decimals) - 100,000 BOND
  const createBond = m.call(tokenFactory, "createToken",
    ["Treasury Bond Token", "BOND"],
    { id: "createBond" }
  );
  const bondAddress = m.readEventArgument(createBond, "TokenCreated", "tokenAddress",
    { id: "readBondAddress" }
  );
  const bond = m.contractAt("Token", bondAddress, { id: "contractBond" });
  m.call(bond, "mint", [deployer, "1000000000000000000000000000"], { id: "mintBond" });

  // CALL (18 decimals) - 100,000 CALL
  const createOption = m.call(tokenFactory, "createToken",
    ["ETH Call Option", "CALL"],
    { id: "createOption" }
  );
  const optionAddress = m.readEventArgument(createOption, "TokenCreated", "tokenAddress",
    { id: "readOptionAddress" }
  );
  const option = m.contractAt("Token", optionAddress, { id: "contractOption" });
  m.call(option, "mint", [deployer, "1000000000000000000000000000"], { id: "mintOption" });

  // BTCF (18 decimals) - 10,000 BTCF
  const createFuture = m.call(tokenFactory, "createToken",
    ["BTC Future", "BTCF"],
    { id: "createFuture" }
  );
  const futureAddress = m.readEventArgument(createFuture, "TokenCreated", "tokenAddress",
    { id: "readFutureAddress" }
  );
  const future = m.contractAt("Token", futureAddress, { id: "contractFuture" });
  m.call(future, "mint", [deployer, "1000000000000000000000000000"], { id: "mintFuture" });

  // SWAP (18 decimals) - 100,000 SWAP
  const createSwap = m.call(tokenFactory, "createToken",
    ["Interest Rate Swap", "SWAP"],
    { id: "createSwap" }
  );
  const swapAddress = m.readEventArgument(createSwap, "TokenCreated", "tokenAddress",
    { id: "readSwapAddress" }
  );
  const swap = m.contractAt("Token", swapAddress, { id: "contractSwap" });
  m.call(swap, "mint", [deployer, "1000000000000000000000000000"], { id: "mintSwap" });

  // XAUT (18 decimals) - 50,000 XAUT
  const createSynthetic = m.call(tokenFactory, "createToken",
    ["Synthetic Gold", "XAUT"],
    { id: "createSynthetic" }
  );
  const syntheticAddress = m.readEventArgument(createSynthetic, "TokenCreated", "tokenAddress",
    { id: "readSyntheticAddress" }
  );
  const synthetic = m.contractAt("Token", syntheticAddress, { id: "contractSynthetic" });
  m.call(synthetic, "mint", [deployer, "50000000000000000000000000"], { id: "mintSynthetic" });

  // Get the test accounts (Anvil provides 10 by default, we'll use 1-9)
  const testAccounts = Array.from({ length: 9 }, (_, i) =>
    m.getAccount(i + 1) // Skip 0 as it's the deployer
  );

  const amounts = [
    "23456700000000000000000000", // 23.4M USDC
    "45678900000000000000000000", // 45.6M USDC
    "12345600000000000000000000", // 12.3M USDC
    "34567800000000000000000000", // 34.5M USDC
    "43210900000000000000000000", // 43.2M USDC
    "32109800000000000000000000", // 32.1M USDC
    "21098700000000000000000000", // 21.0M USDC
    "19876500000000000000000000", // 19.8M USDC
    "44556600000000000000000000", // 44.5M USDC
  ];

  testAccounts.forEach((address, i) => {
    m.call(usdc, "mint", [address, amounts[i]],
      { id: `mintUSDC${i + 1}` }
    );
  });

  return { usdc, usdt, dai, bond, option, future, swap, synthetic };
});

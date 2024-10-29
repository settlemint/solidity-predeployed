import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ContractsModule } from "./contracts";

export const TokenModule = buildModule("TokenModule", (m) => {
  const { factory } = m.useModule(ContractsModule);

  const create = m.call(factory, "createToken",
    ["Example Token", "EXT", "This is an example token"],
    { id: "createExampleToken1" }
  );
  const tokenAddress = m.readEventArgument(create, "TokenCreated", "tokenAddress",
    { id: "readToken1Address" }
  );
  const token1 = m.contractAt("StarterKitERC20", tokenAddress,
    { id: "contractToken1Instance" }
  );

  const create2 = m.call(factory, "createToken",
    ["Example Token 2", "EXT2", "This is an example token 2"],
    { id: "createExampleToken2" }
  );
  const tokenAddress2 = m.readEventArgument(create2, "TokenCreated", "tokenAddress",
    { id: "readToken2Address" }
  );
  const token2 = m.contractAt("StarterKitERC20", tokenAddress2,
    { id: "contractToken2Instance" }
  );

  m.call(token1, "mint", ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 1000000000000000000000n]); // 1000
  m.call(token1, "transfer", ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8", 5000000000000000000n]); // 5

  m.call(token2, "mint", ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 1000000000000000000000n]); // 1000
  m.call(token2, "transfer", ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8", 5000000000000000000n]); // 5

  return { token1, token2 };
});

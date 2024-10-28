import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const StarterKitModule = buildModule("StarterKitModule", (m) => {
  const registry = m.contract("StarterKitERC20Registry");
  const factory = m.contract("StarterKitERC20Factory", [registry]);

  const saleRegistry = m.contract("StarterKitERC20SaleRegistry");
  const saleFactory = m.contract("StarterKitERC20SaleFactory", [saleRegistry]);

  return { registry, factory, saleRegistry, saleFactory };
});

const SeedModule = buildModule("SeedModule", (m) => {
  const { registry, factory, saleRegistry, saleFactory } = m.useModule(StarterKitModule);

  const create = m.call(factory, "createToken",
    ["Example Token", "EXT", "This is an example token"],
    { id: "createExampleToken1" }
  );
  const tokenAddress = m.readEventArgument(create, "TokenCreated", "tokenAddress",
    { id: "readToken1Address" }
  );
  const existingToken = m.contractAt("StarterKitERC20", tokenAddress,
    { id: "contractToken1Instance" }
  );

  const create2 = m.call(factory, "createToken",
    ["Example Token 2", "EXT2", "This is an example token 2"],
    { id: "createExampleToken2" }
  );
  const tokenAddress2 = m.readEventArgument(create2, "TokenCreated", "tokenAddress",
    { id: "readToken2Address" }
  );
  const existingToken2 = m.contractAt("StarterKitERC20", tokenAddress2,
    { id: "contractToken2Instance" }
  );

  m.call(existingToken, "mint", ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 100000000000000000000n]);
  m.call(existingToken, "transfer", ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8", 25000000000000000000n]);

  m.call(existingToken2, "mint", ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 100000000000000000000n]);
  m.call(existingToken2, "transfer", ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8", 25000000000000000000n]);


  const createSale = m.call(saleFactory, "createSale", [tokenAddress, tokenAddress2, 25000000000000000000n, 0, 0 ]);
  const saleAddress = m.readEventArgument(createSale, "SaleCreated", "saleAddress");
  const sale = m.contractAt("StarterKitERC20Sale", saleAddress);

  m.call(existingToken, "approve", [saleAddress, 35000000000000000000n]);
  m.call(sale, "deposit", [35000000000000000000n]);

  m.call(existingToken2, "approve", [saleAddress, 50000000000000000000n]);
  m.call(sale, "buy", [15000000000000000000n]);

  return { registry, factory, saleRegistry, saleFactory, sale };
});

export default SeedModule;

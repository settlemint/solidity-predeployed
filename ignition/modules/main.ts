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

  // Create a new token using the factory
  const create = m.call(factory, "createToken", ["Example Token", "EXT", "This is an example token"]);
  const tokenAddress = m.readEventArgument(create, "TokenCreated", "tokenAddress");

  const existingToken = m.contractAt("StarterKitERC20", tokenAddress);

  m.call(existingToken, "mint", ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 100000000000000000000n]);

  const createSale = m.call(saleFactory, "createSale", [tokenAddress, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 1000000000000000000000000n, 0, 0 ]);

  return { registry, factory, saleRegistry, saleFactory };
});

export default SeedModule;

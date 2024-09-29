import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const StarterKitModule = buildModule("StarterKitModule", (m) => {
  const registry = m.contract("StarterKitERC20Registry");
  const factory = m.contract("StarterKitERC20Factory", [registry]);

  return { registry,factory };
});

const SeedModule = buildModule("SeedModule", (m) => {
  const { registry, factory } = m.useModule(StarterKitModule);

  // Create a new token using the factory
  const create = m.call(factory, "createToken", ["Example Token", "EXT", "This is an example token"]);
  const tokenAddress = m.readEventArgument(create, "TokenCreated", "tokenAddress");

  const existingToken = m.contractAt("StarterKitERC20", tokenAddress);

  m.call(existingToken, "mint", ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 100000000000000000000n]);

  return { registry, factory };
});

export default SeedModule;

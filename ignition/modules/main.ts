import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const StarterKitModule = buildModule("StarterKitModule", (m) => {
  const registry = m.contract("StarterKitERC20Registry");
  const factory = m.contract("StarterKitERC20Factory", [registry]);

  return { registry,factory };
});

const SeedModule = buildModule("SeedModule", (m) => {
  const { registry, factory } = m.useModule(StarterKitModule);

  // Create a new token using the factory
  m.call(factory, "createToken", ["Example Token", "EXT", "This is an example token"]);


  return { registry, factory };
});

export default SeedModule;

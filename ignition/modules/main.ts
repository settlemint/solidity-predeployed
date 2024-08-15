import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const SettleMintERC20Module = buildModule("SettleMintERC20Module", (m) => {
  const counter = m.contract("SettleMintERC20");

  return { counter };
});

export default SettleMintERC20Module;

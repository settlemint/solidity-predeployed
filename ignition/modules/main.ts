import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const SettleMintERC20Module = buildModule("SettleMintERC20Module", (m) => {
  const erc20 = m.contract("SettleMintERC20");
  const erc1155 = m.contract("SettleMintERC1155");

  return { erc20,erc1155 };
});

export default SettleMintERC20Module;

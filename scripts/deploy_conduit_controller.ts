import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // 获取当前 nonce
  const nonce = await deployer.getTransactionCount();
  console.log("Current nonce:", nonce);

  // 获取合约工厂
  const ConduitController = await ethers.getContractFactory("ConduitController");

  // 部署合约并手动指定 nonce、gasPrice、gasLimit
  const contract = await ConduitController.deploy({
    nonce: nonce,  // 指定 nonce
    gasPrice: ethers.utils.parseUnits('20', 'gwei'),
    gasLimit: 50000000  // 设置 gasLimit
  });

  console.log("Contract deployed to:", contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
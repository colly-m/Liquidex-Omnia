import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("Deploying LiquidityManager with account:", deployer.address);
  console.log("Account balance:", (await ethers.getBalance(deployer.address)).toString());

  const LiquidityManager = await ethers.getContractFactory("LiquidityManager");
  
  // Platform contract address - replace with actual address
  const platformAddress = "0x0000000000000000000000000000000000000000";
  
  const liquidityManager = await LiquidityManager.deploy(platformAddress);
  
  await liquidityManager.waitForDeployment();
  
  console.log("LiquidityManager deployed to:", await liquidityManager.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
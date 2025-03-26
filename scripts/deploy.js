// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
const hre = require("hardhat");

async function main() {
  console.log("Deploying IPNFTRegistryWithFees contract to Polygon Amoy testnet...");

  // Get the contract factory
  const IPNFTRegistryWithFees = await hre.ethers.getContractFactory("IPNFTRegistryWithFees");
  
  // Deploy the contract
  const ipnftRegistry = await IPNFTRegistryWithFees.deploy();

  // Wait for the contract to be deployed
  await ipnftRegistry.waitForDeployment();
  
  // Get the contract address
  const address = await ipnftRegistry.getAddress();
  
  console.log(`IPNFTRegistryWithFees deployed to: ${address}`);
  console.log("Update your .env file with this contract address");
  
  // Set the fee percentages (3% for mint and transfer)
  console.log("Setting fee percentages...");
  await ipnftRegistry.setMintFeePercentage(300);
  await ipnftRegistry.setTransferFeePercentage(300);
  console.log("Fee percentages set to 3%");
  
  // Display information about verifying the contract
  console.log("\nTo verify the contract on the block explorer:");
  console.log(`npx hardhat verify --network amoy ${address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

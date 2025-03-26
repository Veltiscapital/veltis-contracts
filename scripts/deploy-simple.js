// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
const hre = require("hardhat");

async function main() {
  console.log("Deploying SimpleIPNFTRegistry contract to Polygon Amoy testnet...");

  // Get the contract factory
  const SimpleIPNFTRegistry = await hre.ethers.getContractFactory("SimpleIPNFTRegistry");
  
  // Deploy the contract
  const registry = await SimpleIPNFTRegistry.deploy();
  
  // Wait for deployment
  await registry.waitForDeployment();
  
  // Get the contract address
  const address = await registry.getAddress();
  
  console.log(`SimpleIPNFTRegistry deployed to: ${address}`);
  console.log("Update your .env file with this contract address");
  
  // Set the mint fee percentage (3%)
  console.log("Setting mint fee percentage...");
  await registry.setMintFeePercentage(300);
  console.log("Mint fee percentage set to 3%");
  
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

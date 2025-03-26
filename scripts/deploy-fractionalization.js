// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
const hre = require("hardhat");

async function main() {
  console.log("Deploying IPNFTFractionalizationFactory contract to Polygon Amoy testnet...");

  // Get the contract factory
  const IPNFTFractionalizationFactory = await hre.ethers.getContractFactory("IPNFTFractionalizationFactory");
  
  // Get the deployer address to use as fee collector
  const [deployer] = await hre.ethers.getSigners();
  
  // Deploy the contract with the deployer as fee collector
  const factory = await IPNFTFractionalizationFactory.deploy(deployer.address);
  
  // Wait for deployment
  await factory.waitForDeployment();
  
  // Get the contract address
  const address = await factory.getAddress();
  
  console.log(`IPNFTFractionalizationFactory deployed to: ${address}`);
  console.log("Update your .env file with this contract address");
  
  // Set the creation fee percentage (3%)
  console.log("Setting creation fee percentage...");
  await factory.setCreationFeePercentage(300);
  console.log("Creation fee percentage set to 3%");
  
  // Display information about verifying the contract
  console.log("\nTo verify the contract on the block explorer:");
  console.log(`npx hardhat verify --network amoy ${address} ${deployer.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY || "mJNGWubj_qQYGnXn1mFLcHhiyBftWps7";
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0000000000000000000000000000000000000000000000000000000000000000";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    amoy: {
      url: `https://polygon-amoy.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: [PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: {
      polygonAmoy: process.env.POLYGONSCAN_API_KEY || ""
    },
    customChains: [
      {
        network: "amoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://www.oklink.com/amoy"
        }
      }
    ]
  }
};

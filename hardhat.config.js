// import plugins
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");


// import secrets
const { mnemonic } = require('./secrets.json');


/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {  
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 10000
          }
        }
      }, 
    ]
  },
  networks: {
    hardhat: {
      accounts: {mnemonic: mnemonic},
      network_id: 31337
    },
    eth_mainnet: {
      url: "https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161", //<---- YOUR INFURA ID! (or it won't work)
      accounts: {
        mnemonic: mnemonic,
      },
    },
    rinkeby: {
      url: "https://rinkeby-light.eth.linkpool.io", //<---- YOUR INFURA ID! (or it won't work)
      accounts: {
        mnemonic: mnemonic,
      },
      network_id: 4,
    },
  },
  paths: {
    tests: "./tests",
  },
  etherscan: {
    // Your API key for Etherscan/BSCscan/Polygonscan
    apiKey: ""
  },
};


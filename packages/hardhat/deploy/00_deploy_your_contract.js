// deploy/00_deploy_your_contract.js

const { ethers } = require("hardhat");

const localChainId = "31337";

const sleep = (ms) =>
  new Promise((r) =>
    setTimeout(() => {
      // console.log(`waited for ${(ms / 1000).toFixed(3)} seconds`);
      r();
    }, ms)
  );

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  const NFcharTContract = ethers.getContractFactory("NFcharT");

  const wethAddress = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
  const usdtAddress = "0xdac17f958d2ee523a2206206994597c13d831ec7"

  // create test accounts
  const accounts = await ethers.provider.listAccounts();
  const signers = await ethers.getSigners();
  const owner = accounts[0];

  const NFcharT = await (await NFcharTContract).deploy("test", "TEST");

  await NFcharT.pause(false);

  // Verify your contracts with Etherscan
  // You don't want to verify on localhost
  if (chainId !== localChainId) {
    // wait for etherscan to be ready to verify
    await sleep(15000);
    await run("verify:verify", {
      address: NFcharT.address,
      contract: "contracts/NFcharT.sol:NFcharT",
      contractArguments: [],
    });
  }
};
module.exports.tags = ["NFcharT"];

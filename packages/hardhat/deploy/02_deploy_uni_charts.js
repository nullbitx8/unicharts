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

  const deployResult = await deploy("UniCharts", {
    from: deployer,
    args: [
      "UniCharts",
      "CHARTS",
      deployer.address,
      deployer.address
    ],
    dependencies: ["V3Oracle", "DatetimeLib"]
  });


  // Verify your contracts with Etherscan
  // You don't want to verify on localhost
  if (chainId !== localChainId) {
    // wait for etherscan to be ready to verify
    await sleep(15000);
    await run("verify:verify", {
      address: NFcharT.address,
      contract: "contracts/UniChwarts.sol:UniCharts",
      contractArguments: [],
    });
  }
};
module.exports.tags = ["UniCharts"];

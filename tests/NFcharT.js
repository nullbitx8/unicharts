/*
 * Test module for the NFcharT.sol contract.
 */
const { expect } = require("chai");
const { ethers } = require("hardhat");

// imports
const NFcharTContract = ethers.getContractFactory("NFcharT");

const wethAddress = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
const usdtAddress = "0xdac17f958d2ee523a2206206994597c13d831ec7"

describe("NFcharT", () => {
  // test accounts
  let accounts;
  let owner;
  let signers;

  // contract under test
  let deployedNFcharT;

  // tokens for test
  let weth;
  let usdt;

  /* 
   * Runs once before all tests.
   */
  before(async () => {
    // create test accounts
    accounts = await ethers.provider.listAccounts();
    signers = await ethers.getSigners();
    owner = accounts[0];

    weth = await (await NFcharTContract).deploy("weth", "weth");
    usdt = await (await NFcharTContract).deploy("usdt", "usdt");
  });

  /* 
   * Runs once before each test.
   */
  beforeEach(async () => {
    // create nft contract
    deployedNFcharT =  await (await NFcharTContract).deploy("test", "test1");
  });



  describe("Metadata", () => {
    // TODO: test passing bad input to userMint function
    it("should return a JSON blob with correct shape encoded as base64 from tokenURI method", async () => {
      // First unpause minting
      await deployedNFcharT.pause(false);
      // Then call returnPairKey and assert it matches concat of both addresses
      const tokenPair = await deployedNFcharT.returnPairKey(wethAddress, usdtAddress);
      expect(tokenPair).to.equal(wethAddress + usdtAddress.slice(2));
      // Then mint a new token pair
      await deployedNFcharT.userMint(weth.address, usdt.address);
      // Then call tokenURI method
      const token0 = await deployedNFcharT.tokenOfOwnerByIndex(accounts[0], 0);
      const metadata = await deployedNFcharT.tokenURI(token0);
      expect(metadata).to.equal({});
    });
  });

});

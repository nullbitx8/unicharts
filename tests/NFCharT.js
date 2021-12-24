/*
 * Test module for the MyCollection.sol contract.
 */

// third party imports
const assert = require("chai").assert;

// our imports

// constants
const zeroAddress = "0x0000000000000000000000000000000000000000"
const deadAddress = "0x000000000000000000000000000000000000dEaD"


describe("Charteez", function() { 
  // test accounts
  let accounts;
  let signers;

  // contract under test
  let contract;
  let contractUser1;

  // contract initialization values
  let name;
  let symbol;
  let uniV3Oracle;
  let ethDT;


  /* 
   * Runs once before all tests.
   */
  before(async function() {
    // retrieve test accounts
    accounts = await ethers.provider.listAccounts();
    signers = await ethers.getSigners();

    // contract initialization values
    name = "Chart NFT";
    symbol = "CHARTS";
    uniV3Oracle = "0x0000000000000000000000000000000000000000";

    // deploy DateTime library contract
    const DateTime = await ethers.getContractFactory("DateTime");
    ethDT = await DateTime.deploy();

    // set hardhat time to now
    await ethers.provider.send("evm_setNextBlockTimestamp", [Date.now()/1000]);
    await ethers.provider.send("evm_mine");
  });

  /* 
   * Runs once before each test.
   */
  beforeEach(async function() {
    // create UniChartz contract
    const Charts = await ethers.getContractFactory("NFcharT");
    // signer is contract owner (signers[0])
    contract = await Charts.deploy(
        name,
        symbol,
        uniV3Oracle,
        ethDT.address
    );

    // signer is user1 (signers[1])
    contractUser1 = await ethers.getContractAt("NFcharT", contract.address, signers[1]);
  });

  describe("Deployment", function() {
    it("should deploy with the correct values", async function() {
      var res = await contract.owner();
      assert.equal(res, accounts[0]);

      // TODO add more
    });
  });

  describe("Minting", function() {
  });

  describe("SVG Data", function() {
    it("should return a string of the full SVG", async function() {
        var svg = await contract.buildSVG(
            "BTC",
            "DAI",
            [0,80,150,100,300,200,350]
        ); 

        assert.equal(svg, "");
    });
  });
});

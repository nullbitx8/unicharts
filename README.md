# NFcharT

## About

NFcharT (unicharts) is a fully on-chain, generative art NFT project!
Users can mint their own charts, then view them on marketplaces like OpenSea.  

The price data for a chart is retrieved from Uniswap's on-chain price oracle!
The image data for a chart is created using SVG and the price data from the oracle!

Users can choose to display their NFT as a weekly chart or an hourly chart based on their preference.

The charts will be free to mint, with secondary sales royalties going to the contributors of the project!

We are currently looking for:
 * a designer that can create a uniswap-y feel to the existing charts
 * a designer to create a mint page concept


## Development
1. Run `yarn install` in root
1. Run `yarn chain` in one terminal
1. Run `yarn deploy` in a second terminal. Then run `yarn start` to spin up web app


### deploying to local
1. in console run `var Collection = await ethers.getContractFactory("MyCollection")` where MyCollection is contract name
1. `var contract = await Collection.deploy('NFcharT', 'NFTCHART', '', ...)` passing in constructor params... deployer is acct 0, team address is diff acct (nb address are a string)


Note that `ethers` is essentially a client that mimics Web3js interactions

### testing access control
1. can set baseURI as owner by running `var res = await contract.setBaseURI('youtube.com')`
1. to interact with contract as a different user to test access control
    1. get list of signers (addresses generated in terminal) -> `var signers = await ethers.getSigners()`
    1. get copy instance of contract -> `var contractAsUser1 = await ethers.getContractAt('MyCollection', contract.address, signers[1])`
    1. try to set baseURI and observe permission denied/reversion error -> `var res = await contractAsUser1.setBaseURI('youtube.com')`

### minting nft
Note that any user can mint
1. First need to unPause sale (can only update state via api that contract exposed) -> `await contract.pause(false)`
1. Can check with `await contract.paused()` because getter is auto-generated for state vars
1. Then mint 10 `var res = await contractAsUser1.userMint(10, {value: ethers.utils.parseEther("0.6")})` -- note that `value` is in wei so parse to avoid manual conversion
1. Now can use method in src to check tokens owned by a address -> `await contract.assetsOfAddress(signers[1].address)`

### exploring minted nft
1. To see the baseURI we set on the first item -> `var metadata = await contract.tokenURI(0)`

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

// Source: https://andrecronje.medium.com/easy-on-chain-oracles-54d82961a2a0
interface v3oracle {
    function assetToAsset(address, uint, address, uint) external view returns (uint);
}

contract NFcharT is ERC721Enumerable, Ownable, ReentrancyGuard {
    // libraries
    using Strings for uint256;

    v3oracle constant oracle = v3oracle(0x0F1f5A87f99f0918e6C81F16E59F3518698221Ff);
    
    // state vars
    bool public paused = true;
    uint private lookBackWindow = 1; // in days... TODO: is this the place to put it for customizable by each user
    mapping(bytes => bool) public tokenPairExistenceMapping; // the key is a concatenation of token0 and token1
    mapping(uint256 => address[]) internal tokenIdToTokenPairMapping; // the key is tokenId and value is array of addresses for two tokens being tracked

    // constructor
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    /**
     * @dev Allows a user to mint an NFT by paying for it.
     * Transfers the minting cost to the team and the service provider.
     */
    function userMint(address token0, address token1) public payable nonReentrant {
        require(!paused, 'Sale paused');
        require(token0 != token1, 'What are you doing comparing the same token?');
        bytes memory concatted = returnPairKey(token0, token1);
        require(
            tokenPairExistenceMapping[concatted] != true,
            'This token pair already exists. Consider trading for it on OpenSea'
        );
        tokenPairExistenceMapping[concatted] = true;

        uint256 tokenId = totalSupply(); // the next token's tokenId == totalSupply
        tokenIdToTokenPairMapping[tokenId] = [token0, token1];
        _safeMint(msg.sender, tokenId);
    }

    /**
     * @dev Allows a user to mint an NFT by paying for it.
     * Transfers the minting cost to the team and the service provider.
     */
    function returnPairKey(address token0, address token1) public pure returns (bytes memory) {
        return abi.encodePacked(token0, token1);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     * Returns a base64 encoded JSON blob of metadata.
     * Includes the key 'image_data' that is supported by OpenSea
     * for displaying raw SVG data.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        // fetch two tokens being compared by tokenId key
        address[] memory tokens = tokenIdToTokenPairMapping[tokenId];
        // TODO: get TWAP period from web client? 
        // now query Uniswap Oracle for Price Data (https://andrecronje.medium.com/easy-on-chain-oracles-54d82961a2a0)
        // TODO: need a loop to get these over different interval
        // eg - to get over 24 hours period, need to query for 30 mins, then 60 mins, then 90, then ... up to 24 hrs
        // and return all values as an array to plot

        uint _twip = oracle.assetToAsset(tokens[0], 1e18, tokens[1], 3600); // over the last 30 mins?
        if (_twip == 0){
            // TODO: remove me. this is dummy logic to get the compiler to not complain about unused variable
        }

        // TODO
        // Create JSON template
        // Create SVG Template
            // Query Uniswap Oracle for Price Data
        // base64 encode the JSON blob
        // return encoded JSON
        return "";
    }

    /**
     * @dev Pauses the public NFT minting.
     */
    function pause(bool val) public onlyOwner {
        paused = val;
    }

    /**
     * @dev Sends the ETH balance in the contract to the contract owner.
     */
    function withdrawAll() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

}

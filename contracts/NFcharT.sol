// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

contract NFcharT is ERC721Enumerable, Ownable, ReentrancyGuard {

    // libraries
    using Strings for uint256;

    // state vars
    bool public paused = true;
    mapping(bytes => bytes1) public pairMapping;  // the key is a concatenation of token0 and token1

    // constructor
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
    }


    /**
     * @dev Allows a user to mint an NFT by paying for it.
     * Transfers the minting cost to the team and the service provider.
     */
    function userMint(address token0, address token1) public payable nonReentrant {
        require(!paused, "Sale paused");
        require(token0 != token1, "What are you doing comparing the same token?");
        bytes memory concatted = abi.encodePacked(token0, token1);
        require(pairMapping[concatted] != 0x01, "This token pair already exists. Consider trading for it on OpenSea");
        pairMapping[concatted] = 0x01;

        uint256 supply = totalSupply();
        _safeMint(msg.sender, supply);
    }

    /**
     * @dev Allows a user to mint an NFT by paying for it.
     * Transfers the minting cost to the team and the service provider.
     */
    function returnPairKey(address token0, address token1) public pure returns (bytes memory) {
        return abi.encodePacked(token0, token1);
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

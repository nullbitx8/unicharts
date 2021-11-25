// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

contract MyCollection is ERC721Enumerable, Ownable, ReentrancyGuard {
    // libraries
    using Strings for uint256;

    // state vars
    string internal _baseTokenURI;
    uint256 public maxSupply = 10000;
    uint256 public maxMintTx = 20;
    uint256 public reserved = 100;
    uint256 public price = 0.06 ether;
    bool public paused = true;

    // withdraw addresses
    address public teamAddr;
    address public providerAddr;

    // withdraw percentages
    uint256 public teamPct;
    uint256 public providerPct;

    // events
    event baseUriSet(string URI);
    event nftMinted(uint256 nftId);

    // constructor
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        address _teamAddr,
        uint256 _teamPct,
        address _providerAddr,
        uint256 _providerPct
    ) ERC721(_name, _symbol) {
        setBaseURI(_baseUri);
        teamAddr = _teamAddr;
        teamPct = _teamPct;
        providerAddr = _providerAddr;
        providerPct = _providerPct;
    }

    /**
     * @dev Returns the base URI of the NFT collection.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Sets the base URI of the NFT collection.
     * Setting the URI is logged.
     */
    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
        emit baseUriSet(baseURI);
    }

    /**
     * @dev Sets the base URI of the NFT collection.
     * Setting the URI is logged.
     */
    function getBaseURI() public view returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Allows a user to mint an NFT by paying for it.
     * Transfers the minting cost to the team and the service provider.
     */
    function userMint(uint256 num) public payable nonReentrant {
        uint256 supply = totalSupply();
        require(!paused, 'Sale paused');
        require(num > 0 && num <= maxMintTx, 'Cant mint more than maxMintTx');
        require(supply + num <= maxSupply - reserved, 'Exceeds maximum NFT supply');
        require(msg.value >= price * num, 'Ether sent is not correct');
        require(
            payable(providerAddr).send((msg.value * providerPct) / 100),
            'Could not send provider'
        );
        require(payable(teamAddr).send((msg.value * teamPct) / 100), 'Could not send team');

        for (uint256 i; i < num; i++) {
            _safeMint(msg.sender, supply + i);
        }

        emit nftMinted(num);
    }

    /**
     * @dev Returns all the tokens owned by the given address.
     */
    function assetsOfAddress(address _address) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_address);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_address, i);
        }
        return tokensId;
    }

    /**
     * @dev Sets the cost of minting an NFT.
     */
    function setPrice(uint256 _newPrice) public onlyOwner {
        price = _newPrice;
    }

    /**
     * @dev Returns the cost of minting an NFT.
     */
    function getPrice() public view returns (uint256) {
        return price;
    }

    /**
     * @dev Mints the given _amount of reserved NFTs to the _to address.
     * Only costs gas to mint.
     */
    function giveAway(address _to, uint256 _amount) external onlyOwner {
        require(_amount <= reserved, 'Exceeds reserved NFT supply');

        uint256 supply = totalSupply();
        for (uint256 i; i < _amount; i++) {
            _safeMint(_to, supply + i);
        }

        reserved -= _amount;
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

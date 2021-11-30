// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import 'contracts/Base64.sol';

// Source: https://andrecronje.medium.com/easy-on-chain-oracles-54d82961a2a0
interface v3oracle {
    function assetToAsset(
        address,
        uint256,
        address,
        uint256
    ) external view returns (uint256);
}

interface IERC20 {
    function symbol() external view returns (string memory);
}

contract NFcharT is ERC721Enumerable, Ownable, ReentrancyGuard {
    // libraries
    using Strings for uint256;

    v3oracle constant oracle = v3oracle(0x0F1f5A87f99f0918e6C81F16E59F3518698221Ff);

    // state vars
    bool public paused = true;
    uint256 hour = 3600;
    mapping(bytes => bool) public tokenPairExistenceMapping; // the key is a concatenation of token0 and token1
    mapping(uint256 => address[]) internal tokenIdToTokenPairMapping; // the key is tokenId and value is array of addresses for two tokens being tracked
    // TODO: create a method to set lookBackWindowForToken by client
    mapping(uint256 => uint256) internal lookBackWindowForToken; // key is tokenId and value is lookback window (in days) set for that token

    // TODO: can add a mapping of tokenId to array of plugins
    // then tokenURI method can iterate through plugins when building svg and the json metadata
    // also needs getters/setters

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

    /*
     * TODO: fill me out
     */
    function buildSVG(
        string memory symbol0,
        string memory symbol1,
        uint256[] memory twips,
        uint256 tokenId
    ) internal view returns (string memory) {
        // tokenId can beused to determine if 24hr or 7 day
        // can fetch lookback period by taking length of twips array

        //  take the first case of 24 hour chart
        // we have 6 points of 4 hours each
        // 4 hours = 60 * 60 * 4  seconds
        // so we would have a mapping of
        //    4 hours => price
        //    8 hours => price
        //    12 hours => price
        //    16
        //    20
        //    24
        //
        // take the second case of 7 day chart
        //  we have 7 piontns of 1 day (24 hours) each
        // so we would have a mapping of
        //    1 day  => price
        //    2 days => price
        //    3 days => price
        //    4 days => price
        //    5 days => price
        //    6 days => price
        //    7 days => price

        return '';
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

        // example of getting symbol
        string memory symbol0 = IERC20(tokens[0]).symbol();
        string memory symbol1 = IERC20(tokens[1]).symbol();
        // TODO: check if this encoding method works as expected
        string memory pairName = string(abi.encodePacked('"', symbol0, '/', symbol1, '"'));

        uint256 twipCountToFetch = lookBackWindowForToken[tokenId] * 48; // 48 comes from assuming 3600 is for 30 mins as docs say. and there are 48 periods of 30 mins in one day
        uint256[] memory twips = new uint256[](twipCountToFetch);
        // TODO: should be a map of seconds (uint256) to prices (unit256)
        for (uint256 i = 0; i < twipCountToFetch; i++) {
            uint256 currentLookbackWindow = (i + 1) * 3600; // recall i is 0 indexed
            // https://andrecronje.medium.com/easy-on-chain-oracles-54d82961a2a0
            uint256 twip = oracle.assetToAsset(tokens[0], 1e18, tokens[1], currentLookbackWindow);
            twips[i] = twip;
        }

        string memory svg = buildSVG(symbol0, symbol1, twips, tokenId);

        // TODO: test this json creation method
        // separating strings into small chunks to not exceed 32 bit limit
        string memory blob = string(
            abi.encodeWithSelector(
                '{"',
                'description"',
                ': "NFcharT", "name": ',
                pairName,
                ', "image_data":',
                svg,
                '}'
            )
        );
        return Base64.encode(bytes(blob));
    }

    /**
     * @dev Pauses the public NFT minting.
     */
    function pause(bool val) public onlyOwner {
        paused = val;
    }

    /**
     * @dev Sets lookback window for tokenId
     */
    function setLookbackWindow(uint256 tokenId, uint256 dayCount) external {
        // TODO: write an enum instead of an int
        lookBackWindowForToken[tokenId] = dayCount;
    }

    /**
     * @dev Gets lookback window for tokenId
     */
    function getLookbackWindow(uint256 tokenId) public view returns (uint256) {
        return lookBackWindowForToken[tokenId];
    }

    /**
     * @dev Sends the ETH balance in the contract to the contract owner.
     */
    function withdrawAll() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}

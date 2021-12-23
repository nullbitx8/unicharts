// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

// Source: https://andrecronje.medium.com/easy-on-chain-oracles-54d82961a2a0
interface v3oracle {
    function assetToAsset(
        address,
        uint256,
        address,
        uint256
    ) external view returns (uint256);
}

// Source https://github.com/pipermerriam/ethereum-datetime
interface datetime {
    function getHour(uint timestamp) external view returns (uint16);
    function getDay(uint timestamp) external view returns (uint16);
}

interface IERC20 {
    function symbol() external view returns (string memory);
}

contract NFcharT is ERC721Enumerable, Ownable, ReentrancyGuard {
    // libraries
    using Strings for uint256;

    v3oracle public oracle;
    datetime public ethDT;

    // state vars
    bool public paused = true;
    mapping(bytes => bool) public tokenPairExistenceMapping; // the key is a concatenation of token0 and token1
    mapping(uint256 => address[]) internal tokenIdToTokenPairMapping; // the key is tokenId and value is array of addresses for two tokens being tracked
    // TODO: create a method to set lookBackWindowForToken by client
    mapping(uint256 => uint256) internal lookBackWindowForToken; // key is tokenId and value is lookback window (in days) set for that token
    // TODO: can add a mapping of tokenId to array of plugins
    // then tokenURI method can iterate through plugins when building svg and the json metadata
    // also needs getters/setters

    // constructor
    constructor(string memory _name, string memory _symbol, address _oracle, address _ethDT) ERC721(_name, _symbol) {
        oracle = v3oracle(_oracle);
        ethDT = datetime(_ethDT); 
    }

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
    * @dev Returns a string of SVG data representing the price chart.
    */
    function buildSVG(string memory symbol0, string memory symbol1, uint256[] memory twips) external view returns (bytes memory) {
        // our graph is 350x350
        // there are 50px of padding in all directions
        // which allow us to label the axes, and title the chart
        // then the lines and points are drawn in a 250x250 square

        // there are two possible charts
        // 1. Daily chart (6 points of 4 hours)
        // 2. Weekly chart (7 points of 1 day)

        // determine if the chart is a 1 day chart or 7 day chart
        bool isWeekChart = twips.length == 7;

        // calculate different variables based on whether the
        // chart is a daily chart or a weekly chart
        uint16 xInterval;
        string memory xAxisLabel;

        if (isWeekChart == true) {
            xInterval = 50;  // 50 pixels between points
            xAxisLabel = "Day (UTC)";
        }
        else {
            xInterval = 40;  // 40 pixels between points
            xAxisLabel = "Hour (UTC)";
        }

        // generate the SVG for our chart 
        bytes memory toReturn = abi.encode(
            '<svg width="350" height="350" xmlns="http://www.w3.org/2000/svg"',
            ' xmlns:xlink="http://www.w3.org/1999/xlink">',
            
            // chart title
            '<text x="150" y="50" font-size="18">',
            '<set attributeName="visibility" from="visible" to="hidden" begin="0s" dur="1s" />',
            symbol0,
            '/',
            symbol1,
            '</text>',

            // create / label the X axis
            '<line x1="50" x2="50" y1="50" y2="300" stroke="black" stroke-width="5">',
		    '<animate attributeName="y2" from="50" to="300" begin="0s" dur="1s" />',
            '</line>',
            '<text x="120" y="340">',
            xAxisLabel,
            '</text>',

            // add the dates or hours to the X axis 
            buildTimeUnitsSVG(isWeekChart, xInterval),

            // create / label the y axis
            '<line x1="50" x2="300" y1="300" y2="300" stroke="black" stroke-width="5">',
            '<animate attributeName="x1" from="300" to="50" begin="0s" dur="1s" />',
            '</line>',
            '<text x="30" y="150" style="writing-mode: sideways-lr;">',
            'Price  (',
            symbol1,
            ')',
            '</text>',

            // create the price points, labels, and lines
            buildPricePointsSVG(twips, xInterval),
            '</svg>'
        );
            
        return toReturn;
    }

    /*
    * @dev Returns a string of SVG data representing
    * the time units on the X axis.
    */
    function buildTimeUnitsSVG(bool isWeek, uint16 xInterval) internal view returns (bytes memory) {
        bytes memory toReturn = "";
        uint8 numPoints = isWeek ? 7 : 6;
        uint16[7] memory units;
        uint16 pointX = 50;

        // populate the time units
        units = getTimeUnits(isWeek);

        for (uint8 i=0; i < numPoints; i++) {
            pointX = pointX + xInterval;
            toReturn = abi.encode(
                toReturn,
                '<text x="',
                pointX,
                '" y="320" font-size="14">',
                '<set attributeName="visibility" from="visible"',
                ' to="hidden" begin="0s" dur="1s" />',
                units[i],
                '</text>'
            );
        }

        return toReturn;
    }

    /*
    * @dev Returns an array of 7 date units if isWeek is true.
    * Returns an array of 6 hour units if isWeek is false.
    * E.g. isWeek is true, returns [28, 29, 30, 31, 1, 2, 3]
    *      isWeek is false, returns [6, 7, 8, 9, 10, 11]
    */
    function getTimeUnits(bool isWeek) internal view returns (uint16[7] memory units) {
        uint256 hour = 3600;  // seconds

        // store 7 days including the current day
        // sorted from oldest to newest
        if (isWeek) {
            for (uint256 i=6; i>=0; i--) {
                units[6-i] = ethDT.getDay(block.timestamp - (hour * 24 * i));
            }
        }

        // store six 4-hour intervals including the current hour
        // sorted from oldest to newest
        else {
            for (uint256 i=5; i>=0; i--) {
                units[5-i] = ethDT.getHour(block.timestamp - (hour * 4 * i));
            }
        }

        return units;
    }

    /*
    * @dev Returns a string of SVG data representing
    * the price points on the graph.
    */
    function buildPricePointsSVG(uint256[] memory twips, uint16 xInterval) internal pure returns (bytes memory) {
        uint256[] memory normalizedTwaps = calcNormalizedTwaps(twips);
        
        // loop through the prices and create
        // the points and lines for each price
        bytes memory toReturn;

        // create first point and its label
        toReturn = firstPointSVG(twips[0], normalizedTwaps[0]);

        // create remaining points, their labels, and lines connecting them
        toReturn = abi.encode(
            toReturn,
            remainingPointsSVG(twips, normalizedTwaps, xInterval)
        );
        
        return toReturn;
    }

    /*
    * @dev Returns an array of uints of y coords
    * representing price data that is normalized
    * to fit a 250px square chart.
    */
    function calcNormalizedTwaps(uint256[] memory twips) internal pure returns (uint256[] memory normalizedTwaps) {
        // TODO test for inactive markets or invalid values
        //      ... what if the price oracle returns 0 or -1?
        // thanks to Ross Bulat for normalizing the data for SVG
        // https://tinyurl.com/563uk68a

        // TODO format twips to decimal places
        // get min and max of price data
        uint256 min = twips[0];
        uint256 max = twips[0];
        for (uint8 i=1; i<twips.length; i++) {
            if (twips[i] > max) max = twips[i];
            if (twips[i] < min) min = twips[i];
        }

        for (uint8 i=0; i<twips.length; i++) {
            // feature scaling, multiplied by 250 to fit our 250px square graph
            // since our square graph lies between 50px and 300px
            // subtract the result from 300 to inverse the coords for SVG
            // additionally we give 3px buffer for our circles so we start
            // at 297 instead of 300
            normalizedTwaps[i] = 297 - (((twips[i] - min) / (max-min)) * 250);
        }

        return normalizedTwaps;
    }

    /*
    * @dev Returns SVG of first point on graph.
    */
    function firstPointSVG(uint256 twap, uint256 normalizedTwap) internal pure returns (bytes memory) {

        return abi.encode(
            '<circle cx="53" cy="',
            normalizedTwap,
            '" r="5" fill="aqua" visibility="visible">',
            '<set attributeName="visibility" from="visible" to="hidden" ',
            'begin="0ms" dur="1000ms" />',
            '</circle>',
            '<text x="53" y="',
            normalizedTwap - 10,
            '" font-size="14">',
            '<set attributeName="visibility" from="visible" to="hidden" ',
            'begin="0ms" dur="1000ms" />',
            // TODO what if twip has 10 leading 0's?
            twap, 
            '</text>'
        );
    }
    
    /*
    * @dev Returns SVG of remaining points on graph.
    */
    function remainingPointsSVG(uint256[] memory twaps, uint256[] memory normalizedTwaps, uint16 xInterval) internal pure returns (bytes memory toReturn) {
        // loop through each price
        for (uint8 i=1; i<twaps.length; i++) {
            
            // concat the svg for each point, its label, and connecting lines
            toReturn = abi.encode(
                toReturn,
                circleSVG(normalizedTwaps, i, xInterval),
                labelSVG(twaps, normalizedTwaps, i, xInterval),
                lineSVG(normalizedTwaps, i, xInterval)
            );
        }
    }

    /*
    * @dev Returns SVG of a price point circle.
    */
    function circleSVG(uint256[] memory normalizedTwaps, uint8 index, uint16 xInterval) internal pure returns (bytes memory) {
        return abi.encode(
            '<circle cx="',
            53 + (index * xInterval),
            '" cy="',
            normalizedTwaps[index],
            '" r="5" fill="aqua" visibility="visible"> ',
            '<set attributeName="visibility" from="visible" to="hidden" ',
            'begin="0ms" dur="',
            1000 + (index * 500),
            'ms" />',
            '</circle>'
        );
    }

    /*
    * @dev Returns SVG of a price point label.
    */
    function labelSVG(uint256[] memory twaps, uint256[] memory normalizedTwaps, uint8 index, uint16 xInterval) internal pure returns (bytes memory) {
        return abi.encode(
            '<text x="',
            53 + (index * xInterval) - 10,
            '" y="',
            normalizedTwaps[index] - 10,
            '" font-size="14" visibility="visible">',
		    '<set attributeName="visibility" from="visible" to="hidden" ',
            'begin="0ms" dur="',
            1000 + (index * 500),
            //pointDur,
            'ms" />',
            twaps[index],
            '</text>'
        );
    }

    /*
    * @dev Returns SVG of a line connecting two price points.
    */
    function lineSVG(uint256[] memory normalizedTwaps, uint8 index, uint16 xInterval) internal pure returns (bytes memory) {
        return abi.encode(
            '<line x1="',
            53 + (index * xInterval) - xInterval,
            '" x2="',
            53 + (index * xInterval),
            '" y1="',
            normalizedTwaps[index-1],
            '" y2="',
            normalizedTwaps[index],
            '" stroke="green" stroke-width="3" visibility="visible">',
            '<set attributeName="visibility" from="visible" to="hidden" ',
            'begin="0ms" dur="',
            1000 + (index * 500) - 500,
            'ms" />',
            '<animate attributeName="y2" from="',
            normalizedTwaps[index-1],
            '" to="',
            normalizedTwaps[index],
            '" begin="',
            1000 + (index * 500) - 500,
            'ms" dur="500ms" />',
            '<animate attributeName="x2" from="',
            53 + (index * xInterval) - xInterval,
            '" to="',
            53 + (index * xInterval),
            '" begin="',
            1000 + (index * 500) - 500,
            'ms" dur="500ms" /></line>'
        );
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

        // now query Uniswap Oracle for Price Data (https://andrecronje.medium.com/easy-on-chain-oracles-54d82961a2a0)
        // eg - to get over 24 hours period, need to query for 30 mins, then 60 mins, then 90, then ... up to 24 hrs
        // and return all values as an array to plot

        uint256 twipCountToFetch = lookBackWindowForToken[tokenId] * 48; // 48 comes from assuming 3600 is for 30 mins as docs say. and there are 48 periods of 30 mins in one day
        uint256[] memory twips = new uint256[](twipCountToFetch);
        // TODO: should be a map of seconds (uint256) to prices (unit256)
        for (uint256 i = 0; i < twipCountToFetch; i++) {
            uint256 currentLookbackWindow = (i + 1) * 3600; // recall i is 0 indexed
            uint256 twip = oracle.assetToAsset(tokens[0], 1e18, tokens[1], currentLookbackWindow);
            twips[i] = twip;
        }

        string memory svg = string(this.buildSVG(symbol0, symbol1, twips));

        // Build outline of JSON blob
        /*
        {
        "description": "NFcharT", 
        "name": buildToken0/Token1Symbol(tokenId),
        "image_data": buildSVG(tokenId),
        // "attributes": [{"key": "value"}], // TODO: this is for v2
        }
         */

        // base64 encode it (can use contract from here: https://etherscan.io/address/0xe0fa9fb0e30ca86513642112bee1cbbaa2a0580d#code)

        // return it
        return svg;
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

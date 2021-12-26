// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
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
    // TODO change to internal, bytes
    function buildSVG(string memory symbol0, string memory symbol1, uint256[] memory twips) external view returns (string memory) {
        // the graph is 350x350 pixels
        // there are 50px of padding in all directions
        // to allow labeling of the axes, and titling the chart
        // the chart lines and points are drawn in a 250x250 pixel square

        // there are two possible charts
        // 1. Daily chart (6 points of 4 hours)
        // 2. Weekly chart (7 points of 1 day)

        // determine if the chart is a 1 day chart or 7 day chart
        bool isWeekChart = twips.length == 7;

        // weekly charts have 35 pixels between points
        // whereas daily charts have 40
        uint16 xInterval = isWeekChart? 38 : 47;

        // generate the SVG for the chart 
        return string(abi.encodePacked(
            declareSVG(),
            chartTitleSVG(symbol0, symbol1),
            xAxisLabelSVG(isWeekChart),
            buildTimeUnitsSVG(isWeekChart, xInterval),
            yAxisSVG(symbol1),
            buildPricePointsSVG(twips, xInterval),
            '</svg>'
        ));
    }

    /*
    * @dev Returns opening SVG element.
    */
    function declareSVG() internal pure returns (bytes memory) {

        return abi.encodePacked(
            '<svg width="350" height="350" ',
            'xmlns="http://www.w3.org/2000/svg',
            '" xmlns:xlink="http://www.w3.org/',
            '1999/xlink">'
        );
    }

    /*
    * @dev Returns SVG of chart title.
    */
    function chartTitleSVG(string memory symbol0, string memory symbol1) internal pure returns (bytes memory) {

        return abi.encodePacked(
            '<text x="150" y="50" ',
            'font-size="18">',
            '<set attributeName="visibility" ',
            'from="visible" to="hidden" ',
            'begin="0s" dur="1s" />',
            symbol0,
            '/',
            symbol1,
            '</text>'
        );
    }

    /*
    * @dev Returns SVG of X axis label.
    */
    function xAxisLabelSVG(bool isWeek) internal pure returns (bytes memory) {
        string memory xAxisLabel = isWeek? "Day (UTC)" : "Hour (UTC)";

        return abi.encodePacked(
            // create / label the X axis
            '<line x1="50" x2="50" y1="50" ',
            'y2="300" stroke="black" ',
            'stroke-width="5">',
		    '<animate attributeName="y2" ',
            'from="50" to="300" begin="0s" ',
            'dur="1s" />',
            '</line>',
            '<text x="120" y="340">',
            xAxisLabel,
            '</text>'
        );
    }

    /*
    * @dev Returns SVG of Y axis.
    */
    function yAxisSVG(string memory symbol1) internal pure returns (bytes memory) {

        return abi.encodePacked(
            '<line x1="50" x2="300" y1="300" ',
            'y2="300" stroke="black" ',
            'stroke-width="5">',
            '<animate attributeName="x1" ',
            'from="300" to="50" begin="0s" ',
            'dur="1s" />',
            '</line>',
            '<text x="30" y="150" ',
            'style="writing-mode: ',
            'sideways-lr;">',
            'Price  (',
            symbol1,
            ')',
            '</text>'
        );
    }

    /*
    * @dev Returns a string of SVG data representing
    * the time units on the X axis.
    */
    function buildTimeUnitsSVG(bool isWeek, uint16 xInterval) internal view returns (bytes memory toReturn) {
        uint8 numPoints = isWeek ? 7 : 6;
        uint16[7] memory units;
        uint16 pointX = 50;

        // populate the time units
        units = getTimeUnits(isWeek);

        for (uint8 i=0; i < numPoints; i++) {
            toReturn = abi.encodePacked(
                toReturn,
                '<text x="',
                Strings.toString(pointX + (i * xInterval)),
                '" y="320" font-size="14">',
                '<set attributeName="visibility" ',
                'from="visible" to="hidden" ',
                'begin="0s" dur="1s" />',
                Strings.toString(units[i]),
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

            for (uint256 i=0; i<7; i++) {
                units[i] = ethDT.getDay(block.timestamp - (hour * 24 * (6-i)));
            }
        }

        // store six 4-hour intervals including the current hour
        // sorted from oldest to newest
        else {

            for (uint256 i=0; i<6; i++) {
                units[i] = ethDT.getHour(block.timestamp - (hour * 4 * (5-i)));
            }
        }

        return units;
    }

    /*
    * @dev Returns a string of SVG data representing
    * the price points on the graph.
    */
    function buildPricePointsSVG(uint256[] memory twips, uint16 xInterval) internal pure returns (bytes memory toReturn) {
        uint256[7] memory normalizedTwaps = calcNormalizedTwaps(twips);

        // create first point and its label
        toReturn = firstPointSVG(twips[0], normalizedTwaps[0]);

        // create remaining points, their labels, and lines connecting them
        toReturn = abi.encodePacked(
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
    function calcNormalizedTwaps(uint256[] memory twips) internal pure returns (uint256[7] memory normalizedTwaps) {
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
            // feature scaling, multiplied by 250 to fit the 250px square graph

            // feature scaling gives a result between 0 and 1; in solidity this
            // will round down to 0, so the result is multiplied and later divided
            //  by the max to preserve the precision

            // since the chart is a square graph that lies between 50px and 300px,
            // subtract the result from 300 to inverse the coords for SVG

            // a 3px buffer is given for the circles on the graph,
            // so the first coord starts at 297 instead of 300
            normalizedTwaps[i] = 297 - ( ( ( (twips[i] - min) * max ) / (max-min) * 230 ) / max );
        }

        return normalizedTwaps;
    }

    /*
    * @dev Returns SVG of first point on graph.
    */
    function firstPointSVG(uint256 twap, uint256 normalizedTwap) internal pure returns (bytes memory) {

        return abi.encodePacked(
            '<circle cx="53" cy="',
            Strings.toString(normalizedTwap),
            '" r="5" fill="aqua" visibility=',
            '"visible">',
            '<set attributeName="visibility" ',
            'from="visible" to="hidden" ',
            'begin="0ms" dur="1000ms" />',
            '</circle>',
            '<text x="63" y="',
            Strings.toString(normalizedTwap),
            '" font-size="14">',
            '<set attributeName="visibility" ',
            'from="visible" to="hidden" ',
            'begin="0ms" dur="1000ms" />',
            // TODO what if twip has 10 leading 0's?
            Strings.toString(twap), 
            '</text>'
        );
    }
    
    /*
    * @dev Returns SVG of remaining points on graph.
    */
    function remainingPointsSVG(uint256[] memory twaps, uint256[7] memory normalizedTwaps, uint16 xInterval) internal pure returns (bytes memory toReturn) {
        // loop through each price
        for (uint8 i=1; i<twaps.length; i++) {
            
            // concat the svg for each point, its label, and connecting lines
            toReturn = abi.encodePacked(
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
    function circleSVG(uint256[7] memory normalizedTwaps, uint8 index, uint16 xInterval) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<circle cx="',
            Strings.toString(53 + (index * xInterval)),
            '" cy="',
            Strings.toString(normalizedTwaps[index]),
            '" r="5" fill="aqua" visibility=',
            '"visible"> ',
            '<set attributeName="visibility" ',
            'from="visible" to="hidden" ',
            'begin="0ms" dur="',
            Strings.toString(1000 + (index * 500)),
            'ms" />',
            '</circle>'
        );
    }

    /*
    * @dev Returns SVG of a price point label.
    */
    function labelSVG(uint256[] memory twaps, uint256[7] memory normalizedTwaps, uint8 index, uint16 xInterval) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<text x="',
            Strings.toString(53 + (index * xInterval) + 10),
            '" y="',
            Strings.toString(normalizedTwaps[index]),
            '" font-size="14" visibility=',
            '"visible">',
		    '<set attributeName="visibility" ',
            'from="visible" to="hidden" ',
            'begin="0ms" dur="',
            Strings.toString(1000 + (index * 500)),
            'ms" />',
            Strings.toString(twaps[index]),
            '</text>'
        );
    }

    /*
    * @dev Returns SVG of a line connecting two price points.
    */
    function lineSVG(uint256[7] memory normalizedTwaps, uint8 index, uint16 xInterval) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<line x1="',
            Strings.toString(53 + (index * xInterval) - xInterval),
            '" x2="',
            Strings.toString(53 + (index * xInterval)),
            '" y1="',
            Strings.toString(normalizedTwaps[index-1]),
            '" y2="',
            Strings.toString(normalizedTwaps[index]),
            '" stroke="green" stroke-width=',
            '"3" visibility="visible">',
            '<set attributeName="visibility" ',
            'from="visible" to="hidden" ',
            'begin="0ms" dur="',
            Strings.toString(1000 + (index * 500) - 500),
            'ms" />',
            lineAnimationSVG(normalizedTwaps, index, xInterval),
            '</line>'
        );
    }

    /*
    * @dev Returns SVG of the line animation.
    */
    function lineAnimationSVG(uint256[7] memory normalizedTwaps, uint8 index, uint16 xInterval) internal pure returns (bytes memory) {
        return abi.encodePacked(
            '<animate attributeName="y2" from="',
            Strings.toString(normalizedTwaps[index-1]),
            '" to="',
            Strings.toString(normalizedTwaps[index]),
            '" begin="',
            Strings.toString(1000 + (index * 500) - 500),
            'ms" dur="500ms" />',
            '<animate attributeName="x2" from="',
            Strings.toString(53 + (index * xInterval) - xInterval),
            '" to="',
            Strings.toString(53 + (index * xInterval)),
            '" begin="',
            Strings.toString(1000 + (index * 500) - 500),
            'ms" dur="500ms" />'
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
        string memory pairName = string(abi.encodePacked('"', symbol0, '/', symbol1, '"'));

        uint256 twipCountToFetch = lookBackWindowForToken[tokenId] * 48; // 48 comes from assuming 3600 is for 30 mins as docs say. and there are 48 periods of 30 mins in one day
        uint256[] memory twips = new uint256[](twipCountToFetch);
        for (uint256 i = 0; i < twipCountToFetch; i++) {
            uint256 currentLookbackWindow = (i + 1) * 3600; // recall i is 0 indexed
            // https://andrecronje.medium.com/easy-on-chain-oracles-54d82961a2a0
            uint256 twip = oracle.assetToAsset(tokens[0], 1e18, tokens[1], currentLookbackWindow);
            twips[i] = twip;
        }

        // separating strings into small chunks to not exceed 32 bit limit
        string memory blob = string(
            abi.encodePacked(
                '{"',
                'description"',
                ': "NFcharT", "name": ',
                pairName,
                ', "image_data":',
                this.buildSVG(symbol0, symbol1, twips),
                '}'
            )
        );

        // TODO: add header specifying this is base64 encoded application/json (like the http header)
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

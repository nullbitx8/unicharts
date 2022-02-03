pragma solidity ^0.8.0;

/*
 * Mock UniV3Oracle contract used for testing.
 * Implements the interface but returns fake data. 
 *
 */
contract V3Oracle {

    /*
     * Returns fake price data based on the seconds queried.
     * The price returned assumes token1 has 9 decimals.
     */
    function assetToAsset(
        address token0, 
        uint256 amount0,
        address token1,
        uint256 secondsAgo
    ) external view returns (uint256) {
        // current time
        if (secondsAgo == 0) {
            return 80 * 1e9;
        }
        // four hours ago
        if (secondsAgo == 3600 * 4) {
            return 80 * 1e9;
        }
        // eight hours ago
        else if (secondsAgo == 3600 * 8) {
            return 150 * 1e9;
        }
        // twelve hours ago
        else if (secondsAgo == 3600 * 12) {
            return 100 * 1e9;
        }
        // sixteen hours ago
        else if (secondsAgo == 3600 * 16) {
            return 300 * 1e9;
        }
        // twenty hours ago
        else if (secondsAgo == 3600 * 20) {
            return 200 * 1e9;
        }
        // 1 day ago
        else if (secondsAgo == 3600 * 24) {
            return 350 * 1e9;
        }
        else return 1 * 1e9;
    }

}

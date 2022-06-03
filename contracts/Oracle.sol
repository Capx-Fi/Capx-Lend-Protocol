// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

pragma solidity 0.8.4;

interface LiquidInterface {
    // controller -> liquid interface
    function derivativeAdrToActualAssetAdr(address _wvt)
        external
        view
        returns (address);
}

contract Oracle is Ownable {
    // auto
    mapping(address => address) public assetToFeed;

    address public controller;

    constructor() {}

    function setController(address _controller) external onlyOwner {
        controller = _controller;
    }

    function updateAssetFeed(address _asset, address _feed) public onlyOwner {
        assetToFeed[_asset] = _feed;
    }

    function getPrice(address _wvt) external view returns (uint256, uint256) {
        address _actualAsset = LiquidInterface(controller)
            .derivativeAdrToActualAssetAdr(_wvt);
        require(_actualAsset != address(0), "Not a known asset");
        (
            ,
            /*uint80 roundID*/
            int256 price, /*uint startedAt*/ /*uint timeStamp*/
            ,
            ,

        ) = /*uint80 answeredInRound*/
            AggregatorV3Interface(assetToFeed[_actualAsset]).latestRoundData();

        return (
            uint256(price),
            AggregatorV3Interface(assetToFeed[_actualAsset]).decimals()
        );
        // Example as ETH
        // ((value retuned by oracle)*(decimal of stable coin))/(10**8) StableTokenBaseUnit will be returned for 10**18 wei
        // so for 1wei = ((value retuned by oracle)*(decimal of stable coin))/((10**8)(10**decimal of asset))
    }
}

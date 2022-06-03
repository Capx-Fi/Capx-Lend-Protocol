// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

contract AggregatorV3Interface {

    uint8 public feedDecimal;
    uint256 public feedVersion;

    // Round Data

    uint80 public feedroundId;
    int256 public feedanswer;
    uint256 public feedstartedAt;
    uint256 public feedupdatedAt;
    uint80 public feedansweredInRound;

    constructor(){}

  function decimals() external view returns (uint8){
      return(feedDecimal);
  }

  function description() external view returns (string memory){
      return("Feed desc Asset/USD");
  }

  function version() external view returns (uint256){
      return(feedVersion);
  }

  function latestRoundData()
    external
    view
    returns (
      uint80,
      int256,
      uint256,
      uint256,
      uint80
    ){
        return(feedroundId,feedanswer,feedstartedAt,feedupdatedAt,feedansweredInRound);
    }

    function updateFeedData(uint80 _rid, int256 _answer, uint256 _startedat, uint256 _updatedat,uint80 _answeredInRound) public {
        feedroundId = _rid;
        feedanswer = _answer;
        feedstartedAt = _startedat;
        feedupdatedAt = _updatedat;
        feedansweredInRound = _answeredInRound;
    }

    function updateFeedDecimalAndVersion(uint8 _feedDecimal, uint256 _feedVersion) public {
        feedDecimal = _feedDecimal;
        feedVersion = _feedVersion;
    }
}

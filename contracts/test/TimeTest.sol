// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;
contract Time {
    function normalisedTime() public view returns(uint256){
        return (block.timestamp / 86400) * 86400;
    }
    function time() public view returns(uint256){
        return block.timestamp;
    }
}
// SPDX-License-Identifier: Unlicenced
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

pragma solidity 0.8.4;

contract LendNFT is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC721Upgradeable
{
    address public controller;

    function initialize() public initializer {
        __Ownable_init();
        __ERC721_init("LendNFT", "LNFT");
    }

    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    function setController(address _controller) public onlyOwner {
        require((msg.sender == owner()), "Only owner can set controller");
        controller = _controller;
    }

    function mintLoanNFT(uint256 _tokenID, address _lender) public {
        require(msg.sender == controller, "Controller can only mint");
        _mint(_lender, _tokenID);
    }

    function burnLoanNFT(uint256 _tokenID) public {
        require(msg.sender == controller, "Controller can only burn");
        _burn(_tokenID);
    }
}

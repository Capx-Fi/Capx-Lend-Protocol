// SPDX-License-Identifier: GNU GPLv3

import "../../node_modules/@openzeppelin/contracts/access/Ownable.sol";

pragma solidity 0.8.4;

abstract contract ERC20Clone {
    function initializer(
        address _minter,
        string memory _wrappedTokenName,
        string memory _wrappedTokenTicker,
        uint8 _wrappedTokenDecimals,
        uint256 _vestEndTime
    ) public virtual;
}

pragma solidity 0.8.4;

/// @title ERC20Factory contract for mass deployment of derivatives
/// @author Capx Team
/// @notice Only the controller contract can call the function which deploys cheap copy of ERC20 contracts
/// @dev This contract uses EIP-1167: Minimal Proxy Contract
contract ERC20Factory is Ownable {
    address public implementation;
    address public controller;
    address public lender;

    constructor(address _implementaiton, address _controller) {
        implementation = _implementaiton;
        controller = _controller;
    }

    /// @notice Function which can only be called by owner and used to set lender contract address.
    /// @param _lender The address of the lender contract.
    function setLender(address _lender) external onlyOwner {
        lender = _lender;
    }

    /// @notice Function called by controller contract to deploy new ERC20 token
    function createStorage(
        string memory _wrappedTokenName,
        string memory _wrappedTokenTicker,
        uint8 _wrappedTokenDecimals,
        uint256 _vestEndTime
    ) public returns (address) {
        require(msg.sender == controller, "Only controller can access");
        address clone = createClone(implementation);
        // Handling low level exception
        assert(clone != address(0));
        ERC20Clone(clone).initializer(
            controller,
            _wrappedTokenName,
            _wrappedTokenTicker,
            _wrappedTokenDecimals,
            _vestEndTime
        );
        return (clone);
    }

    /// @notice Function uses EIP-1167 implementation
    function createClone(address _target) internal returns (address result) {
        bytes20 targetBytes = bytes20(_target);
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }
    }
}

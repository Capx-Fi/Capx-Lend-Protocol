// SPDX-License-Identifier: GNU GPLv3
import "./timestampToDateLibrary.sol";
import "../../node_modules/@openzeppelin/contracts/access/Ownable.sol";

import "../../node_modules/@openzeppelin/contracts/utils/Address.sol";

import "../../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

pragma solidity 0.8.4;

interface ERC20Properties {
    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function decimals() external view returns (uint8);
}

pragma solidity 0.8.4;

interface ERC20Clone {
    function mintbyControl(address _to, uint256 _amount) external;

    function burnbyControl(address _to, uint256 _amount) external;
}

pragma solidity 0.8.4;

interface AbsERC20Factory {
    function createStorage(
        string memory _wrappedTokenName,
        string memory _wrappedTokenTicker,
        uint8 _wrappedTokenDecimals,
        uint256 _vestTime
    ) external returns (address);
}

pragma solidity 0.8.4;

/// @title Controller contract for vesting
/// @author Capx Team
/// @notice The Controller contract is the only contract which the user will interact with for vesting.
/// @dev This contract uses openzepplin Upgradable plugin. https://docs.openzeppelin.com/upgrades-plugins/1.x/
contract Controller is Ownable {
    using SafeERC20 for IERC20;

    uint256 internal constant DAY = 86400;
    uint256 internal constant _ACTIVE = 2;
    uint256 internal constant _INACTIVE = 1;

    uint256 public lastVestID;
    uint256 internal _locked;
    uint256 internal _killed;
    uint256 internal totalAmount;
    address internal factoryAddress;
    address internal proposalContract;

    mapping(uint256 => address) public derivativeIDtoAddress;
    mapping(address => uint256) public vestingTimeOfTokenId;
    mapping(address => uint256) public totalDerivativeForAsset;
    mapping(address => address) public assetAddresstoProjectOwner;
    mapping(address => address) public derivativeAdrToActualAssetAdr;

    struct derivativePair {
        address sellable;
        address nonsellable;
    }

    mapping(address => mapping(uint256 => derivativePair))
        public assetToDerivativeMap;
    mapping(address => mapping(address => uint256))
        public assetLockedForDerivative;

    event ProjectInfo(
        string name,
        address indexed tokenAddress,
        string tokenTicker,
        string documentHash,
        address creator,
        uint256 tokenDecimal
    );

    event CreateVest(
        address indexed assetAddress,
        address creator,
        address userAddress,
        uint256 userAmount,
        uint256 unlockTime,
        address wrappedERC20Address,
        string wrappedAssetTicker,
        bool transferable
    );

    event TransferWrapped(
        address userAddress,
        address indexed wrappedTokenAddress,
        address receiverAddress,
        uint256 amount
    );

    event Withdraw(
        address indexed userAddress,
        uint256 amount,
        address wrappedTokenAddress
    );

    modifier noReentrant() {
        require(_locked != _ACTIVE, "ReentrancyGuard: Re-Entrant call");
        _locked = _ACTIVE;
        _;
        _locked = _INACTIVE;
    }

    function isKilled() internal view {
        require(_killed != _ACTIVE, "FailSafeMode: ACTIVE");
    }

    /// @notice Disables the derivative Creation & Withdraw functionality of the contract.
    function kill() external onlyOwner {
        _killed = _ACTIVE;
    }

    /// @notice Enables the derivative Creation & Withdraw functionality of the contract.
    function revive() external onlyOwner {
        _killed = _INACTIVE;
    }

    constructor() {
        lastVestID = 0;
        _killed = _INACTIVE;
        _locked = _INACTIVE;
    }

    /// @notice Sets factory contract address to the erc20FactoryContract object state variable
    /// @param _factoryAddress The address of the factory contract which makes cheap copies of ERC20 model contract
    function setFactory(address _factoryAddress) external onlyOwner {
        require(_factoryAddress != address(0), "Invalid Address");
        factoryAddress = _factoryAddress;
    }

    /// @notice Sets Proposal contract address.
    /// @param _proposalContract The address of the proposal contract.
    function setProposalContract(address _proposalContract) external onlyOwner {
        require(_proposalContract != address(0), "Invalid Address");
        proposalContract = _proposalContract;
    }

    /// @notice Using this function a user can vest their project tokens till a specific date
    /// @dev Iterates over the vesting sheet received in params for
    /// @param _name Name of the project
    /// @param _documentHash Document IPFS hash of the project
    /// @param _tokenAddress Address of the project token
    /// @param _amount Amount of tokens the user wants to vest
    /// @param _distAddress Array of Addresses to whome the project owner wants to distribute derived tokens.
    /// @param _distTime Array of Integer timestamps at which the derived tokens will be eligible for exchange with project tokens
    /// @param _distAmount Array of amount which determines how much of each derived tokens should be distributed to _distAddress
    /// @param _transferable Array of boolean determining which asset is sellable and which is not
    function createBulkDerivative(
        string memory _name,
        string memory _documentHash,
        address _tokenAddress,
        uint256 _amount,
        address[] calldata _distAddress,
        uint256[] memory _distTime,
        uint256[] memory _distAmount,
        bool[] memory _transferable
    ) external virtual noReentrant {
        isKilled();
        // Function variable Declaration
        totalAmount = 0;
        uint256 i = 0;
        uint256 _limitOfDerivatives = 20;
        // uint256 _lengthOfEntries = _distTime.length;

        require(
            _distTime.length != 0 &&
                _amount != 0 &&
                _tokenAddress != address(0) &&
                _distTime.length <= 400,
            "Invalid Input"
        );
        require(
            (_distAddress.length == _distTime.length) &&
                (_distTime.length == _distAmount.length) &&
                (_distTime.length == _transferable.length),
            "Inconsistency in vesting details"
        );
        // require(_distTime.length <= 400, "Vest Limit exceeded");
        require(
            bytes(_name).length >= 2 &&
                bytes(_name).length <= 26 &&
                bytes(_documentHash).length == 46,
            "Invalid name or document length"
        );

        // Registering the Project Asset to it's owner.
        if (assetAddresstoProjectOwner[_tokenAddress] == address(0)) {
            assetAddresstoProjectOwner[_tokenAddress] = msg.sender;
        }

        // transfering ERC20 tokens from _projectOwner (msg.sender) to contract
        _safeTransferERC20(_tokenAddress, msg.sender, address(this), _amount);

        emit ProjectInfo(
            _name,
            _tokenAddress,
            ERC20Properties(_tokenAddress).symbol(),
            _documentHash,
            assetAddresstoProjectOwner[_tokenAddress],
            ERC20Properties(_tokenAddress).decimals()
        );

        // Minting wrapped tokens by iterating on the vesting sheet
        for (i = 0; i < _distTime.length; i++) {
            uint256 _vestTime = (_distTime[i] / DAY) * DAY;

            require(
                _vestTime > ((block.timestamp / DAY) * DAY),
                "Not a future Vest End Time"
            );
            // Checking if the distribution of tokens is in consistent with the total amount of tokens.
            totalAmount += _distAmount[i];
            // require(totalAmount <= _amount, "Invalid Token Distribution");

            address _wrappedTokenAdr;
            if (_transferable[i]) {
                _wrappedTokenAdr = assetToDerivativeMap[_tokenAddress][
                    _vestTime
                ].sellable;
            } else {
                _wrappedTokenAdr = assetToDerivativeMap[_tokenAddress][
                    _vestTime
                ].nonsellable;
            }
            string memory _wrappedTokenTicker = "";
            if (_wrappedTokenAdr == address(0)) {
                //function call to deploy new ERC20 derivative
                lastVestID += 1;
                require(_limitOfDerivatives > 0, "Derivative limit exhausted");
                _limitOfDerivatives -= 1;
                (_wrappedTokenAdr, _wrappedTokenTicker) = _deployNewERC20(
                    _tokenAddress,
                    _vestTime,
                    _transferable[i]
                );

                //update mapping
                _updateMappings(
                    _wrappedTokenAdr,
                    _tokenAddress,
                    _vestTime,
                    _transferable[i]
                );
            } else {
                _wrappedTokenTicker = ERC20Properties(_wrappedTokenAdr).symbol();
            }
            assert(
                _mintWrappedTokens(
                    _tokenAddress,
                    _distAddress[i],
                    _distAmount[i],
                    _wrappedTokenAdr
                )
            );

            totalDerivativeForAsset[_tokenAddress] += _distAmount[i];

            emit CreateVest(
                _tokenAddress,
                msg.sender,
                _distAddress[i],
                _distAmount[i],
                _vestTime,
                _wrappedTokenAdr,
                _wrappedTokenTicker,
                _transferable[i]
            );
        }

        require(totalAmount == _amount, "Inconsistent amount of tokens");
        assert(
            IERC20(_tokenAddress).balanceOf(address(this)) >=
                totalDerivativeForAsset[_tokenAddress]
        );
    }

    /// @notice Helper function to update the mappings.
    /// @dev Updates the global state variables.
    /// @param _wrappedTokenAdr Address of the derivative to be updated.
    /// @param _tokenAddress Address of the Project Token of which the derivative is created.
    /// @param _vestTime Time of unlock of the project token.
    /// @param _transferable Boolean to determine if this asset is sellable or not.
    function _updateMappings(
        address _wrappedTokenAdr,
        address _tokenAddress,
        uint256 _vestTime,
        bool _transferable
    ) internal {
        derivativeIDtoAddress[lastVestID] = _wrappedTokenAdr;

        if (_transferable) {
            assetToDerivativeMap[_tokenAddress][_vestTime]
                .sellable = _wrappedTokenAdr;
        } else {
            assetToDerivativeMap[_tokenAddress][_vestTime]
                .nonsellable = _wrappedTokenAdr;
        }

        vestingTimeOfTokenId[_wrappedTokenAdr] = _vestTime;

        derivativeAdrToActualAssetAdr[_wrappedTokenAdr] = _tokenAddress;
    }

    /// @notice Helper function to transfer the corresponding token.
    /// @dev Uses the IERC20Upgradable to transfer the asset from one user to another.
    /// @param _tokenAddress The asset of which the transfer is to take place.
    /// @param _from The address from which the asset is being transfered.
    /// @param _to The address to whom the asset is being transfered.
    /// @param _amount The quantity of the asset being transfered.
    function _safeTransferERC20(
        address _tokenAddress,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        // transfering ERC20 tokens from _projectOwner (msg.sender) to contract
        if (_from == address(this)) {
            IERC20(_tokenAddress).safeTransfer(_to, _amount);
        } else {
            IERC20(_tokenAddress).safeTransferFrom(_from, _to, _amount);
        }
    }

    /// @notice Function called by createBulkDerivative to spawn new cheap copies which make delegate call to ERC20 Model Contract
    /// @dev Uses the AbsERC20Factory interface object to call createStorage method of the factory contract
    /// @param _tokenAddress Token address for which a derivative is being created
    /// @param _vestTime The timestamp after which the token deployed can be exchanged for the project token
    /// @param _transferable The new deployed ERC20 is sellable or not
    /// @return Returns a tupple of address which contains the address of newly deployed ERC20 contract and its token ticker
    function _deployNewERC20(
        address _tokenAddress,
        uint256 _vestTime,
        bool _transferable
    ) internal virtual returns (address, string memory) {
        // Getting ERC20 token information
        string memory date = _timestampToDate(_vestTime);

        address currentContractAddress;
        string memory _wrappedTokenTicker;
        if (_transferable) {
            _wrappedTokenTicker = string(
                abi.encodePacked(
                    date,
                    ".",
                    ERC20Properties(_tokenAddress).symbol(),
                    "-S"
                )
            );
            string memory wrappedTokenName = string(
                abi.encodePacked(
                    date,
                    ".",
                    ERC20Properties(_tokenAddress).name(),
                    "-S"
                )
            );
            uint8 wrappedTokenDecimals = ERC20Properties(_tokenAddress)
                .decimals();

            currentContractAddress = AbsERC20Factory(factoryAddress)
                .createStorage(
                    wrappedTokenName,
                    _wrappedTokenTicker,
                    wrappedTokenDecimals,
                    0
                );
        } else {
            _wrappedTokenTicker = string(
                abi.encodePacked(
                    date,
                    ".",
                    ERC20Properties(_tokenAddress).symbol(),
                    "-NS"
                )
            );
            string memory wrappedTokenName = string(
                abi.encodePacked(
                    date,
                    ".",
                    ERC20Properties(_tokenAddress).name(),
                    "-NS"
                )
            );
            uint8 wrappedTokenDecimals = ERC20Properties(_tokenAddress)
                .decimals();

            currentContractAddress = AbsERC20Factory(factoryAddress)
                .createStorage(
                    wrappedTokenName,
                    _wrappedTokenTicker,
                    wrappedTokenDecimals,
                    _vestTime
                );
        }

        // Creating new Wrapped ERC20 asset

        return (currentContractAddress, _wrappedTokenTicker);
    }

    /// @notice Function called by createBulkDerivative to mint new Derived tokens.
    /// @dev Uses the ERC20Clone interface object to instruct derived asset to mint new tokens.
    /// @param _tokenAddress Token address for which a derivative is being minted
    /// @param _distributionAddress The address to whom derived token is to be minted.
    /// @param _distributionAmount The amount of derived assets to be minted.
    /// @param _wrappedTokenAddress The address of the derived asset which is to be minted.
    function _mintWrappedTokens(
        address _tokenAddress,
        address _distributionAddress,
        uint256 _distributionAmount,
        address _wrappedTokenAddress
    ) internal virtual returns (bool _flag) {
        assetLockedForDerivative[_tokenAddress][
            _wrappedTokenAddress
        ] += _distributionAmount;

        // Minting Wrapped ERC20 token
        ERC20Clone(_wrappedTokenAddress).mintbyControl(
            _distributionAddress,
            _distributionAmount
        );
        // _flag=true;
        _flag = (IERC20(_wrappedTokenAddress).totalSupply() ==
            assetLockedForDerivative[_tokenAddress][_wrappedTokenAddress]);
    }

    /// @notice Function called by derived asset contract when they are transferred.
    /// @param _from The address from which the token is being transferred.
    /// @param _to The address to which the token is being transferred.
    /// @param _amount The amount of tokens being transferred.
    function tokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external virtual {
        // This function can only be called by wrapped ERC20 token contract which are created by the controller
        require(
            derivativeAdrToActualAssetAdr[msg.sender] != address(0),
            "Not a valid wrapped token"
        );
        emit TransferWrapped(_from, msg.sender, _to, _amount);
    }

    /// @notice Using this function a user can withdraw vested tokens in return of derived tokens held by the user address after the vest time has passed
    /// @dev This function burns the derived erc20 tokens and then transfers the project tokens to the msg.sender
    /// @param _wrappedTokenAddress Takes the address of the derived token
    /// @param _amount The amount of derived tokens the user want to withdraw
    function withdrawToken(address _wrappedTokenAddress, uint256 _amount)
        external
        virtual
        noReentrant
    {
        isKilled();

        require(
            derivativeAdrToActualAssetAdr[_wrappedTokenAddress] != address(0),
            "Invalid Wrapped Token"
        );

        // Anyone other than Proposal Contract can't withdraw tokens if vest time has not passed.
        require(
            msg.sender == proposalContract ||
                vestingTimeOfTokenId[_wrappedTokenAddress] <= block.timestamp,
            "Cannot withdraw before vest time"
        );

        address _tokenAddress = derivativeAdrToActualAssetAdr[
            _wrappedTokenAddress
        ];

        //Transfer the Wrapped Token to the controller first.
        _safeTransferERC20(
            _wrappedTokenAddress,
            msg.sender,
            address(this),
            _amount
        );

        totalDerivativeForAsset[_tokenAddress] -= _amount;

        // Burning wrapped tokens
        ERC20Clone(_wrappedTokenAddress).burnbyControl(address(this), _amount);

        assetLockedForDerivative[_tokenAddress][
            _wrappedTokenAddress
        ] -= _amount;

        _safeTransferERC20(_tokenAddress, address(this), msg.sender, _amount);
        assert(
            IERC20(_tokenAddress).balanceOf(address(this)) >=
                totalDerivativeForAsset[_tokenAddress]
        );

        emit Withdraw(msg.sender, _amount, _wrappedTokenAddress);
    }

    /// @notice This function is used by _deployNewERC20 function to set Ticker and Name of the derived asset.
    /// @dev This function uses the TimestampToDateLibrary.
    /// @param _timestamp tiemstamp which needs to be converted to date.
    /// @return finalDate as a string which the timestamp represents.
    function _timestampToDate(uint256 _timestamp)
        internal
        pure
        returns (string memory finalDate)
    {
        // Converting timestamp to Date using timestampToDateLibrary
        _timestamp = (_timestamp / DAY) * DAY;
        uint256 year;
        uint256 month;
        uint256 day;
        (year, month, day) = TimestampToDateLibrary.timestampToDate(_timestamp);
        string memory mstring;

        // Converting month component to String
        if (month == 1) mstring = "Jan";
        else if (month == 2) mstring = "Feb";
        else if (month == 3) mstring = "Mar";
        else if (month == 4) mstring = "Apr";
        else if (month == 5) mstring = "May";
        else if (month == 6) mstring = "Jun";
        else if (month == 7) mstring = "Jul";
        else if (month == 8) mstring = "Aug";
        else if (month == 9) mstring = "Sep";
        else if (month == 10) mstring = "Oct";
        else if (month == 11) mstring = "Nov";
        else if (month == 12) mstring = "Dec";

        // Putting data on finalDate
        finalDate = string(
            abi.encodePacked(_uint2str(day), mstring, _uint2str(year))
        );
    }

    /// @notice This function is used by _timestampToDate function to convert number to string.
    /// @param _i an integer.
    /// @return str which is _i as string.
    function _uint2str(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + (j % 10)));
            j /= 10;
        }
        str = string(bstr);
    }
}

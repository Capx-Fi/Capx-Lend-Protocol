// SPDX-License-Identifier: Unlicenced
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

pragma solidity 0.8.4;

interface MasterInterface {
    // checks for valid stable coins
    function stableCoins(address _token) external view returns (bool);

    // returns health factor of a loan
    function healthFactor(uint256 _loanID) external view returns (uint256);

    // returns the loan repayment amount
    function loanRepaymentAmount(uint256 _loanID)
        external
        view
        returns (uint256);

    // returns liquidation amount
    function liquidationAmount(uint256 _loanID)
        external
        view
        returns (uint256, uint256);

    // returns wvt amount equivalent to the stablecoin amount given using the oracle
    function wvtAmountCalculation(
        uint256 _stableCoinAmount,
        address _wvtAddress,
        address _stableCoinAddress,
        uint96 _loanToValue,
        uint96 _discount
    ) external view returns (uint256);

    // returns stablecoin amount equivalent to the stablecoin amount given using the oracle
    function stablecoinAmountCalculation(
        uint256 _wvtAmount,
        address _wvtAddress,
        address _stableCoinAddress,
        uint96 _loanToValue,
        uint96 _discount
    ) external view returns (uint256);

    // returns if an address is a valid WVT address
    function getValidWvt(address _wvtAddress) external view returns (bool);

    function pullFailurePeanlty(uint256 _loanID)
        external
        view
        returns (uint256);
}

pragma solidity 0.8.4;

interface NFTInterface {
    function mintLoanNFT(uint256 _tokenID, address _lender) external;

    function burnLoanNFT(uint256 _tokenID) external;

    function ownerOf(uint256 _tokenID) external returns (address);
}

pragma solidity 0.8.4;

contract Lend is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public loanID;
    address public master;
    address public lendnft;
    uint256 internal constant DAY = 86400;
    struct loanDetails1 {
        address wvtAddress; // address of collat
        uint96 interestRate; // interest rate
        address stablecoinAddress; // lend asset address
        uint96 loanToValue; // LTV
        address lenderAddress; // address of lender giving out stablecoin as loan
        uint96 discount; // discount at which the collat value is assessed
        address borrowerAddress; // address putting out the loan in the market
        uint96 liquidationThreshold; // LT
    }

    struct loanDetails2 {
        uint256 endTime; // when will the loan time ends(will be duration at the start)
        uint256 initiationTime; // when the loan gets accepted by a lender
        uint256 wvtAmount; // amount of collat
        uint256 stablecoinAmount; // amount of lending asset
        bool externalLiquidation; // boolean if external liquidation is allowed
        uint8 stageOfLoan; // 1 for init by borrower, 2 for init by lender, 3 for accepted by lender - ready to pull asset, 4 for accepted by borrower or borrower pulled asset - start of loan, Map will be deleted on complition
    }

    mapping(uint256 => loanDetails1) public loanBook1;
    mapping(uint256 => loanDetails2) public loanBook2;

    event CreateLoan(
        uint256 loanID,
        address collateralAddress,
        address stableCoin,
        bool borrower,
        uint256 amount,
        uint96 interestrate,
        uint96 ltv,
        uint96 lt,
        uint256 duration,
        uint96 discount,
        bool externalLiquidate
    );

    event AcceptLoan(
        uint256 loanID,
        bool externalLiquidation,
        uint256 wvtAmount,
        uint256 stableCoinAmount,
        uint256 initiationTime
    );

    event CancelLoan(uint256 loanID);

    event PullAsset(uint256 loanID, uint256 initiationTime);

    event LiquidateLoan(
        uint256 loanID,
        uint256 stableContractAmount,
        uint256 stablePushAmount
    );

    event RepayLoan(uint256 loanID);

    function initialize(address _master, address _nft) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        master = _master;
        lendnft = _nft;
        loanID = 0;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    /// @notice Using this function a user can create new loan
    /// @dev Transfers ERC20 token from lender or borrower depending on who initiates loan
    /// @param _collateralAddress Address of the collateral token
    /// @param _stablecoinAddress Address of the lending token
    /// @param _borrower boolean if the msg.sender is borrower or lender
    /// @param _amount amount of token user want to lend or borrow
    /// @param _interestRate interest rate charged
    /// @param _loanToValue loan to value percentage
    /// @param _liquidationThreshold liquidation percentage
    /// @param _duration duration of the loan
    /// @param _externalLiquidate If lender is calling he can specify if external party can liquidate or not
    function createLoan(
        address _collateralAddress,
        address _stablecoinAddress,
        bool _borrower,
        uint256 _amount,
        uint96 _interestRate,
        uint96 _loanToValue,
        uint96 _liquidationThreshold,
        uint256 _duration,
        uint96 _discount,
        bool _externalLiquidate
    ) external virtual nonReentrant whenNotPaused {
        loanID += 1;

        _duration = (_duration / DAY) * DAY;
        require(
            _liquidationThreshold >= _loanToValue &&
                MasterInterface(master).getValidWvt(_collateralAddress) &&
                MasterInterface(master).stableCoins(_stablecoinAddress) &&
                _interestRate <= 10000 &&
                _liquidationThreshold <= 10000 &&
                _amount != 0 &&
                _duration != 0,
            "Invalid Input"
        );
        IERC20Upgradeable(_borrower ? _collateralAddress : _stablecoinAddress)
            .safeTransferFrom(msg.sender, address(this), _amount);

        loanBook1[loanID] = loanDetails1(
            _collateralAddress,
            _interestRate,
            _stablecoinAddress,
            _loanToValue,
            !_borrower ? msg.sender : address(0),
            _discount,
            _borrower ? msg.sender : address(0),
            _liquidationThreshold
        );

        loanBook2[loanID] = loanDetails2(
            _duration,
            0,
            _borrower ? _amount : 0, // wvt amount
            !_borrower ? _amount : 0, // stable coin amount
            !_borrower ? _externalLiquidate : false, // external liquidatoin bool
            _borrower ? 1 : 2 // state of loan
        );

        emit CreateLoan(
            loanID,
            _collateralAddress,
            _stablecoinAddress,
            _borrower,
            _amount,
            _interestRate,
            _loanToValue,
            _liquidationThreshold,
            _duration,
            _discount,
            _externalLiquidate
        );
    }

    /// @notice Using this function a user can cancel loan if not accepted
    /// @dev Returns back the asset of loans cancelled
    /// @param _loanID ID of the loan to be cancelled
    function cancelLoan(uint256 _loanID)
        external
        virtual
        nonReentrant
        whenNotPaused
    {
        address _initiator = loanBook2[_loanID].stageOfLoan == 1
            ? loanBook1[_loanID].borrowerAddress
            : loanBook1[_loanID].lenderAddress;

        require(
            msg.sender == _initiator &&
                (loanBook2[_loanID].stageOfLoan == 1 ||
                    loanBook2[_loanID].stageOfLoan == 2),
            "invalid canceller"
        );

        IERC20Upgradeable(
            loanBook2[_loanID].stageOfLoan == 1
                ? loanBook1[_loanID].wvtAddress
                : loanBook1[_loanID].stablecoinAddress
        ).transfer(
                _initiator,
                loanBook2[_loanID].stageOfLoan == 1
                    ? loanBook2[_loanID].wvtAmount
                    : loanBook2[_loanID].stablecoinAmount
            );
        deleteMaps(_loanID);
        emit CancelLoan(_loanID);
    }

    /// @notice Using this function a user can accept already made loan in the market
    /// @dev Acceptance of loan and management of assets
    /// @param _loanID ID of the loan to be accepted
    /// @param _externalLiquidation boolean flag to set external liquidation if the loan accepted by lender
    function acceptLoan(uint256 _loanID, bool _externalLiquidation)
        external
        virtual
        nonReentrant
        whenNotPaused
    {
        loanDetails2 memory _loanEntity2 = loanBook2[_loanID];
        require(
            _loanEntity2.stageOfLoan == 2 || _loanEntity2.stageOfLoan == 1,
            "Invalid"
        );

        uint256 _currentTime = (block.timestamp / DAY) * DAY;

        if (_loanEntity2.stageOfLoan == 2) {
            require(msg.sender != loanBook1[_loanID].lenderAddress, "Invalid");
            _loanEntity2.wvtAmount = MasterInterface(master)
                .wvtAmountCalculation(
                    _loanEntity2.stablecoinAmount,
                    loanBook1[_loanID].wvtAddress,
                    loanBook1[_loanID].stablecoinAddress,
                    loanBook1[_loanID].loanToValue,
                    loanBook1[_loanID].discount
                );
            // add duration to current time
            _loanEntity2.initiationTime = _currentTime;
            _loanEntity2.stageOfLoan = 4;
            loanBook1[_loanID].borrowerAddress = msg.sender;
            // Asset Transfer
            IERC20Upgradeable(loanBook1[_loanID].wvtAddress).transferFrom(
                msg.sender,
                address(this),
                _loanEntity2.wvtAmount
            );
            IERC20Upgradeable(loanBook1[_loanID].stablecoinAddress).transfer(
                msg.sender,
                _loanEntity2.stablecoinAmount
            );
            NFTInterface(lendnft).mintLoanNFT(_loanID, loanBook1[_loanID].lenderAddress);
            // update the endTime
            _loanEntity2.endTime =
                _loanEntity2.initiationTime +
                _loanEntity2.endTime;
        } else {
            require(
                msg.sender != loanBook1[_loanID].borrowerAddress,
                "Invalid"
            );
            _loanEntity2.externalLiquidation = _externalLiquidation;
            _loanEntity2.stablecoinAmount = MasterInterface(master)
                .stablecoinAmountCalculation(
                    _loanEntity2.wvtAmount,
                    loanBook1[_loanID].wvtAddress,
                    loanBook1[_loanID].stablecoinAddress,
                    loanBook1[_loanID].loanToValue,
                    loanBook1[_loanID].discount
                );
            _loanEntity2.initiationTime = block.timestamp + DAY;
            _loanEntity2.stageOfLoan = 3;
            loanBook1[_loanID].lenderAddress = msg.sender;
            // Asset Transfer
            IERC20Upgradeable(loanBook1[_loanID].stablecoinAddress)
                .transferFrom(
                    msg.sender,
                    address(this),
                    _loanEntity2.stablecoinAmount
                );
        }

        loanBook2[_loanID] = _loanEntity2;
        emit AcceptLoan(
            _loanID,
            _externalLiquidation,
            _loanEntity2.wvtAmount,
            _loanEntity2.stablecoinAmount,
            _loanEntity2.initiationTime
        );
    }

    /// @notice Using this function a borrower can pull his assets after acceptance by lender
    /// @dev Borrower has 1 day to do so
    /// @param _loanID ID of the loan to be pulled assets from
    function pullAssets(uint256 _loanID)
        external
        virtual
        nonReentrant
        whenNotPaused
    {
        if (loanBook2[_loanID].initiationTime >= block.timestamp) {
            require(
                loanBook2[_loanID].stageOfLoan == 3 &&
                    msg.sender == loanBook1[_loanID].borrowerAddress,
                "Invalid"
            );
            loanBook2[_loanID].stageOfLoan = 4;
            // set the initiation time and end time according to today
            loanBook2[_loanID].initiationTime = (block.timestamp / DAY) * DAY;
            // update the endTime
            loanBook2[_loanID].endTime =
                loanBook2[_loanID].initiationTime +
                loanBook2[_loanID].endTime;
            IERC20Upgradeable(loanBook1[_loanID].stablecoinAddress).transfer(
                msg.sender,
                loanBook2[_loanID].stablecoinAmount
            );
            NFTInterface(lendnft).mintLoanNFT(
                _loanID,
                loanBook1[_loanID].lenderAddress
            );
        } else {
            require(
                loanBook2[_loanID].stageOfLoan == 3 &&
                    (msg.sender == loanBook1[_loanID].borrowerAddress ||
                        msg.sender == loanBook1[_loanID].lenderAddress),
                "Invalid"
            );
            // here one is still push
            
            uint256 _wvtToLender = MasterInterface(master).pullFailurePeanlty(
                _loanID
            );

            IERC20Upgradeable(loanBook1[_loanID].stablecoinAddress).transfer(
                loanBook1[_loanID].lenderAddress,
                loanBook2[_loanID].stablecoinAmount
            );
            IERC20Upgradeable(loanBook1[_loanID].wvtAddress).transfer(
                loanBook1[_loanID].borrowerAddress,
                loanBook2[_loanID].wvtAmount - _wvtToLender
            );

            IERC20Upgradeable(loanBook1[_loanID].wvtAddress).transfer(
                loanBook1[_loanID].lenderAddress,
                _wvtToLender
            );

            deleteMaps(_loanID);
        }
        // loanBook2[_loanID].initiationTime will be 0 in case of asset return after failure to pull assets on time
        emit PullAsset(_loanID, loanBook2[_loanID].initiationTime);
    }

    /// @notice Using this function a borrower can repay his loan
    /// @dev Repayment amount is calculated depending on the day of repayment
    /// @param _loanID ID of the loan to be repayed
    function repaymentLoan(uint256 _loanID)
        external
        virtual
        nonReentrant
        whenNotPaused
    {
        require(msg.sender == loanBook1[_loanID].borrowerAddress, "Invalid");
        // remaining requires handled by master

        // trasnfer lend asset with interest to lender
        // again push is implemented here - acceptable
        IERC20Upgradeable(loanBook1[_loanID].stablecoinAddress)
            .safeTransferFrom(
                msg.sender,
                NFTInterface(lendnft).ownerOf(_loanID),
                MasterInterface(master).loanRepaymentAmount(_loanID)
            );

        // transfer collateral to borrower
        IERC20Upgradeable(loanBook1[_loanID].wvtAddress).safeTransfer(
            loanBook1[_loanID].borrowerAddress,
            loanBook2[_loanID].wvtAmount
        );

        NFTInterface(lendnft).burnLoanNFT(_loanID);
        deleteMaps(_loanID);
        emit RepayLoan(_loanID);
    }

    /// @notice Using this function a user can liquidate defaulted asset or lender can get his collateral
    /// @dev Liquidates a loan
    /// @param _loanID ID of the loan to be liquidated
    function liquidation(uint256 _loanID)
        external
        virtual
        nonReentrant
        whenNotPaused
    {
        // we can move these require also to master
        require(
            (loanBook2[_loanID].endTime < ((block.timestamp / DAY) * DAY) ||
                MasterInterface(master).healthFactor(_loanID) == 0) &&
                loanBook2[_loanID].stageOfLoan == 4 &&
                loanBook1[_loanID].borrowerAddress != msg.sender,
            "Not Defaulted"
        );

        address _lender = NFTInterface(lendnft).ownerOf(_loanID);
        NFTInterface(lendnft).burnLoanNFT(_loanID);
        if (msg.sender == _lender) {
            IERC20Upgradeable(loanBook1[_loanID].wvtAddress).safeTransfer(
                _lender,
                loanBook2[_loanID].wvtAmount
            );
            emit LiquidateLoan(_loanID, 0, 0);
            deleteMaps(_loanID);
            return;
        }
        require(loanBook2[_loanID].externalLiquidation, "Not allowed");
        IERC20Upgradeable(loanBook1[_loanID].wvtAddress).safeTransfer(
            msg.sender,
            loanBook2[_loanID].wvtAmount
        );

        (uint256 transfer1, uint256 transfer2) = MasterInterface(master)
            .liquidationAmount(_loanID);

        IERC20Upgradeable(loanBook1[_loanID].stablecoinAddress)
            .safeTransferFrom(msg.sender, address(this), transfer1);
        // this is also push
        IERC20Upgradeable(loanBook1[_loanID].stablecoinAddress).safeTransfer(
            _lender,
            transfer2
        );

        deleteMaps(_loanID);
        emit LiquidateLoan(_loanID, transfer1, transfer2);
    }

    /// @notice Deletes mapping entries for gas refund
    /// @dev Reduces transaction costs
    /// @param _loanID ID of the loan to be removed from mapping can only be called internally
    function deleteMaps(uint256 _loanID) internal {
        delete loanBook1[_loanID];
        delete loanBook2[_loanID];
    }
}

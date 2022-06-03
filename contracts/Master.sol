// SPDX-License-Identifier: Unlicenced
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./Lend.sol";

pragma solidity 0.8.4;

interface TokenDecimal {
    function decimals() external view returns (uint8);
}

pragma solidity 0.8.4;

interface LiquidInterface {
    function derivativeAdrToActualAssetAdr(address _wvt)
        external
        view
        returns (address);
}

pragma solidity 0.8.4;

interface OracleFeed {
    function priceFeed(address _token) external view returns (uint256);

    function getPrice(address _wvt) external view returns (uint256, uint256);
}

pragma solidity 0.8.4;

contract Master is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint96 public penalty;
    address public oracle;
    address public lend;
    address public controller;
    uint256 internal constant DAY = 86400;

    mapping(address => bool) public stableCoins; // allowed stable coins

    function initialize(address _oracle, uint96 _penalty) public initializer {
        require(_oracle != address(0), "Zero address check");
        require(_penalty <= 10000, "Penalty cannot be more than 100%");
        __Ownable_init();
        __ReentrancyGuard_init();
        oracle = _oracle;
        penalty = _penalty;
    }

    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    function setLendContract(address _lend) external virtual onlyOwner {
        lend = _lend;
    }

    function setController(address _controller) external virtual onlyOwner {
        controller = _controller;
    }

    // adding and removing eligible stable coins
    function addStable(address[] memory _stableCoins, bool[] memory _state)
        external
        virtual
        onlyOwner
    {
        require(_stableCoins.length == _state.length, "Inconsistent");
        for (uint256 index = 0; index < _stableCoins.length; index++) {
            require(_stableCoins[index] != address(0), "Empty address");
            stableCoins[_stableCoins[index]] = _state[index];
        }
    }

    function setPenalty(uint96 _newPenalty) external virtual onlyOwner {
        require(_newPenalty <= 10000, "Penalty cannot be more than 100%");
        penalty = _newPenalty;
    }

    function healthFactor(uint256 _loan) public view returns (uint256) {
        (
            address wvtAddress, // address of collat // interest rate // lend asset address // LTV // address of lender giving out stablecoin as loan
            ,
            address stablecoinAddress, // address of stable coin
            ,
            ,
            uint96 discount, // discount at which the collat value is assessed // address putting out the loan in the market
            ,
            uint96 liquidationThreshold // LT
        ) = Lend(lend).loanBook1(_loan);

        (
            ,
            ,
            // when will the loan time ends(will be duration at the start)
            // when the loan gets accepted by a lender
            uint256 wvtAmount, // amount of collat
            uint256 stablecoinAmount, // amount of lending asset // boolean if external liquidation is allowed // 1 for init by borrower, 2 for init by lender, 3 for accepted by lender, 4 for accepted by borrower,5 for pulled by borrower // if asset needs to be repayed in WVTs    // LT
            ,

        ) = Lend(lend).loanBook2(_loan);

        (uint256 _oracleVal, uint256 _oracleDec) = OracleFeed(oracle).getPrice(
            wvtAddress
        );

        uint256 _colat_value = (_oracleVal *
            (10**TokenDecimal(stablecoinAddress).decimals()) *
            wvtAmount *
            discount) /
            (10000 *
                (10**_oracleDec) *
                (10**TokenDecimal(wvtAddress).decimals()));

        uint256 _healthFactor = (_colat_value * liquidationThreshold) /
            (10000 * stablecoinAmount);

        return _healthFactor;
    }

    function loanRepaymentAmount(uint256 _loan) public view returns (uint256) {
        uint256 currentTime = (block.timestamp / DAY) * DAY;

        (
            ,
            // address of collat
            uint96 interestRate, // interest rate // lend asset address // LTV // address of lender giving out stablecoin as loan // discount at which the collat value is assessed // address putting out the loan in the market // LT
            ,
            ,
            ,
            ,
            ,

        ) = Lend(lend).loanBook1(_loan);

        (
            uint256 endTime, // when will the loan time ends(will be duration at the start)
            uint256 initiationTime, // when the loan gets accepted by a lender // amount of collat
            ,
            uint256 stablecoinAmount, // amount of lending asset // boolean if external liquidation is allowed
            ,
            uint8 stageOfLoan // 1 for init by borrower, 2 for init by lender, 3 for accepted by lender, 4 for accepted by borrower,5 for pulled by borrower // if asset needs to be repayed in WVTs    // LT
        ) = Lend(lend).loanBook2(_loan);

        require(stageOfLoan == 4 && currentTime <= endTime, "Invalid");
        // First cut of interest which is of full rate
        uint256 interest1 = (stablecoinAmount *
            interestRate *
            (currentTime - initiationTime)) / (10000 * 86400 * 365);
        // // Second cut of interest which is of full rate * Penalty percentage
        uint256 interest2 = (stablecoinAmount *
            interestRate *
            (endTime - currentTime) *
            penalty) / (100000000 * 86400 * 365);

        // total sum includes principal + interest1 + interest2
        uint256 totalSumToReturn = interest1 + interest2 + stablecoinAmount;

        return (totalSumToReturn);
    }

    function liquidationAmount(uint256 _loan)
        public
        view
        returns (uint256, uint256)
    {
        (
            address wvtAddress, // address of collat // interest rate // lend asset address // LTV // address of lender giving out stablecoin as loan
            ,
            address stablecoinAddress, // address of stable coin
            ,
            ,
            uint96 discount, // discount at which the collat value is assessed // address putting out the loan in the market // LT
            ,

        ) = Lend(lend).loanBook1(_loan);

        (
            ,
            ,
            // when will the loan time ends(will be duration at the start)
            // when the loan gets accepted by a lender
            uint256 wvtAmount, // amount of collat
            uint256 stablecoinAmount, // amount of lending asset // boolean if external liquidation is allowed // 1 for init by borrower, 2 for init by lender, 3 for accepted by lender, 4 for accepted by borrower,5 for pulled by borrower // if asset needs to be repayed in WVTs    // LT
            ,

        ) = Lend(lend).loanBook2(_loan);

        (uint256 _oracleVal, uint256 _oracleDec) = OracleFeed(oracle).getPrice(
            wvtAddress
        );

        // we need to multiply discount here also
        uint256 stablePriceForContract = (_oracleVal *
            (10**TokenDecimal(stablecoinAddress).decimals()) *
            wvtAmount *
            discount) /
            (10000 *
                (10**_oracleDec) *
                (10**TokenDecimal(wvtAddress).decimals()));

        if (stablePriceForContract > stablecoinAmount) {
            return (stablePriceForContract, stablecoinAmount);
        } else {
            return (stablePriceForContract, stablePriceForContract);
        }
    }

    // Specific Example :
    // Example as ETH
    // ((value retuned by oracle)*(decimal of stable coin))/(10**8) StableTokenBaseUnit will be returned for 10**18 wei
    // so for 1wei = ((value retuned by oracle)*(decimal of stable coin))/((10**8)(10**decimal of asset))
    //
    // now 1 lastunitofstable = ((10**8)(10**decimal of asset))/((value retuned by oracle)*(decimal of stable coin))

    function wvtAmountCalculation(
        uint256 _stableCoinAmount,
        address _wvtAddress,
        address _stableCoinAddress,
        uint96 _loanToValue,
        uint96 _discount
    ) public view returns (uint256) {
        (uint256 _oracleVal, uint256 _oracleDec) = OracleFeed(oracle).getPrice(
            _wvtAddress
        );

        uint256 result = (_stableCoinAmount *
            100000000 *
            (10**_oracleDec) *
            (10**TokenDecimal(_wvtAddress).decimals())) /
            (_oracleVal *
                (10**TokenDecimal(_stableCoinAddress).decimals()) *
                _loanToValue *
                _discount);
        return (result);
    }

    function stablecoinAmountCalculation(
        uint256 _wvtAmount,
        address _wvtAddress,
        address _stableCoinAddress,
        uint96 _loanToValue,
        uint96 _discount
    ) public view returns (uint256) {
        (uint256 _oracleVal, uint256 _oracleDec) = OracleFeed(oracle).getPrice(
            _wvtAddress
        );

        uint256 result = (_oracleVal *
            (10**TokenDecimal(_stableCoinAddress).decimals()) *
            _wvtAmount *
            _loanToValue *
            _discount) /
            (100000000 *
                (10**_oracleDec) *
                (10**TokenDecimal(_wvtAddress).decimals()));

        return (result);
    }

    function getValidWvt(address _wvt) external view returns (bool) {
        return (
            LiquidInterface(controller).derivativeAdrToActualAssetAdr(
                _wvt
            ) == address(0)
                ? false
                : true
        );
    }

    function pullFailurePeanlty(uint256 _loanID)
        external
        view
        returns (uint256)
    {
        (
            address wvtAddress, // address of collat // interest rate // lend asset address // LTV // address of lender giving out stablecoin as loan
            uint96 interestRate,
            address stablecoinAddress, // address of stable coin
            ,
            ,
            uint96 discount, // discount at which the collat value is assessed // address putting out the loan in the market // LT
            ,

        ) = Lend(lend).loanBook1(_loanID);

        (
            ,
            uint256 initiationTime,
            // when will the loan time ends(will be duration at the start)
            // when the loan gets accepted by a lender
            uint256 wvtAmount, // amount of collat
            uint256 stablecoinAmount, // amount of lending asset // boolean if external liquidation is allowed // 1 for init by borrower, 2 for init by lender, 3 for accepted by lender, 4 for accepted by borrower,5 for pulled by borrower // if asset needs to be repayed in WVTs    // LT
            ,

        ) = Lend(lend).loanBook2(_loanID);

        uint256 _currentTime = (block.timestamp / DAY) * DAY;

        // do we need to include the ongoing day as interest penalty

        // corresponding wvt calculation should be on the oracle price or loan's derivative to stable coin ratio

        // implemented the second part as of now
        uint256 stableCoinPenalty = (stablecoinAmount *
            interestRate *
            (_currentTime - initiationTime + 2 * DAY)) / (10000 * 86400 * 365);
        // uint256 correspondingWVT;
        // if(stableCoinPenalty<stablecoinAmount){
        //     correspondingWVT = stableCoinPenalty * wvtAmount / stablecoinAmount;
        // }else{
        //     correspondingWVT = wvtAmount;
        // }
        (uint256 _oracleVal, uint256 _oracleDec) = OracleFeed(oracle).getPrice(
            wvtAddress
        );

        uint256 correspondingWVT = (stableCoinPenalty *
            10000 *
            (10**_oracleDec) *
            (10**TokenDecimal(wvtAddress).decimals())) /
            (_oracleVal *
                (10**TokenDecimal(stablecoinAddress).decimals()) *
                discount);
        if (correspondingWVT > wvtAmount) {
            correspondingWVT = wvtAmount;
        }
        return (correspondingWVT);
    }
}

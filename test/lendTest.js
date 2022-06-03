const { default: BigNumber } = require("bignumber.js");
const { assert } = require("console");
const { report } = require("process");
const Controller = artifacts.require("Controller");
const model = artifacts.require("ERC20CloneContract");
const factoryContract = artifacts.require("ERC20Factory");
const Lend = artifacts.require("Lend");
const Oracle = artifacts.require("Oracle");
const OracleFeed = artifacts.require("AggregatorV3Interface");
const helper = require('../utils');
const ERC20test = artifacts.require("ERC20Test");
const LendNFT = artifacts.require("LendNFT");
const TimeTest = artifacts.require("Time");

const Master = artifacts.require("Master");

contract('Testing Lend Contract', (accounts) => {
    var lend;
    var testERC20;
    var testERC20Derivative;
    var testERC20StableCoin;
    var testERC20StableCoin2;
    var controllerInstance;
    var master;
    var lendNFTInstance;

    var _loan_id = 1;
    var _lender_loan_id = 1;

    // Loan values
    var _amount =  "1000000";
    var _ltv =  "5000";
    var _rate_of_interest = "1000";
    var _liquidation_threshold =  "6000";
    var _expiry_time = "86400";
    //var _lender_asset_amount = "10000";
    var _discount = "7000";
    var _liquidation_flag = true;
    var _borrower = true;
    var _external_liquidate = true;
    var _repayment_by_wvt = true;
    let timeTest;
    let currentTime;
    let derivedAssetAddress1;
    let derivedAssetAddress2;
    let derivedAssetAddress3;

    async function get_balance(token_instance, _address) {
        let value = await token_instance.balanceOf(_address);
        return(BigNumber(value));
        // expected output: "resolved"
    }

    it('Deployed LendSingle', async() => {

        oracleFeedInstance = await OracleFeed.new();

        await oracleFeedInstance.updateFeedDecimalAndVersion("8","3");

        await oracleFeedInstance.updateFeedData("36893488147419115317","281560000000","1650873608","1650873616","36893488147419115317");

        oracleInstance = await Oracle.deployed();
        lend = await Lend.deployed();
        master = await Master.deployed();
        lendNFTInstance = await LendNFT.deployed();
        timeTest = await TimeTest.new();
        controllerInstance = await Controller.new();
        await console.log("Controller address : ", controllerInstance.address)

        let erc20model = await model.new();
        let erc20factory = await factoryContract.new(erc20model.address, controllerInstance.address);
        await controllerInstance.setFactory(erc20factory.address);
        assert(controllerInstance.address !== '', "Contract was deployed");
        master.setController(controllerInstance.address)
        oracleInstance.setController(controllerInstance.address)
        // // New token creation
        testERC20 = await ERC20test.new("TET", "18", "100000000000000000000000000");
        await oracleInstance.updateAssetFeed(testERC20.address,oracleFeedInstance.address);

        testERC20StableCoin = await ERC20test.new("StableToken","ST","100000000000000000000000000");
        testERC20StableCoin2 = await ERC20test.new("StableToken2","ST2","100000000000000000000000000");

        // Updating tokens in oracle
        await oracleFeedInstance.updateFeedData("36893488147419115317","20000000000","1650873608","1650873616","36893488147419115317");
        await lendNFTInstance.setController(lend.address);
    });
    
    it('Vesting tokens for the first time', async () => {

        var a1 = []
        var a2 = []
        var a3 = []
        var a4 = []
        const erc20 = testERC20;
        await erc20.approve(controllerInstance.address, "40000000000000000000", {
            from: accounts[0]
        });
        let kp = 1903336242 //  25 April 2030
        await a1.push(accounts[0]);
        await a2.push(kp.toString());
        await a3.push("10000000000000000000")
        await a4.push(true)
        await a1.push(accounts[0]);
        await a2.push(kp.toString());
        await a3.push("10000000000000000000")
        await a4.push(true)
        kp += 86400
        await a1.push(accounts[0]);
        await a2.push(kp.toString());
        await a3.push("10000000000000000000")
        await a4.push(true)
        kp += 86400
        await a1.push(accounts[0]);
        await a2.push(kp.toString());
        await a3.push("10000000000000000000")
        await a4.push(true)

        await controllerInstance.createBulkDerivative("name", "QmVcrjMQVhdCEnmCs78x4MaiLSBgnvygaXLT5nH9YFsvi7", erc20.address, "40000000000000000000", a1, a2, a3, a4, {
            from: accounts[0]
        });

        derivedAssetAddress1 = await controllerInstance.derivativeIDtoAddress("1").then(function(response) {
            return (response.toString(10))
        })
        testERC20Derivative = await ERC20test.at(derivedAssetAddress1)
        derivedAssetAddress2 = await controllerInstance.derivativeIDtoAddress("2").then(function(response) {
            return (response.toString(10))
        })
        derivedAssetAddress3 = await controllerInstance.derivativeIDtoAddress("3").then(function(response) {
            return (response.toString(10))
        })
    });

    it('Invalid Case: Add Stable coins', async() => {
        // Invalid Case: Add Stable coins with 0 address
        try {
            await master.addStable(
                ["0x0000000000000000000000000000000000000000"],[true]
            );
        } catch (error) {
            await assert(error.message.includes("Empty address"))
        }

        // Invalid Case: Add Stable coins with wrong parameters
        try {
            await master.addStable(
                [testERC20StableCoin.address],[]
            );
        } catch (error) {
            await assert(error.message.includes("Inconsistent"))
        }
    });

    it('Add Stable coins for borrowing', async() => {
        // Add Stable coins
        await master.addStable(
            [testERC20StableCoin.address],[true]
        );
        await master.stableCoins(testERC20StableCoin.address).then((response)=>{
            assert(
                response == true
            );
        })
    });

    it('Invalid Case: Setting penalty', async() => {
        // Invalid Case: Adding penalty more than 100%
        try {
            await master.setPenalty(
                1000000
            );
        } catch (error) {
            await assert(error.message.includes("Penalty cannot be more than 100%"))
        }
    });

    it('Setting penalty for early liquidation', async() => {
        // Add Stable coins
        await master.setPenalty(
            1000
        );
        await master.penalty().then((response)=>{
            assert(
                response == 1000
            );
        })
    });

    it('Invalid inputs while creating order', async() => {
        // interest rate is more than 100%
        var _updated_rate_of_interest = 100001;
        // LT is more than TLV
        var _updated_liquidation_threshold = 4000;
        // End time is less than current block time
        var _updated_expiry_time = "164758688";
        // LTV is more than 100%
        var _updated_ltv = 10001;
        // collateral Amount cannot be 0
        var _updated_collateralAmount = 0;
        var _updated_borrower = false;
        var _updated_amount = 0;

        // negative case: interest rate is more than 100
        try {
            await lend.createLoan(
                // testERC20.address,
                derivedAssetAddress1,
                testERC20StableCoin.address,
                _borrower,
                _amount,
                _updated_rate_of_interest,
                _ltv,
                _liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("Invalid Input"))
        }

        // negative case: liquidation threshold is less than LTV
        try {
            await lend.createLoan(
                // testERC20.address,
                derivedAssetAddress1,
                testERC20StableCoin.address,
                _borrower,
                _amount,
                _rate_of_interest,
                _ltv,
                _updated_liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("Invalid Input"))
        }

        // negative case: LTV is more than 100%
        try {
            var _new_liquidation_threshold = 100010;
            await lend.createLoan(
                // testERC20.address,
                derivedAssetAddress1,
                testERC20StableCoin.address,
                _borrower,
                _amount,
                _rate_of_interest,
                _updated_ltv,
                _new_liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("Invalid Input"))
        }

        // negative case: Collateral is more than 100%
        try {
            var _new_liquidation_threshold = 100010;
            await lend.createLoan(
                // testERC20.address,
                derivedAssetAddress1,
                testERC20StableCoin.address,
                _borrower,
                _amount,
                _rate_of_interest,
                _ltv,
                _new_liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("Invalid Input"))
        }

        // negative case: Collateral amount is 0
        try {
            await lend.createLoan(
                // testERC20.address,
                derivedAssetAddress1,
                testERC20StableCoin.address,
                _borrower,
                _updated_amount,
                _rate_of_interest,
                _ltv,
                _liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("Invalid Input"))
        }

        // negative case: Lend Asset Address is 0
        try {
            await lend.createLoan(
                // testERC20.address,
                derivedAssetAddress1,
                "0x0000000000000000000000000000000000000000",
                _borrower,
                _amount,
                _rate_of_interest,
                _ltv,
                _liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("Invalid Input"))
        }

        // negative case: Collateral Address is 0
        try {
            
            await lend.createLoan(
                "0x0000000000000000000000000000000000000000",
                testERC20StableCoin.address,
                _borrower,
                _amount,
                _rate_of_interest,
                _ltv,
                _liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("Invalid Input"))
        }

        // negative case: Stable coin not whitelisted in master contract
        try {
            
            await lend.createLoan(
                // testERC20.address,
                derivedAssetAddress1,
                testERC20StableCoin2.address,
                _borrower,
                _amount,
                _rate_of_interest,
                _ltv,
                _liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("Invalid Input"))
        }

        // negative case: Stable coin and collateral address are same
        try {
            
            await lend.createLoan(
                testERC20StableCoin2.address,
                testERC20StableCoin2.address,
                _borrower,
                _amount,
                _rate_of_interest,
                _ltv,
                _liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("Invalid Input"))
        }

        // negative case: Create order without approval
        try {
            await lend.createLoan(
                // testERC20.address,
                derivedAssetAddress1,
                testERC20StableCoin.address,
                _borrower,
                _amount,
                _rate_of_interest,
                _ltv,
                _liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("ERC20: transfer amount exceeds allowance"))
        }
    });

    it('Create Order by borrower', async() => {
        // Checking if any loan is created
        await lend.loanBook1(_loan_id).then((response)=>{
            assert(response.borrowerAddress.toString(10)==="0x0000000000000000000000000000000000000000");
        })
        const erc20 = testERC20Derivative;
        const stable_erc20 = testERC20StableCoin;

        // Approving transfer of derivative tokens to single lend contract
        await erc20.approve(lend.address, "100000000", {
            from: accounts[0]
        });

        var initial_acc1_value = await get_balance(erc20, accounts[0])
        var initial_lend_cont_value = await get_balance(erc20, lend.address)

        await lend.createLoan(
            // testERC20.address,
            derivedAssetAddress1,
            testERC20StableCoin.address,
            _borrower,
            _amount,
            _rate_of_interest,
            _ltv,
            _liquidation_threshold,
            _expiry_time,
            _discount,
            _external_liquidate,
            // _repayment_by_wvt
        );

        var final_acc1_value = await get_balance(erc20, accounts[0]);
        var final_lend_cont_value = await get_balance(erc20, lend.address)
        var difference_acc1 = await initial_acc1_value.minus(final_acc1_value)
        var difference_lend_cont = await final_lend_cont_value.minus(initial_lend_cont_value)

        // checking the collateral amount being transferred from borrower to the contract
        assert (difference_acc1.toString(10) === _amount);
        assert (difference_lend_cont.toString(10) === _amount);
    
        await lend.loanBook1(_loan_id).then((response)=>{
            assert(
                // response.wvtAddress.toString(10) === (testERC20.address).toString(10) &&
                response.wvtAddress.toString(10) === (derivedAssetAddress1).toString(10) &&
                response.interestRate.toString(10) === _rate_of_interest &&
                response.stablecoinAddress.toString(10) ===  testERC20StableCoin.address &&
                response.loanToValue.toString(10)=== _ltv &&
                response.lenderAddress.toString(10) === "0x0000000000000000000000000000000000000000" &&
                response.borrowerAddress.toString(10) === accounts[0].toString(10) &&
                response.liquidationThreshold.toString(10) === _liquidation_threshold &&
                response.discount.toString(10) === _discount
            );
        })

        await lend.loanBook2(_loan_id).then((response)=>{
            assert(
                response.wvtAmount.toString(10)=== _amount &&
                response.stablecoinAmount.toString(10)=== "0" &&
                response.externalLiquidation === false &&
                response.stageOfLoan.toString(10) === "1"
                // response.repaymentByWVT === false
            );
        })
    });

    it('Create Order by lender', async() => {
        // Checking if any loan is created
        _loan_id +=1
        await lend.loanBook1(_loan_id).then((response)=>{
            assert(response.lenderAddress.toString(10)==="0x0000000000000000000000000000000000000000");
        })
        const erc20 = testERC20Derivative;
        const stable_erc20 = testERC20StableCoin;

        // Approving transfer of stable tokens to lend contract
        await testERC20StableCoin.approve(lend.address, "100000000", {
            from: accounts[0]
        });

        var initial_acc1_value = await get_balance(testERC20StableCoin, accounts[0])
        var initial_lend_cont_value = await get_balance(testERC20StableCoin, lend.address)

        await lend.createLoan(
            // testERC20.address,
            derivedAssetAddress1,
            testERC20StableCoin.address,
            false,
            _amount,
            _rate_of_interest,
            _ltv,
            _liquidation_threshold,
            _expiry_time,
            _discount,
            _external_liquidate,
            // _repayment_by_wvt
        );

        var final_acc1_value = await get_balance(testERC20StableCoin, accounts[0]);
        var final_lend_cont_value = await get_balance(testERC20StableCoin, lend.address)
        var difference_acc1 = await initial_acc1_value.minus(final_acc1_value)
        var difference_lend_cont = await final_lend_cont_value.minus(initial_lend_cont_value)

        // checking the collateral amount being transferred from borrower to the contract
        assert (difference_acc1.toString(10) === _amount);
        assert (difference_lend_cont.toString(10) === _amount);
    
        await lend.loanBook1(_loan_id).then((response)=>{
            assert(
                response.wvtAddress.toString(10) === (derivedAssetAddress1).toString(10) &&
                response.interestRate.toString(10) === _rate_of_interest &&
                response.stablecoinAddress.toString(10) ===  testERC20StableCoin.address &&
                response.loanToValue.toString(10)=== _ltv &&
                response.lenderAddress.toString(10) === accounts[0].toString(10) &&
                response.borrowerAddress.toString(10) === "0x0000000000000000000000000000000000000000" &&
                response.liquidationThreshold.toString(10) === _liquidation_threshold &&
                response.discount.toString(10) === _discount
            );
        })

        await lend.loanBook2(_loan_id).then((response)=>{
            assert(
                response.wvtAmount.toString(10)=== "0" &&
                response.stablecoinAmount.toString(10)=== _amount &&
                response.externalLiquidation === _external_liquidate &&
                response.stageOfLoan.toString(10) === "2"
                // response.repaymentByWVT === _repayment_by_wvt
            );
        })
    });

    it('Invalid case: Cancel Loan', async() => {
        // Invalid case: Cancelling a non-existant loan
        try {
            await lend.cancelLoan(
                100, {
                    from: accounts[0]
                }
            );
        } catch (error) {
            await assert(error.message.includes("invalid canceller"))
        }

        // Invalid case: Someone other than borrower cancelling the loan
        try {
            await lend.cancelLoan(
                _loan_id, {
                    from: accounts[1]
                }
            );
        } catch (error) {
            await assert(error.message.includes("invalid canceller"))
        }
    });

    it('Cancel Loan', async() => {
        // cancel loan request
        await lend.cancelLoan(
            1,
            {
                from: accounts[0]
            }
        );
        await lend.loanBook1(1).then((response)=>{
            assert(
                response.borrowerAddress === "0x0000000000000000000000000000000000000000",
                response.lenderAddress === "0x0000000000000000000000000000000000000000"
            );
        })
        await lend.loanBook2(1).then((response)=>{
            assert(
                response.wvtAmount.toString(10) === "0",
                response.endTime.toString(10) === "0"
            );
        })
    });

    it('Invalid case: Order fulfill, order created by lender', async() => {
        const erc20 = testERC20Derivative;
        // Invalid case: lender fulfilling loan
        try {
            await lend.acceptLoan(
                _loan_id,
                _liquidation_flag,
                {
                    from: accounts[0]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Invalid"))
        }

        // fulfilling order without appropriate balance
        try {
            await lend.acceptLoan(
                _loan_id,
                _liquidation_flag,
                {
                    from: accounts[1]
                }
            );
        } catch (error) {
            await assert(error.message.includes("ERC20: transfer amount exceeds balance"))
        }

        // fulfilling order that is already cancelled
        try {
            await lend.acceptLoan(
                1,
                _liquidation_flag,
                {
                    from: accounts[1]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Invalid"))
        }

        // transferring tokens to account 1
        await erc20.transfer(accounts[1], "1000000000000000000");
        // fulfilling order without approval
        try {
            await lend.acceptLoan(
                _loan_id,
                _liquidation_flag,
                {
                    from: accounts[1]
                }
            );
        } catch (error) {
            await assert(error.message.includes("ERC20: transfer amount exceeds allowance"))
        }
    });

    it('Fulfilling Loan Request, created by lender', async() => {
        const erc20 = testERC20Derivative;
        // Approving transfer of derivative tokens to single lend contract 1000000000000 1000000000000
        await erc20.approve(lend.address, "10000000000000", {
            from: accounts[1]
        });
        var initial_acc1_value = await get_balance(erc20, accounts[1]);
        var initial_acc1_stable_value = await get_balance(testERC20StableCoin, accounts[1]);
        var initial_lend_cont_value = await get_balance(erc20, lend.address)
        await oracleInstance.getPrice(derivedAssetAddress1).then((response)=>{
            _price = response["0"];
            _decimal = response["1"];
        })
        await lend.acceptLoan(
            _loan_id,
            _liquidation_flag,
            {
                from: accounts[1]
            }
        );

        var final_acc1_value = await get_balance(erc20, accounts[1]);
        var final_acc1_stable_value = await get_balance(testERC20StableCoin, accounts[1]);
        var final_lend_cont_value = await get_balance(erc20, lend.address)
        var difference_acc1 = await initial_acc1_value.minus(final_acc1_value)
        var difference_acc1_stable = await final_acc1_stable_value.minus(initial_acc1_stable_value)
        var difference_lend_cont = await final_lend_cont_value.minus(initial_lend_cont_value)

        var lend_asset_amount = (_amount * 100000000 * 10**_decimal * 10**18)/(_price * 10**18 * _ltv * _discount)

        await lend.loanBook1(_loan_id).then((response)=>{
            assert(
                response.borrowerAddress.toString(10) === accounts[1]
               );
        })

        await lend.loanBook2(_loan_id).then((response)=>{
            _lender_asset_amount = response.wvtAmount;
            assert(
                response.stageOfLoan.toString(10) === "4"
               );
        })

        // checking the loan amount being transferred from lender to borrower
        assert (difference_acc1.toString(10) === difference_lend_cont.toString(10));
        assert (difference_acc1.toString(10) === _lender_asset_amount.toString(10));
        assert (parseInt(lend_asset_amount).toString(10) === _lender_asset_amount.toString(10));
        assert (difference_acc1_stable.toString(10) === _amount.toString(10));
    });

    it('Fulfilling Loan Request, created by borrower', async() => {
        const erc20 = testERC20Derivative;
        _loan_id+=1;
        // Creating order by borrower
        await lend.createLoan(
            // testERC20.address,
            derivedAssetAddress1,
            testERC20StableCoin.address,
            _borrower,
            _amount,
            _rate_of_interest,
            _ltv,
            _liquidation_threshold,
            _expiry_time,
            _discount,
            _external_liquidate,
            // _repayment_by_wvt
        );
        
        // transferring tokens to account 1
        await testERC20StableCoin.transfer(accounts[1], "1000000000000000000");
        // Approving transfer of derivative tokens to single lend contract 1000000000000 1000000000000
        await testERC20StableCoin.approve(lend.address, "10000000000000", {
            from: accounts[1]
        });
        var initial_acc1_stable_value = await get_balance(testERC20StableCoin, accounts[1]);
        var initial_lend_cont_value = await get_balance(testERC20StableCoin, lend.address)

        // let _price = await oracleInstance.priceFeed(testERC20.address)
        await oracleInstance.getPrice(derivedAssetAddress1).then((response)=>{
            _price = response["0"];
            _decimal = response["1"];
        })
        var lend_asset_amount = (_price * 10**18 * _amount * _ltv * _discount)/(100000000 * 10**18 * 10**_decimal)
        await lend.acceptLoan(
            _loan_id,
            _liquidation_flag,
            {
                from: accounts[1]
            }
        );

        var final_acc1_stable_value = await get_balance(testERC20StableCoin, accounts[1]);
        var final_lend_cont_value = await get_balance(testERC20StableCoin, lend.address)
        var difference_acc1 = await initial_acc1_stable_value.minus(final_acc1_stable_value)
        var difference_lend_cont = await final_lend_cont_value.minus(initial_lend_cont_value)

        await lend.loanBook1(_loan_id).then((response)=>{
            assert(
                response.lenderAddress.toString(10) === accounts[1]
               );
        })

        await lend.loanBook2(_loan_id).then((response)=>{
            _lender_asset_amount = response.stablecoinAmount;
            assert(
                response.stageOfLoan.toString(10) === "3"
               );
        })

        // checking the loan amount being transferred from lender to contract
        assert (difference_acc1.toString(10) === difference_lend_cont.toString(10));
        assert (difference_acc1.toString(10) === _lender_asset_amount.toString(10));
        assert (parseInt(lend_asset_amount).toString(10) === _lender_asset_amount.toString(10));
    });

    it('Invalid case: Cancel Loan which is accepted', async() => {
        
        // Invalid case: Cancelling a non-existant loan
        try {
            await lend.cancelLoan(
                _loan_id, {
                    from: accounts[0]
                }
            );
        } catch (error) {
            await assert(error.message.includes("invalid canceller"))
        }
    });

    it('Invalid case: Pull assets ', async() => {
        // Invalid case: Lender pulling the money before expiry
        try {
            await lend.pullAssets(
                _loan_id, {
                    from: accounts[1]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Invalid"))
        }

        // Invalid case: Borrower pulling the money when loan stage is at 6
        try {
            await lend.pullAssets(
                (_loan_id-1), {
                    from: accounts[0]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Invalid"))
        }

        // advancing chain time
        advancement = 86400*2 // 2 days
        await helper.advanceTimeAndBlock(advancement);

        // Invalid case: 3rd party pulling the money after 1 day period has passed
        try {
            await lend.pullAssets(
                (_loan_id), {
                    from: accounts[3]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Invalid"))
        }

        // Invalid case: Borrower pulling the money after 1 day has passed and loan stage is at 6
        try {
            await lend.pullAssets(
                (_loan_id-1), {
                    from: accounts[0]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Invalid"))
        }

    });

    it('Valid case: Pull assets for loan initiated by borrower', async() => {
        const erc20 = testERC20Derivative;
        // Lender pulling the money after expiry

        var initial_acc1_stable_value = await get_balance(testERC20StableCoin, accounts[1]);
        var initial_lend_stable_cont_value = await get_balance(testERC20StableCoin, lend.address);
        var initial_acc0_value = await get_balance(erc20, accounts[0]);

        await lend.loanBook1(_loan_id).then((response)=>{
            interestRate = response.interestRate;
            discount = response.discount;
        })
        await lend.loanBook2(_loan_id).then((response)=>{
            stable_coin_amount = response.stablecoinAmount;
            wvt_amount = response.wvtAmount;
            initiationTime = response.initiationTime;
        })
        testTime = await TimeTest.new();
        currentTime = await  testTime.normalisedTime();
        stableCoinPenalty = (stable_coin_amount *
            interestRate *
            (currentTime - initiationTime + 2*86400)) / (10000 * 86400 * 365);

        await oracleInstance.getPrice(derivedAssetAddress1).then((response)=>{
            _price = response["0"];
            _decimal = response["1"];
        })
        correspondingWVT = (stableCoinPenalty *
            10000 *
            (10**_decimal) *
            (10**18)) /
            (_price *
                (10**18) *
                discount);

        await lend.pullAssets(
            _loan_id, {
                from: accounts[1]
            }
        );
        var final_acc1_stable_value = await get_balance(testERC20StableCoin, accounts[1]);
        var final_lend_stable_cont_value = await get_balance(testERC20StableCoin, lend.address);
        var final_acc0_value = await get_balance(erc20, accounts[0]);

        var difference_acc1_stable = await final_acc1_stable_value.minus(initial_acc1_stable_value);
        var difference_lend_cont = await initial_lend_stable_cont_value.minus(final_lend_stable_cont_value);
        var difference_acc0_wvt = await final_acc0_value.minus(initial_acc0_value);
        // checking the loan amount being transferred from lender to contract
        assert (difference_acc1_stable.toString(10) === difference_lend_cont.toString(10));
        assert (difference_acc1_stable.toString(10) === stable_coin_amount.toString(10));
        assert ((parseInt(difference_acc0_wvt) + parseInt(correspondingWVT)).toString(10) === wvt_amount.toString(10));
    });

    it('Valid case: pull assets by borrower by 1 day cooling period', async() => {
        _loan_id+=1;
        // Creating order by borrower
        await lend.createLoan(
            // testERC20.address,
            derivedAssetAddress1,
            testERC20StableCoin.address,
            _borrower,
            _amount,
            _rate_of_interest,
            _ltv,
            _liquidation_threshold,
            _expiry_time,
            _discount,
            _external_liquidate,
            // _repayment_by_wvt
        );
        
        // transferring tokens to account 1
        await testERC20StableCoin.transfer(accounts[1], "1000000000000000000");
        // Approving transfer of derivative tokens to single lend contract 1000000000000 1000000000000
        await testERC20StableCoin.approve(lend.address, "10000000000000", {
            from: accounts[1]
        });
        await lend.acceptLoan(
            _loan_id,
            _liquidation_flag,
            {
                from: accounts[1]
            }
        );
        
        // invalid case: borrower making a repayment request when loan is at stage 3
        try {
            await lend.repaymentLoan(
                _loan_id, {
                    from: accounts[1]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Invalid"));
        }

        // borrower pulling the money before expiry

        var initial_acc1_stable_value = await get_balance(testERC20StableCoin, accounts[0]);
        var initial_lend_stable_cont_value = await get_balance(testERC20StableCoin, lend.address);

        await lend.loanBook2(_loan_id).then((response)=>{
            stable_coin_amount = response.stablecoinAmount;
        })

        await lend.pullAssets(
            _loan_id, {
                from: accounts[0]
            }
        );
        var final_acc1_stable_value = await get_balance(testERC20StableCoin, accounts[0]);
        var final_lend_stable_cont_value = await get_balance(testERC20StableCoin, lend.address);

        var difference_acc1_stable = await final_acc1_stable_value.minus(initial_acc1_stable_value);
        var difference_lend_cont = await initial_lend_stable_cont_value.minus(final_lend_stable_cont_value);
        // checking the loan amount being transferred from contract to borrower
        assert (difference_acc1_stable.toString(10) === difference_lend_cont.toString(10));
        assert (difference_acc1_stable.toString(10) === stable_coin_amount.toString(10));
    });

    it('Invalid case: Loan Repayment', async() => {
        // Invalid case: Loan Repayment by someone else other than borrower
        try {
            await lend.repaymentLoan(
                _loan_id, {
                    from: accounts[1]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Invalid"));
        }
    });

    it('Loan Repayment', async() => {
        const erc20 = testERC20Derivative;
        var initial_acc1_value = await get_balance(testERC20StableCoin, accounts[0]);
        var initial_acc1_value_erc20 = await get_balance(erc20, accounts[0]);
        var initial_acc2_value = await get_balance(testERC20StableCoin, accounts[1]);
        var initial_lend_cont_value = await get_balance(erc20, lend.address)

        // Approving transfer of stable coins to single lend contract
        await testERC20StableCoin.approve(lend.address, "10000000000000000", {
            from: accounts[0]
        });
        loan_details1 = await lend.loanBook1(_loan_id);
        loan_details2 = await lend.loanBook2(_loan_id);
        
        // Checking if calculation is correct in the contract
        testTime = await TimeTest.new();
        currentTime = await  testTime.normalisedTime();
        penalty = await master.penalty();
        // First cut of interest which is of full rate
        let interest1 = (loan_details2.stablecoinAmount * loan_details1.interestRate * (currentTime-loan_details2.initiationTime))/(10000*86400*365);
        // Second cut of interest which is of full rate * 0.25
        let interest2 = (loan_details2.stablecoinAmount * loan_details1.interestRate * (loan_details2.endTime-currentTime) * penalty)/(100000000*86400*365);
        let totalSumToReturn = parseInt(interest1.toString(10))+parseInt(interest2.toString(10))+parseInt(loan_details2.stablecoinAmount.toString(10));

        await lend.repaymentLoan(
            _loan_id, {
                from: accounts[0]
            }
        );

        var final_acc1_value = await get_balance(testERC20StableCoin, accounts[0]);
        var final_acc1_value_erc20 = await get_balance(erc20, accounts[0]);
        var final_acc2_value = await get_balance(testERC20StableCoin, accounts[1]);
        var final_lend_cont_value = await get_balance(erc20, lend.address)

        var difference_acc1 = await initial_acc1_value.minus(final_acc1_value)
        var difference_acc1_erc20 = await final_acc1_value_erc20.minus(initial_acc1_value_erc20)
        var difference_acc2 = await final_acc2_value.minus(initial_acc2_value)
        var difference_lend_cont = await initial_lend_cont_value.minus(final_lend_cont_value)

        // checking the loan repayment transfers between contract, lender and borrower

        //need to calculate total repayment amount here and map it will borrower and lender
        assert (difference_acc1.toString(10) === difference_acc2.toString(10));
        assert (difference_lend_cont.toString(10) === _amount);
        assert (difference_acc1_erc20.toString(10) === _amount);
        assert (difference_acc1.toString(10) === totalSumToReturn.toString(10))
    });

    it('Invalid Case: Liquidation without approval', async() => {
        const erc20 = testERC20Derivative;
        _loan_id+=1;
        // Creating order by borrower
        await lend.createLoan(
            // testERC20.address,
            derivedAssetAddress1,
            testERC20StableCoin.address,
            _borrower,
            _amount,
            _rate_of_interest,
            _ltv,
            _liquidation_threshold,
            _expiry_time,
            _discount,
            _external_liquidate,
            // _repayment_by_wvt
        );
        
        // transferring tokens to account 1
        await testERC20StableCoin.transfer(accounts[1], "1000000000000000000");
        // Approving transfer of derivative tokens to single lend contract 1000000000000 1000000000000
        await testERC20StableCoin.approve(lend.address, "10000000000000", {
            from: accounts[1]
        });
        await lend.acceptLoan(
            _loan_id,
            true,
            {
                from: accounts[1]
            }
        );

        // Invalid Case: calling liquidation before stage 6
        try {
            await lend.liquidation(
                _loan_id, {
                    from: accounts[1]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Not Defaulted"))
        }

        await lend.pullAssets(
            _loan_id, {
                from: accounts[0]
            }
        );

        try {
            await lendNFTInstance.transferFrom(accounts[1],accounts[5],_loan_id,{from: accounts[1]});
        } catch(error){
            console.log(error)
        }
        // Invalid Case: Collateral value > LT
        try {
            await lend.liquidation(
                _loan_id, {
                    from: accounts[1]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Not Defaulted"))
        }

        // Invalid case: Liquidating a non-existent loan
        try {
            await lend.liquidation(
                10, {
                    from: accounts[1]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Not Defaulted"))
        }

        // updating the collateral value such that value is less than liquidation threshold
        // await oracleInstance.updateFeed(testERC20.address,"2");
        await oracleFeedInstance.updateFeedData("36893488147419115317","200000000","1650873608","1650873616","36893488147419115317");
        // Invalid case: liquidating the loan without funds.
        try {
            await lend.liquidation(
                _loan_id, {
                    from: accounts[3]
                }
            );
        } catch (error) {
            await assert(error.message.includes("ERC20: transfer amount exceeds balance"))
        }

        // Transfer of stable coins to single lend contract
        await testERC20StableCoin.transfer(accounts[3], "1000000000000000000");

        // Invalid case: liquidating the loan without fund approval.
        try {
            await lend.liquidation(
                _loan_id, {
                    from: accounts[3]
                }
            );
        } catch (error) {
            await assert(error.message.includes("ERC20: transfer amount exceeds allowance"))
        }
    });

    it('Liquidation', async() => {
        const erc20 = testERC20Derivative;
        // Approving transfer of stable coins to single lend contract

        await testERC20StableCoin.approve(lend.address, "1000000000000000000", {
            from: accounts[3]
        });

        var initial_acc2_value = await get_balance(testERC20StableCoin, accounts[5]);
        var initial_acc3_value = await get_balance(testERC20StableCoin, accounts[3]);
        var initial_acc3_derivative_value = await get_balance(erc20, accounts[3]);
        var initial_lend_cont_value = await get_balance(erc20, lend.address)

        // checking if price calculated is correct
        loan_details1 = await lend.loanBook1(_loan_id);
        loan_details2 = await lend.loanBook2(_loan_id);
        
        await oracleInstance.getPrice(derivedAssetAddress1).then((response)=>{
            _price = response["0"];
            _decimal = response["1"];
        })
        var priceOfCollateral = (_price * 10**18 * _amount * _discount) / (10000 * 10**18 * 10**_decimal)
        
        
        await lend.liquidation(
            _loan_id, {
                from: accounts[3]
            }
        );

        // var final_acc2_value = await get_balance(testERC20StableCoin, accounts[1]);
        var final_acc2_value = await get_balance(testERC20StableCoin, accounts[5]);
        var final_acc3_derivative_value = await get_balance(erc20, accounts[3]);
        var final_acc3_value = await get_balance(testERC20StableCoin, accounts[3]);
        var final_lend_cont_value = await get_balance(erc20, lend.address)

        //need to calculate total repayment amount here and map it will borrower and lender
        var difference_acc2 = await final_acc2_value.minus(initial_acc2_value);
        var difference_acc3 = await initial_acc3_value.minus(final_acc3_value);
        var difference_acc3_deri = await final_acc3_derivative_value.minus(initial_acc3_derivative_value);
        var difference_lend_cont = await initial_lend_cont_value.minus(final_lend_cont_value)

        assert(difference_acc2.toString(10) === priceOfCollateral.toString(10))
        assert (difference_acc3_deri.toString(10) === difference_lend_cont.toString(10));
        assert (difference_acc2.toString(10) === difference_acc3.toString(10));
    });

    it('Invalid case: Liquidation', async() => {
        // Invalid case: Liquidation for re-payed loan
        try {
            await lend.liquidation(
                1, {
                    from: accounts[0]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Not Defaulted"))
        }
        // Invalid case: Liquidation for a non-existent loan id
        try {
            await lend.liquidation(
                100, {
                    from: accounts[0]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Not Defaulted"))
        }
    });

    it('Liquidation by Lender', async() => {
        const erc20 = testERC20Derivative;
        // await oracleInstance.updateFeed(testERC20.address,"200");
        await oracleFeedInstance.updateFeedData("36893488147419115317","20000000000","1650873608","1650873616","36893488147419115317");
        _loan_id+=1;
        // Creating order by borrower
        await lend.createLoan(
            // testERC20.address,
            derivedAssetAddress1,
            testERC20StableCoin.address,
            _borrower,
            _amount,
            _rate_of_interest,
            _ltv,
            _liquidation_threshold,
            _expiry_time,
            _discount,
            _external_liquidate,
            // _repayment_by_wvt
        );
        
        // transferring tokens to account 1
        await testERC20StableCoin.transfer(accounts[1], "1000000000000000000");
        // Approving transfer of derivative tokens to single lend contract 1000000000000 1000000000000
        await testERC20StableCoin.approve(lend.address, "10000000000000", {
            from: accounts[1]
        });
        await lend.acceptLoan(
            _loan_id,
            false,
            {
                from: accounts[1]
            }
        );

        await lend.pullAssets(
            _loan_id, {
                from: accounts[0]
            }
        );
        // await oracleInstance.updateFeed(testERC20.address,"2");
        await oracleFeedInstance.updateFeedData("36893488147419115317","200000000","1650873608","1650873616","36893488147419115317");
        // invalid case of someone else liquidating the loan when only lender can do so
        try {
            await lend.liquidation(
                _loan_id, {
                    from: accounts[9]
                }
            );
        } catch (error){
            await assert(error.message.includes("Not allowed"))
        }

        await lendNFTInstance.transferFrom(accounts[1],accounts[8],_loan_id,{from: accounts[1]});
        await lendNFTInstance.transferFrom(accounts[8],accounts[9],_loan_id,{from: accounts[8]});

        var initial_acc2_value = await get_balance(erc20, accounts[9]);
        
        // Lender taking the collateral

        await lend.liquidation(
            _loan_id, {
                from: accounts[9]
            }
        );

        var final_acc2_value = await get_balance(erc20, accounts[9]);
        var difference_acc2 = await final_acc2_value.minus(initial_acc2_value);
        assert (difference_acc2.toString(10) === _amount);
    });

    it('Repaying loan after expiry', async() => {
        const erc20 = testERC20Derivative;
        await oracleFeedInstance.updateFeedData("36893488147419115317","20000000000","1650873608","1650873616","36893488147419115317");
        _loan_id+=1;
        // Creating order by borrower
        await lend.createLoan(
            // testERC20.address,
            derivedAssetAddress1,
            testERC20StableCoin.address,
            _borrower,
            _amount,
            _rate_of_interest,
            _ltv,
            _liquidation_threshold,
            _expiry_time,
            _discount,
            _external_liquidate,
            // _repayment_by_wvt
        );
        
        // transferring tokens to account 1
        await testERC20StableCoin.transfer(accounts[1], "1000000000000000000");
        // Approving transfer of derivative tokens to single lend contract 1000000000000 1000000000000
        await testERC20StableCoin.approve(lend.address, "10000000000000", {
            from: accounts[1]
        });
        await lend.acceptLoan(
            _loan_id,
            false,
            {
                from: accounts[1]
            }
        );

        await lend.pullAssets(
            _loan_id, {
                from: accounts[0]
            }
        );

        // advancing chain time
        advancement = 86400 * 730 // 2 years
        await helper.advanceTimeAndBlock(advancement);

        // Invalid case: Loan Repayment expired loans
        try {
            await lend.repaymentLoan(
                _loan_id, {
                    from: accounts[0]
                }
            );
        } catch (error) {
            await assert(error.message.includes("Invalid"))
        }

        // Valid case: Return Collateral after expired loan
        await lend.liquidation(
            _loan_id, {
                from: accounts[1]
            }
        );
        await lend.loanBook1(_loan_id).then((response)=>{
            assert(
                response.borrowerAddress === "0x0000000000000000000000000000000000000000",
                response.lenderAddress === "0x0000000000000000000000000000000000000000"
            );
        })
    });

    it('Repaying loan after expiry by anyone else other than lender', async() => {
        const erc20 = testERC20Derivative;
        // Transfer and approving of stable coins to single lend contract
        await testERC20StableCoin.transfer(accounts[2], "1000000000000000000");
        await testERC20StableCoin.approve(lend.address, "1000000000000000000", {
            from: accounts[2]
        });
        // await oracleInstance.updateFeed(erc20.address,"200");
        _loan_id+=1;
        // Creating order by borrower
        await lend.createLoan(
            // testERC20.address,
            derivedAssetAddress1,
            testERC20StableCoin.address,
            _borrower,
            _amount,
            _rate_of_interest,
            _ltv,
            _liquidation_threshold,
            _expiry_time,
            _discount,
            _external_liquidate,
            // _repayment_by_wvt
        );
        
        // transferring tokens to account 1
        await testERC20StableCoin.transfer(accounts[1], "1000000000000000000");
        // Approving transfer of derivative tokens to single lend contract 1000000000000 1000000000000
        await testERC20StableCoin.approve(lend.address, "10000000000000", {
            from: accounts[1]
        });
        await lend.acceptLoan(
            _loan_id,
            true,
            {
                from: accounts[1]
            }
        );

        await lend.pullAssets(
            _loan_id, {
                from: accounts[0]
            }
        );

        // advancing chain time
        advancement = 86400 * 730 // 2 years
        await helper.advanceTimeAndBlock(advancement);

        // Valid case: Return Collateral after expired loan
        await lend.liquidation(
            _loan_id, {
                from: accounts[2]
            }
        );
        await lend.loanBook1(_loan_id).then((response)=>{
            assert(
                response.borrowerAddress === "0x0000000000000000000000000000000000000000",
                response.lenderAddress === "0x0000000000000000000000000000000000000000"
            );
        })
    });

    it('Checking the pause function in the contract', async () => {
        _loan_id+=1;
        await lend.pause();
        try {
            // Creating order by borrower
            await lend.createLoan(
                // testERC20.address,
                derivedAssetAddress1,
                testERC20StableCoin.address,
                _borrower,
                _amount,
                _rate_of_interest,
                _ltv,
                _liquidation_threshold,
                _expiry_time,
                _discount,
                _external_liquidate,
                // _repayment_by_wvt
            );
        } catch (error) {
            await assert(error.message.includes("Pausable: paused"))
        }
        await lend.unpause();
        try {
                // Creating order by borrower
                await lend.createLoan(
                    "0x0000000000000000000000000000000000000000",
                    testERC20StableCoin.address,
                    _borrower,
                    _amount,
                    _rate_of_interest,
                    _ltv,
                    _liquidation_threshold,
                    _expiry_time,
                    _discount,
                    _external_liquidate,
                    // _repayment_by_wvt
                );
        } catch (error) {
            await assert(error.message.includes("Invalid Input"))
        }
    });

});
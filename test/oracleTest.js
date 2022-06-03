const { assert } = require("console");

const Oracle = artifacts.require("Oracle");
const OracleFeed = artifacts.require("AggregatorV3Interface");
const ERC20test = artifacts.require("ERC20Test");
const Controller = artifacts.require("Controller");
const model = artifacts.require("ERC20CloneContract");
const factoryContract = artifacts.require("ERC20Factory");

contract('Testing Oracle', (accounts) => {
    var oracleInstance;
    var testERC20;
    var oracleFeedInstance;

    it('Deployed Oracle and Update feed', async() => {
        oracleInstance = await Oracle.deployed();

        oracleFeedInstance = await OracleFeed.new();

        await oracleFeedInstance.updateFeedDecimalAndVersion("8","3");

        await oracleFeedInstance.updateFeedData("36893488147419115317","281560000000","1650873608","1650873616","36893488147419115317");

        testERC20 = await ERC20test.new("OracleToken","OT","100000000000000000000000000");

        controllerInstance = await Controller.new();
        await console.log("Controller address : ", controllerInstance.address)

        let erc20model = await model.new();
        let erc20factory = await factoryContract.new(erc20model.address, controllerInstance.address);
        await controllerInstance.setFactory(erc20factory.address);
        assert(controllerInstance.address !== '', "Contract was deployed");



        await oracleInstance.updateAssetFeed(testERC20.address,oracleFeedInstance.address);

        await console.log("Token address : ",testERC20.address);
        await console.log("Oracle Feed : ",oracleFeedInstance.address);

        await oracleInstance.assetToFeed(testERC20.address).then((response)=>{
            assert(response.toString(10)===oracleFeedInstance.address);
        });

        // await oracleInstance.priceFeed(testERC20.address).then((response)=>{
        //     assert(response.toString(10)==="0");
        // })

        // await oracleInstance.updateFeed(testERC20.address,"2000000");

        // await oracleInstance.priceFeed(testERC20.address).then((response)=>{
        //     assert(response.toString(10)==="2000000");
        // })

        // try {
        //     await oracleInstance.updateFeed(
        //         testERC20.address,
        //         "2000000",{
        //             from: accounts[1]
        //             }
        //     );
        // } catch (error) {
        //     await assert(error.message.includes("Ownable: caller is not the owner"))
        // }
    });

    it('Vest Tokens', async() => {

        var a1 = []
        var a2 = []
        var a3 = []
        var a4 = []
        const erc20 = testERC20;
        await erc20.approve(controllerInstance.address, "40000000000000000000", {
            from: accounts[0]
        });
        let kp = 1666698326 //  25 October 2022
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

        let derivativeAddress = await controllerInstance.derivativeIDtoAddress("1").then((response)=>{
            return(response.toString(10));
        });

        await oracleInstance.setController(controllerInstance.address);

            
        await oracleInstance.getPrice(derivativeAddress).then((response)=>{
            assert(response["0"].toString(10)==="281560000000");
            assert(response["1"].toString(10)==="8");
        })
     
    });

});
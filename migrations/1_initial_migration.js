const oracle = artifacts.require("Oracle");
const Master = artifacts.require("Master");
const LendNFT = artifacts.require("LendNFT");
const Lend = artifacts.require("Lend");

const { deployProxy } = require("@openzeppelin/truffle-upgrades");


module.exports =  async function(deployer) {
  const accounts = await web3.eth.getAccounts();
  const sleep = ms => new Promise(r => setTimeout(r, ms));

  await console.log("Deploy NFT contract");
  
  let nftinstance = await deployProxy(LendNFT,[],{kind: 'uups'});
  
  await console.log("NFT Address: ", nftinstance.address);
  
  await nftinstance.controller().then((response)=>{
      console.log("Controller address -",response)
  });


  await console.log("Deploy Oracle Contract");

  await deployer.deploy(oracle);
  let oracleInstance = await oracle.deployed();
  await console.log("Oracle Address: ", oracleInstance.address);

  await sleep(3000);
  await console.log("Deploy Master Contract");

  let MasterInstance =  await deployProxy(Master, [oracleInstance.address,"500"], { kind: 'uups' });
  await console.log("Master address: ", MasterInstance.address)

  await sleep(3000);
  await console.log("Deploy Lend Contract");

  let lendInstance = await deployProxy(Lend, [MasterInstance.address, nftinstance.address], { kind: 'uups' });
  await console.log("LendInstance Address: ", lendInstance.address);

  await sleep(3000);
  await console.log("Set NFT controller");
  
  await nftinstance.setController(lendInstance.address);

  await nftinstance.controller().then((response)=>{
    console.log("Controller address -",response)
  });
  // set lend contract in master
  await sleep(3000);
  await console.log("Set Lend Contract in master");

  await MasterInstance.setLendContract(lendInstance.address);
  await MasterInstance.lend().then((response)=>{
    console.log("Lend address -",response)
  });

  await console.log("Deployment complete");
}
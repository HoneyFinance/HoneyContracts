const HoneyToken = artifacts.require("Honey");
const HoneycombV2 = artifacts.require("HoneycombV2");
const UniswapV2YfiToken = artifacts.require("UniswapV2Yfi");
const UniswapV2UniToken = artifacts.require("UniswapV2Uni");
const UniswapV2HoneyToken = artifacts.require("UniswapV2Honey");
const Stage2Lock = artifacts.require("Stage2Lock");

module.exports = async function (deployer, network, accounts) {
  let honeyTokenInstance = await HoneyToken.deployed();
  await deployer.deploy(HoneycombV2, honeyTokenInstance.address);

  if (network == 'live') {
    await deployer.deploy(Stage2Lock, honeyTokenInstance.address, accounts[0], parseInt(Date.now() / 1000) + 86400 * 14);
  } else if (network == 'ropsten') {
    await deployer.deploy(UniswapV2YfiToken);
    await deployer.deploy(UniswapV2UniToken);
    await deployer.deploy(UniswapV2HoneyToken);

    await deployer.deploy(Stage2Lock, honeyTokenInstance.address, accounts[0], parseInt(Date.now() / 1000) + 86400 * 14);
  } else {
    await deployer.deploy(UniswapV2YfiToken);
    await deployer.deploy(UniswapV2UniToken);
    await deployer.deploy(UniswapV2HoneyToken);

    await deployer.deploy(Stage2Lock, honeyTokenInstance.address, accounts[0], parseInt(Date.now() / 1000) + 300);
  }
}

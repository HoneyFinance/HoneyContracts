const HoneyToken = artifacts.require("Honey");
const HoneycombV2 = artifacts.require("HoneycombV2");
const UniswapV2Token = artifacts.require("UniswapV2");
const UniswapV2YfiToken = artifacts.require("UniswapV2Yfi");
const UniswapV2UniToken = artifacts.require("UniswapV2Uni");
const UniswapV2HoneyToken = artifacts.require("UniswapV2Honey");
const Stage2Lock = artifacts.require("Stage2Lock");

module.exports = async function (deployer, network, accounts) {
  let honeyTokenInstance = await HoneyToken.deployed();
  let honeycombV2Instance = await HoneycombV2.deployed()

  await honeyTokenInstance.approve(honeycombV2Instance.address, web3.utils.toWei('100000', 'ether'), { from: accounts[0] });

  if (network == 'live') {
    honeycombV2Instance.addBatch(11066600, 11066600 + 95000, web3.utils.toWei('0.006', 'ether'), honeycombV2Instance.address, honeycombV2Instance.address);
    honeycombV2Instance.addPool(0, '0x7C0Df3b6B8498f4634c8B1b687E512971DF74aAe', 1); // COS
    honeycombV2Instance.addPool(0, '0x2fDbAdf3C4D5A8666Bc06645B8358ab803996E28', 1); // YFI
    honeycombV2Instance.addPool(0, '0xd3d2E2692501A5c9Ca623199D38826e513033a17', 1); // UNI
    honeycombV2Instance.addPool(0, '0x7186141Bd5b90576019dE6988B295A2210565618', 3); // HONEY

    let lockInstance = await Stage2Lock.deployed();
    honeyTokenInstance.transfer(lockInstance.address, web3.utils.toWei('3430', 'ether'), { from: accounts[0] });
  } else if (network == 'ropsten') {
    let uniswapV2Instance = await UniswapV2Token.deployed();
    let uniswapV2YfiTokenInstance = await UniswapV2YfiToken.deployed();
    let uniswapV2UniTokenInstance = await UniswapV2UniToken.deployed();
    let uniswapV2HoneyTokenInstance = await UniswapV2HoneyToken.deployed();

    honeycombV2Instance.addBatch(8884600, 8884600 + 95000, web3.utils.toWei('0.006', 'ether'), honeycombV2Instance.address, honeycombV2Instance.address);
    honeycombV2Instance.addPool(0, uniswapV2Instance.address, 1);
    honeycombV2Instance.addPool(0, uniswapV2YfiTokenInstance.address, 1);
    honeycombV2Instance.addPool(0, uniswapV2UniTokenInstance.address, 1);
    honeycombV2Instance.addPool(0, uniswapV2HoneyTokenInstance.address, 3);

    let lockInstance = await Stage2Lock.deployed();
    honeyTokenInstance.transfer(lockInstance.address, web3.utils.toWei('100', 'ether'), { from: accounts[0] });
  } else {
    let uniswapV2Instance = await UniswapV2Token.deployed();
    let uniswapV2YfiTokenInstance = await UniswapV2YfiToken.deployed();
    let uniswapV2UniTokenInstance = await UniswapV2UniToken.deployed();
    let uniswapV2HoneyTokenInstance = await UniswapV2HoneyToken.deployed();

    honeycombV2Instance.addBatch(100, 100 + 95000, web3.utils.toWei('0.006', 'ether'), honeycombV2Instance.address, honeycombV2Instance.address);
    honeycombV2Instance.addPool(0, uniswapV2Instance.address, 1);
    honeycombV2Instance.addPool(0, uniswapV2YfiTokenInstance.address, 1);
    honeycombV2Instance.addPool(0, uniswapV2UniTokenInstance.address, 1);
    honeycombV2Instance.addPool(0, uniswapV2HoneyTokenInstance.address, 3);

    let lockInstance = await Stage2Lock.deployed();
    honeyTokenInstance.transfer(lockInstance.address, web3.utils.toWei('3430', 'ether'), { from: accounts[0] });
  }
}

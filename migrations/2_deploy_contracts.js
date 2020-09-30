const HoneyToken = artifacts.require("Honey");
const UniswapV2Token = artifacts.require("UniswapV2");
const Honeycomb = artifacts.require("Honeycomb");
const WarmupTeamLock = artifacts.require("WarmupTeamLock");
const PrelaunchLock = artifacts.require("PrelaunchLock");
const ProductionLock = artifacts.require("ProductionLock");

module.exports = async function (deployer, network, accounts) {
  var honeyPerBlock, startBlock, endBlock, lockDuration1, lockDuration2, beneficiaryDevTeam, beneficiary, lpTokenAddress;
  if (network == 'ropsten') {
    honeyPerBlock = '0.01';
    startBlock = 8784400;
    endBlock = 8840500;
    lockDuration1 = 86400 * 7 * 2;
    lockDuration2 = 86400 * 7 * 6;
    beneficiaryDevTeam = '0x2a9feEB2c33e7A181471c318694a8aAEBe3A53ed';
    beneficiary = accounts[0];
  } else if (network == 'live') {
    honeyPerBlock = '0.01';
    startBlock = 10965050;
    endBlock = startBlock + 95000; // 95000 blocks take about 14 days (~13s per block)
    lockDuration1 = 86400 * 7 * 2;
    lockDuration2 = 86400 * 7 * 6;
    lpTokenAddress = '0x7c0df3b6b8498f4634c8b1b687e512971df74aae'; // COS-ETH UNI-V2 LP
    beneficiaryDevTeam = '0xf193198fDE76CA3F25B3b263d98ea07bDa6267e9';
    beneficiary = '0x179047339A1c38F8A7820D89B401fD32179158a0';
  } else {
    honeyPerBlock = '1';
    startBlock = 50;
    endBlock = 1000;
    lockDuration1 = 300;
    lockDuration2 = 420;
    beneficiaryDevTeam = accounts[0];
    beneficiary = accounts[0];
  }

  // Deploy HONEY tokens
  let honeyTokenInstance;
  await deployer.deploy(HoneyToken, web3.utils.toWei('100000', 'ether')).then(instance => honeyTokenInstance = instance);

  // Deploy Honeycomb (liquidity mining) contract
  let honeycombInstance;
  await deployer.deploy(Honeycomb, honeyTokenInstance.address, web3.utils.toWei(honeyPerBlock, 'ether'), startBlock, endBlock).then(instance => honeycombInstance = instance);

  // Deploy lock-up contract for the reserved tokens to dev team in phase 1. The locked tokens will be gradually released through out lockDuration1
  let warmupTeamLockInstance;
  await deployer.deploy(WarmupTeamLock, honeyTokenInstance.address, beneficiaryDevTeam, parseInt(Date.now() / 1000), lockDuration1).then(instance => warmupTeamLockInstance = instance);

  // Deploy lock-up contract for the reserved tokens in phase 2. The locked tokens will be released at once after lockDuration1
  let prelaunchLockInstance;
  await deployer.deploy(PrelaunchLock, honeyTokenInstance.address, beneficiary, parseInt(Date.now() / 1000) + lockDuration1).then(instance => prelaunchLockInstance = instance);

  // Deploy lock-up contract for the reserved tokens in phase 3. The locked tokens will be released at once after lockDuration2
  let productionLockInstance;
  await deployer.deploy(ProductionLock, honeyTokenInstance.address, beneficiary, parseInt(Date.now() / 1000) + lockDuration2).then(instance => productionLockInstance = instance);

  // Allocate 950 HONEY (0.95%) to Honeycomb contract for phase 1 liquidity mining
  honeyTokenInstance.mint(honeycombInstance.address, web3.utils.toWei('950', 'ether'));

  // Allocate 50 HONEY (0.05%) to dev team's lock-up contract for phase 1
  honeyTokenInstance.mint(warmupTeamLockInstance.address, web3.utils.toWei('50', 'ether'));

  // Reserve 4000 HONEY (4%) for phase 2
  honeyTokenInstance.mint(prelaunchLockInstance.address, web3.utils.toWei('4000', 'ether'));

  // Reserve 95000 HONEY (95%) for phase 3
  honeyTokenInstance.mint(productionLockInstance.address, web3.utils.toWei('95000', 'ether'));

  if (network != 'live') {
    // Deploy mock LP tokens for testing
    let uniswapV2TokenInstance;
    await deployer.deploy(UniswapV2Token).then(instance => uniswapV2TokenInstance = instance);
    lpTokenAddress = uniswapV2TokenInstance.address
  }

  // Assign the designated LP token to Honeycomb's pool
  await honeycombInstance.add(1, lpTokenAddress, false)
};

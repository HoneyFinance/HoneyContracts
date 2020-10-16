const PrelaunchLock = artifacts.require("PrelaunchLock");
const ProductionLock = artifacts.require("ProductionLock");

module.exports = async function (deployer, network, accounts) {
  let prelaunchLockInstance = await PrelaunchLock.deployed()
  await prelaunchLockInstance.release()
};

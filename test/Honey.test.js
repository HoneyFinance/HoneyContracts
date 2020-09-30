const Honey = artifacts.require('Honey');
const Honeycomb = artifacts.require('Honeycomb');
const WarmupTeamLock = artifacts.require("WarmupTeamLock");
const PrelaunchLock = artifacts.require("PrelaunchLock");
const ProductionLock = artifacts.require("ProductionLock");

contract('Honey', (accounts) => {
    it('Balance verification', async () => {
        const honeyInstance = await Honey.deployed();
        const honeycombInstance = await Honeycomb.deployed();
        const warmupTeamLockInstance = await WarmupTeamLock.deployed();
        const prelaunchLockInstance = await PrelaunchLock.deployed();
        const productionLockInstance = await ProductionLock.deployed();

        const balanceHoneycomb = await honeyInstance.balanceOf.call(honeycombInstance.address);
        const balanceWarmupTeamLock = await honeyInstance.balanceOf.call(warmupTeamLockInstance.address);
        const balancePrelaunchLock = await honeyInstance.balanceOf.call(prelaunchLockInstance.address);
        const balanceProductionLock = await honeyInstance.balanceOf.call(productionLockInstance.address);

        assert.equal(web3.utils.fromWei(balanceHoneycomb, 'ether'), 950, "Incorrect Honeycomb contract balance");
        assert.equal(web3.utils.fromWei(balanceWarmupTeamLock, 'ether'), 50, "Incorrect WarmupTeamLock contract balance");
        assert.equal(web3.utils.fromWei(balancePrelaunchLock, 'ether'), 4000, "Incorrect PrelaunchLock contract balance");
        assert.equal(web3.utils.fromWei(balanceProductionLock, 'ether'), 95000, "Incorrect ProductionLock contract balance");
    });
});



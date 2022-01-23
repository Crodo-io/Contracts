const CrodoDistributionContract = artifacts.require("CrodoDistributionContract");
const CrodoToken = artifacts.require("CrodoToken");

module.exports = function (deployer) {
    deployer.deploy(CrodoDistributionContract)
        .then(() => CrodoDistributionContract.deployed())
        .then(() => deployer.deploy(CrodoToken, CrodoDistributionContract.address));
};

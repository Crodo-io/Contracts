const CrodoDistributionContract = artifacts.require("CrodoDistributionContract")
const CrodoToken = artifacts.require("CrodoToken")

module.exports = function (deployer) {
    CrodoDistributionContract.deployed()
        .then(() => deployer.deploy(CrodoToken, CrodoDistributionContract.address))
}

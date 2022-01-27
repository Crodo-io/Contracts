const CrodoDistributionContract = artifacts.require("CrodoDistributionContract")

module.exports = function (deployer) {
    deployer.deploy(CrodoDistributionContract)
}

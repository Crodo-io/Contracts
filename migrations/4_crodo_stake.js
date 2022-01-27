const CrodoToken = artifacts.require("CrodoToken")
const CRDStake = artifacts.require("CRDStake")

module.exports = function (deployer) {
    CrodoToken.deployed()
        .then(() => deployer.deploy(CRDStake, CrodoToken.address, 0, 10000000))
}

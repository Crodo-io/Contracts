const CrodoToken = artifacts.require("CrodoToken")
const CRDStake = artifacts.require("CRDStake")

const minute = 60
const hour = minute * 60
const day = hour * 24
const month = day * 30
const year = month * 12

const lockTimePeriodMin = month * 6
const lockTimePeriodMax = year * 4

module.exports = async function (deployer) {
    const token = await CrodoToken.deployed()
    await deployer.deploy(CRDStake, token.address, lockTimePeriodMin, lockTimePeriodMax)
}

const CrodoDistributionContract = artifacts.require("CrodoDistributionContract")
const CrodoToken = artifacts.require("CrodoToken")

const TGEDate = new Date(2022, 1, 30).getTime()

module.exports = async function (deployer) {
    await deployer.deploy(CrodoDistributionContract)
    const dist = await CrodoDistributionContract.deployed()
    await deployer.deploy(CrodoToken, dist.address)
    const token = await CrodoToken.deployed()
    await dist.setTokenAddress(token.address)

    if (TGEDate <= Date.now()) {
        await dist.setTGEDate(Math.floor(TGEDate / 1000))
    }
}

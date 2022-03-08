const CrodoDistributionContract = artifacts.require("CrodoDistributionContract")
const CrodoToken = artifacts.require("CrodoToken")

const TGEDate = Math.floor(new Date(2022, 1, 30).getTime() / 1000) // TODO: Set correct TGEDate

// TODO: Set correct addresses
const seedWallet = "0x72245A3E23E7F73e5eaD2857b990b74a27FB95d4"
const privSaleWallet = "0xC1A14B3CC70d3a1FD4f8e45FeA6B0c755f5a3D4A"
const strategicSaleWallet = "0x567C09825dd2678fc8BE92F7504823A09C638555"
const pubSaleWallet = "0xC6F8fa17836fEebBD836f7F5986942e8d102B683"
const teamWallet = "0xD502Ca554453ae1452aAE0760ef3c8F0ABA8F008"
const advisorsWallet = "0x4B49f5c28469F1445D5d591078bde5B976a2a28B"
const liquidityWallet = "0xd2656F956Ee90Bb6A564C35AA886405075D97E0E"
const strategicWallet = "0x0c1b057E1726A26D5A47FaBA8770263bF54bE4a1"
const communityWallet = "0x3Be5244F6c0769384B8AB3bC1EE8667C19CF4D68"

module.exports = async function (deployer) {
    await deployer.deploy(
        CrodoDistributionContract,
        seedWallet,
        privSaleWallet,
        strategicSaleWallet,
        pubSaleWallet,
        teamWallet,
        advisorsWallet,
        liquidityWallet,
        strategicWallet,
        communityWallet
    )
    const dist = await CrodoDistributionContract.deployed()
    await deployer.deploy(CrodoToken, dist.address)
    const token = await CrodoToken.deployed()
    await dist.setTokenAddress(token.address)
    await dist.setTGEDate(TGEDate)

    await dist.setSeedRound()
    await dist.setPrivateRound()
    await dist.setStrategicSaleRound()
    await dist.setPublicRound()
    await dist.setTeamRound()
    await dist.setAdvisorsRound()
    await dist.setLiquidityRound()
    await dist.setStrategicRound()
    await dist.setCommunityRound()
}

// Before any of the contract sales can be used for locking tokens, we need to fund by sending
// regular ERC20 `transfer` transaction on their address.

const CrodoToken = artifacts.require("CrodoToken")
const CrodoSeedSale = artifacts.require("CrodoSeedSale")
const CrodoPrivateSale = artifacts.require("CrodoPrivateSale")
const CrodoStrategicSale = artifacts.require("CrodoStrategicSale")
const CrodoPublicSale = artifacts.require("CrodoPublicSale")
const { getUnixDate, amountToLamports } = require("./utils.js")

// TODO: Set correct dates & USDT address
const USDTAddress = "0x66e428c3f67a68878562e79A0234c1F83c208770"
const USDTDecimals = 6
const seedFirstRelease = getUnixDate(2022, 4, 1)
const privateFirstRelease = getUnixDate(2022, 4, 1)
const strategicFirstRelease = getUnixDate(2022, 4, 1)
const publicFirstRelease = getUnixDate(2022, 4, 1)
const seedReleases = 27
const privateReleases = 26
const strategicReleases = 24
const publicReleases = 4
const seedPrice = amountToLamports(0.10, USDTDecimals)
const privatePrice = amountToLamports(0.14, USDTDecimals)
const strategicPrice = amountToLamports(0.16, USDTDecimals)
const publicPrice = amountToLamports(0.18, USDTDecimals)

module.exports = async function (deployer) {
    const token = await CrodoToken.deployed()

    await deployer.deploy(
        CrodoSeedSale, token.address, USDTAddress, seedPrice,
        seedFirstRelease, seedReleases
    )

    await deployer.deploy(
        CrodoPrivateSale, token.address, USDTAddress, privatePrice,
        privateFirstRelease, privateReleases
    )

    await deployer.deploy(
        CrodoStrategicSale, token.address, USDTAddress, strategicPrice,
        strategicFirstRelease, strategicReleases
    )

    await deployer.deploy(
        CrodoPublicSale, token.address, USDTAddress, publicPrice,
        publicFirstRelease, publicReleases
    )
}

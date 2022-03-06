const DistributionContract = artifacts.require("CrodoDistributionContract")
const CrodoToken = artifacts.require("CrodoToken")
const BigNumber = require("bignumber.js")
const timeMachine = require("ganache-time-traveler")

function amountToLamports (amount, decimals) {
    return new BigNumber(amount).multipliedBy(10 ** decimals).integerValue()
}

function getTimestamp () {
    return Math.floor(Date.now() / 1000)
}

contract("CrodoToken", (accounts) => {
    let token
    let dist

    const seedWallet = accounts[0];
    const privSaleWallet = accounts[1];
    const strategicSaleWallet = accounts[2];
    const pubSaleWallet = accounts[3];
    const teamWallet = accounts[4];
    const advisorsWallet = accounts[5];
    const liquidityWallet = accounts[6];
    const strategicWallet = accounts[7];
    const communityWallet = accounts[8];

    const day = 60 * 60 * 24
    const month = day * 30
    const TGEDate = getTimestamp() + month
    let crodoDecimals

    const releaseWallets = [
        seedWallet, privSaleWallet, strategicSaleWallet, pubSaleWallet, teamWallet,
        advisorsWallet, liquidityWallet, strategicWallet, communityWallet
    ]
    /*
     * Precomputed releases table, each row is balance on nth month after TGEDate,
     * each category is rounded to 100% (some categories aren't precise,
     * e.g. Strategic reserve: 2.85% * 35 = 99.75%).
     *
     * Columns:
     * Seed, Private sale, Strategic, Public sale, Team, Advisors, Liquidity, Strategic Reserve, Community / Ecosystem
     */
    const releasesTable = [
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,        0, 1050000],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,        0, 1673700],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,        0, 2297400],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,        0, 2921100],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,        0, 3544800],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,        0, 4168500],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,   570000, 4792200],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,  1140000, 5415900],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,  1710000, 6039600],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,  2280000, 6663300],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,  2850000, 7287000],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,  3420000, 7910700],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,  3990000, 8534400],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,  4560000, 9158100],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,  5130000, 9781800],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,  5700000, 10405500],
        [ 6000000, 8000000, 8000000, 4000000,        0,       0, 12000000,  6270000, 11029200],
        [ 6000000, 8000000, 8000000, 4000000,   600000,  240000, 12000000,  6840000, 11652900],
        [ 6000000, 8000000, 8000000, 4000000,  1200000,  480000, 12000000,  7410000, 12276600],
        [ 6000000, 8000000, 8000000, 4000000,  1800000,  720000, 12000000,  7980000, 12900300],
        [ 6000000, 8000000, 8000000, 4000000,  2400000,  960000, 12000000,  8550000, 13524000],
        [ 6000000, 8000000, 8000000, 4000000,  3000000, 1200000, 12000000,  9120000, 14147700],
        [ 6000000, 8000000, 8000000, 4000000,  3600000, 1440000, 12000000,  9690000, 14771400],
        [ 6000000, 8000000, 8000000, 4000000,  4200000, 1680000, 12000000, 10260000, 15395100],
        [ 6000000, 8000000, 8000000, 4000000,  4800000, 1920000, 12000000, 10830000, 16018800],
        [ 6000000, 8000000, 8000000, 4000000,  5400000, 2160000, 12000000, 11400000, 16642500],
        [ 6000000, 8000000, 8000000, 4000000,  6000000, 2400000, 12000000, 11970000, 17266200],
        [ 6000000, 8000000, 8000000, 4000000,  6600000, 2640000, 12000000, 12540000, 17889900],
        [ 6000000, 8000000, 8000000, 4000000,  7200000, 2880000, 12000000, 13110000, 18513600],
        [ 6000000, 8000000, 8000000, 4000000,  7800000, 3120000, 12000000, 13680000, 19137300],
        [ 6000000, 8000000, 8000000, 4000000,  8400000, 3360000, 12000000, 14250000, 19761000],
        [ 6000000, 8000000, 8000000, 4000000,  9000000, 3600000, 12000000, 14820000, 20384700],
        [ 6000000, 8000000, 8000000, 4000000,  9600000, 3840000, 12000000, 15390000, 21000000],
        [ 6000000, 8000000, 8000000, 4000000, 10200000, 4080000, 12000000, 15960000, 21000000],
        [ 6000000, 8000000, 8000000, 4000000, 10800000, 4320000, 12000000, 16530000, 21000000],
        [ 6000000, 8000000, 8000000, 4000000, 11400000, 4560000, 12000000, 17100000, 21000000],
        [ 6000000, 8000000, 8000000, 4000000, 12000000, 4800000, 12000000, 17670000, 21000000],
        [ 6000000, 8000000, 8000000, 4000000, 12600000, 5040000, 12000000, 18240000, 21000000],
        [ 6000000, 8000000, 8000000, 4000000, 13200000, 5280000, 12000000, 18810000, 21000000],
        [ 6000000, 8000000, 8000000, 4000000, 13800000, 5520000, 12000000, 19380000, 21000000],
        [ 6000000, 8000000, 8000000, 4000000, 14400000, 5760000, 12000000, 20000000, 21000000],
        [ 6000000, 8000000, 8000000, 4000000, 15000000, 6000000, 12000000, 20000000, 21000000],
        [ 6000000, 8000000, 8000000, 4000000, 15000000, 6000000, 12000000, 20000000, 21000000]
    ]

    // Not dependent on actual tests, just make sure test setup is correct
    assert.equal(releaseWallets.length, releasesTable[0].length)

    beforeEach(async () => {
        const snapshot = await timeMachine.takeSnapshot()
        snapshotId = snapshot.result

        dist = await DistributionContract.new(
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
        // await dist.initAllRounds()
        await dist.setSeedRound();
        await dist.setPrivateRound();
        await dist.setStrategicSaleRound();
        await dist.setPublicRound();
        await dist.setTeamRound();
        await dist.setAdvisorsRound();
        await dist.setLiquidityRound();
        await dist.setStrategicRound();
        await dist.setCommunityRound();
        token = await CrodoToken.new(dist.address)
        crodoDecimals = await token.decimals();
        await dist.setTokenAddress(token.address)
        await dist.setTGEDate(TGEDate)
    })

    afterEach(async () => {
        await timeMachine.revertToSnapshot(snapshotId)
    })

    it("test basic attributes of the Crodo token", async () => {
        const tokenCap = new BigNumber(100000000).multipliedBy(1e+18)
        assert.equal(await token.name(), "CrodoToken")
        assert.equal(await token.symbol(), "CROD")
        assert.equal(await token.decimals(), 18)
        assert.equal(
            new BigNumber(await token.cap()).toString(),
            tokenCap.toString()
        )
    })

    it("test the whole distribution", async () => {
        await timeMachine.advanceBlockAndSetTime(TGEDate + day)
        for (let i = 0; i < releasesTable.length; ++i) {
            // await dist.triggerTokenSend()
            await dist.triggerTokenSend()
            for (let j = 0; j < releaseWallets.length; ++j) {
                let wallet = releaseWallets[j]
                let targetBalance = releasesTable[i][j]

                assert.equal(
                    Number(await token.balanceOf(wallet)),
                    amountToLamports(targetBalance, crodoDecimals)
                )
            }
            await timeMachine.advanceTimeAndBlock(month);
        }
    })
})

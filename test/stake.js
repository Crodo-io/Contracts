const TestToken = artifacts.require("TestToken")
const CRDStake = artifacts.require("CRDStake")
const BigNumber = require("bignumber.js")
const timeMachine = require("ganache-time-traveler")

function amountToLamports (amount, decimals) {
    return new BigNumber(amount).multipliedBy(10 ** decimals).integerValue()
}

function cmpRanged (n, n1, range) {
    return Math.abs(n - n1) <= range
}

contract("CrodoToken", (accounts) => {
    let stakeToken
    let stake
    const owner = accounts[0]
    const user1 = accounts[1]

    const day = 60 * 60 * 24
    const month = day * 30
    const year = month * 12

    const lockTimePeriodMin = month
    const lockTimePeriodMax = 2 * year
    const rewardFactor = 1000 * day // Stake 1000 tokens to get reward of 1 token a day
    const stakeDecimals = 12

    beforeEach(async () => {
        const snapshot = await timeMachine.takeSnapshot()
        snapshotId = snapshot.result

        stakeToken = await TestToken.new(stakeDecimals, owner, 0)
        stake = await CRDStake.new(stakeToken.address, lockTimePeriodMin, lockTimePeriodMax)
        await stake.setRewardToken(stakeToken.address)
        await stake.setStakeRewardFactor(rewardFactor)
        await stakeToken.mint(stake.address, amountToLamports(100000, stakeDecimals))
    })

    afterEach(async () => {
        await timeMachine.revertToSnapshot(snapshotId)
    })

    it("stake 20 tokens between 2 users for 6 months & withdraw them", async () => {
        const stakeAmount = amountToLamports(15, stakeDecimals)
        const userStake = amountToLamports(5, stakeDecimals)
        const lockTime = 6 * month

        await stakeToken.mint(owner, stakeAmount)
        await stakeToken.approve(stake.address, stakeAmount)
        await stake.stake(stakeAmount, lockTime)

        await stakeToken.mint(user1, userStake)
        await stakeToken.approve(stake.address, userStake, { from: user1 })
        await stake.stake(userStake, lockTime, { from: user1 })

        assert.equal(
            lockTime,
            Number(await stake.getLockTime(owner))
        )
        assert.equal(
            stakeAmount,
            Number(await stake.stakeAmount(owner))
        )

        const firstAwait = lockTime / 2
        await timeMachine.advanceTimeAndBlock(firstAwait)
        let target = stakeAmount * firstAwait / rewardFactor
        let current = Number(await stake.getEarnedRewardTokens(owner))
        if (!cmpRanged(target, current, target * 0.001)) {
            assert.equal(
                target,
                current
            )
        }

        await timeMachine.advanceTimeAndBlock(lockTime - firstAwait)
        target = current + stakeAmount * (lockTime - firstAwait) / rewardFactor
        current = Number(await stake.getEarnedRewardTokens(owner))
        if (!cmpRanged(target, current, target * 0.001)) {
            assert.equal(
                target,
                current
            )
        }

        target = current + Number(await stakeToken.balanceOf(owner))
        await stake.claim()
        current = Number(await stakeToken.balanceOf(owner))
        if (!cmpRanged(target, current, target * 0.001)) {
            assert.equal(
                target,
                current
            )
        }

        current = Number(await stake.getEarnedRewardTokens(user1))
        target = current + Number(await stakeToken.balanceOf(user1))
        await stake.claim({ from: user1 })
        current = Number(await stakeToken.balanceOf(user1))
        if (!cmpRanged(target, current, target * 0.001)) {
            assert.equal(
                target,
                current
            )
        }
    })

    it("stake 10 tokens for 6 months and restake half way in", async () => {
        const stakeAmount = amountToLamports(10, stakeDecimals)
        const lockTime = 6 * month

        await stakeToken.mint(owner, stakeAmount)
        await stakeToken.approve(stake.address, stakeAmount)
        await stake.stake(stakeAmount, lockTime)

        const firstAwait = lockTime / 2
        await timeMachine.advanceTimeAndBlock(firstAwait)

        const earnedBeforeRestake = Number(await stake.getEarnedRewardTokens(owner))
        const newStakeAmount = Number(stakeAmount) + earnedBeforeRestake
        await stake.restakeRewards()
        await timeMachine.advanceTimeAndBlock(lockTime - firstAwait)

        target = newStakeAmount * (lockTime - firstAwait) / rewardFactor
        current = Number(await stake.getEarnedRewardTokens(owner))
        if (!cmpRanged(target, current, target * 0.001)) {
            assert.equal(
                target,
                current
            )
        }

        target = current + Number(await stakeToken.balanceOf(owner))
        await stake.claim()
        current = Number(await stakeToken.balanceOf(owner))
        if (!cmpRanged(target, current, target * 0.001)) {
            assert.equal(
                target,
                current
            )
        }
    })

    it("user tried to exceed the max stake time limit", async () => {
        const stakeAmount = amountToLamports(10, stakeDecimals)
        const lockTime = lockTimePeriodMax + month

        await stakeToken.mint(owner, stakeAmount)
        await stakeToken.approve(stake.address, stakeAmount)
        await stake.stake(stakeAmount, lockTime).then(res => {
            assert.fail("This shouldn't happen")
        }).catch(desc => {
            assert.equal(desc.reason, "lockTime must by < lockTimePeriodMax")
            // assert.equal(desc.code, -32000)
            // assert.equal(desc.message, "rpc error: code = InvalidArgument desc = execution reverted: : invalid request")
        })
    })
})

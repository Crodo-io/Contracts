const CrodoPrivateSale = artifacts.require("CrodoPrivateSale")
const TestToken = artifacts.require("TestToken")
const BigNumber = require("bignumber.js")
const timeMachine = require("ganache-time-traveler")

function amountToLamports (amount, decimals) {
    return new BigNumber(amount).multipliedBy(10 ** decimals).integerValue()
}

function getTimestamp () {
    return Math.floor(Date.now() / 1000)
}

function cmpRanged (n, n1, range) {
    return Math.abs(n - n1) <= range
}

contract("PrivateSale", (accounts) => {
    let crodoToken
    let usdtToken
    let privateSale
    let usdtPrice
    let tokensForSale
    const owner = accounts[0]
    const user1 = accounts[1]
    const crodoDecimals = 18
    const usdtDecimals = 6

    const day = 60 * 60 * 24
    const month = day * 30

    const releaseInterval = 2 * month
    const initRelease = getTimestamp() + 3 * month
    const totalReleases = 23

    beforeEach(async () => {
        const snapshot = await timeMachine.takeSnapshot()
        snapshotId = snapshot.result

        crodoToken = await TestToken.new(crodoDecimals, owner, 0)
        usdtToken = await TestToken.new(usdtDecimals, owner, 0)
        usdtPrice = amountToLamports(0.15, usdtDecimals)
        tokensForSale = 100000

        privateSale = await CrodoPrivateSale.new(
            crodoToken.address,
            usdtToken.address,
            usdtPrice,
            initRelease,
            totalReleases
        )
        await privateSale.setReleaseInterval(releaseInterval)
        await crodoToken.mint(privateSale.address, amountToLamports(tokensForSale, crodoDecimals))
    })

    afterEach(async () => {
        await timeMachine.revertToSnapshot(snapshotId)
    })

    it("user exceeded their buy limit", async () => {
        const usdtPrice = amountToLamports(0.15 * 50, usdtDecimals)
        await usdtToken.mint(owner, usdtPrice)
        await privateSale.addParticipant(owner, 1, 49)
        await usdtToken.approve(privateSale.address, usdtPrice)

        await privateSale.lockTokens(50).then(res => {
            assert.fail("This shouldn't happen")
        }).catch(desc => {
            assert.equal(desc.reason, "User tried to exceed their buy-high limit")
            // assert.equal(desc.code, -32000)
            // assert.equal(desc.message, "rpc error: code = InvalidArgument desc = execution reverted: User tried to exceed their buy-high limit: invalid request")
        })
    })

    it("user doesn't have enough USDT", async () => {
        const usdtPrice = amountToLamports(0.15 * 10, usdtDecimals)
        // await usdtToken.mint(owner, usdtPrice)
        await privateSale.addParticipant(owner, 1, 100)
        await usdtToken.approve(privateSale.address, usdtPrice)

        await privateSale.lockTokens(10).then(res => {
            assert.fail("This shouldn't happen")
        }).catch(desc => {
            assert.equal(desc.reason, "User doesn't have enough USDT to buy requested tokens")
            // assert.equal(desc.code, -32000)
            // assert.equal(desc.message, "rpc error: code = InvalidArgument desc = execution reverted: User doesn't have enough USDT to buy requested tokens: invalid request")
        })
    })

    it("reserve total of 46 tokens spread by 2 users", async () => {
        const lockingAmount = 23
        const usdtPrice = amountToLamports(0.15 * lockingAmount, usdtDecimals)
        await usdtToken.mint(owner, usdtPrice)
        await privateSale.addParticipant(owner, 1, 100)
        await usdtToken.approve(privateSale.address, usdtPrice)

        await usdtToken.mint(user1, usdtPrice)
        await privateSale.addParticipant(user1, 1, 100)
        await usdtToken.approve(privateSale.address, usdtPrice, { from: user1 })

        let userUSDTBefore = Number(await usdtToken.balanceOf(owner))
        await privateSale.lockTokens(lockingAmount)
        assert.equal(
            Number(amountToLamports(lockingAmount, crodoDecimals)),
            Number(await privateSale.reservedBy(owner))
        )
        assert.equal(
            userUSDTBefore - usdtPrice,
            Number(await usdtToken.balanceOf(owner))
        )

        userUSDTBefore = Number(await usdtToken.balanceOf(user1))
        await privateSale.lockTokens(lockingAmount, { from: user1 })
        assert.equal(
            Number(amountToLamports(lockingAmount, crodoDecimals)),
            Number(await privateSale.reservedBy(user1))
        )
        assert.equal(
            userUSDTBefore - usdtPrice,
            Number(await usdtToken.balanceOf(user1))
        )
    })

    it("Perform full cycle of test-private-sale among 2 users", async () => {
        const lockingAmount = { }
        lockingAmount[owner] = tokensForSale * 0.75
        lockingAmount[user1] = tokensForSale * 0.25

        let usdtPrice = amountToLamports(0.15 * lockingAmount[owner], usdtDecimals)
        await usdtToken.mint(owner, usdtPrice)
        await privateSale.addParticipant(owner, 1, lockingAmount[owner] + 1)
        await usdtToken.approve(privateSale.address, usdtPrice)

        usdtPrice = amountToLamports(0.15 * lockingAmount[user1], usdtDecimals)
        await usdtToken.mint(user1, usdtPrice)
        await privateSale.addParticipant(user1, 1, lockingAmount[user1] + 1)
        await usdtToken.approve(privateSale.address, usdtPrice, { from: user1 })

        let firstLock = lockingAmount[owner] - 100
        await privateSale.lockTokens(firstLock)
        await privateSale.lockTokens(lockingAmount[owner] - firstLock)
        firstLock = lockingAmount[user1] - 100
        await privateSale.lockTokens(firstLock, { from: user1 })
        await privateSale.lockTokens(lockingAmount[user1] - firstLock, { from: user1 })

        await timeMachine.advanceBlockAndSetTime(initRelease + day)

        for (let i = 1; i < totalReleases; ++i) {
            await privateSale.releaseTokens()

            Object.keys(lockingAmount).forEach(async addr => {
                const target = Number(amountToLamports(lockingAmount[addr], crodoDecimals)) * (i / totalReleases)
                const balance = Number(await crodoToken.balanceOf(addr))
                // Due to division on types >8 bytes, either in contract or in javascript,
                // small inpercisions are allowed, the only important thing, is that after the last
                // release numbers must be exact.
                if (!cmpRanged(target, balance, target * 0.001)) {
                    assert.equal(
                        target,
                        balance
                    )
                }
            })
            await timeMachine.advanceTimeAndBlock(releaseInterval)
        }

        await privateSale.releaseTokens()

        let target = Number(amountToLamports(lockingAmount[owner], crodoDecimals))
        let balance = Number(await crodoToken.balanceOf(owner))
        assert.equal(
            target,
            balance
        )

        target = Number(amountToLamports(lockingAmount[user1], crodoDecimals))
        balance = Number(await crodoToken.balanceOf(user1))
        assert.equal(
            target,
            balance
        )

        // Take USDT from contract
        const balanceBefore = Number(await usdtToken.balanceOf(owner))
        const contractUSDT = Number(await usdtToken.balanceOf(privateSale.address))
        await privateSale.pullUSDT(owner, contractUSDT)
        const balanceAfter = Number(await usdtToken.balanceOf(owner))

        assert.equal(
            balanceAfter,
            balanceBefore + contractUSDT
        )
        assert.equal(
            Number(await usdtToken.balanceOf(privateSale.address)),
            0
        )
    })

    it("Lock tokens after sale has started", async () => {
        const lockingAmount = tokensForSale * 0.63

        const usdtPrice = amountToLamports(0.15 * lockingAmount, usdtDecimals)
        await usdtToken.mint(owner, usdtPrice)
        await privateSale.addParticipant(owner, 1, lockingAmount + 1)
        await usdtToken.approve(privateSale.address, usdtPrice)

        await timeMachine.advanceBlockAndSetTime(initRelease + day)

        // Skip 2 releases
        await privateSale.releaseTokens()
        await timeMachine.advanceTimeAndBlock(releaseInterval)
        await privateSale.releaseTokens()

        const firstLock = lockingAmount - 100
        await privateSale.lockTokens(firstLock)
        await privateSale.lockTokens(lockingAmount - firstLock)

        for (let i = 1; i < totalReleases - 2; ++i) {
            await timeMachine.advanceTimeAndBlock(releaseInterval)
            await privateSale.releaseTokens()

            const target = Number(amountToLamports(lockingAmount, crodoDecimals)) * (i / totalReleases)
            const balance = Number(await crodoToken.balanceOf(owner))
            // Due to division on types >8 bytes, either in contract or in javascript,
            // small inpercisions are allowed, the only important thing, is that after the last
            // release numbers must be exact.
            if (!cmpRanged(target, balance, target * 0.001)) {
                assert.equal(
                    target,
                    balance
                )
            }
        }

        await timeMachine.advanceTimeAndBlock(releaseInterval)
        await privateSale.releaseTokens()

        const target = Number(amountToLamports(lockingAmount, crodoDecimals))
        const balance = Number(await crodoToken.balanceOf(owner))
        assert.equal(
            target,
            balance
        )

        // Take USDT from contract
        const balanceBefore = Number(await usdtToken.balanceOf(owner))
        const contractUSDT = Number(await usdtToken.balanceOf(privateSale.address))
        await privateSale.pullUSDT(owner, contractUSDT)
        const balanceAfter = Number(await usdtToken.balanceOf(owner))

        assert.equal(
            balanceAfter,
            balanceBefore + contractUSDT
        )
        assert.equal(
            Number(await usdtToken.balanceOf(privateSale.address)),
            0
        )
    })

    // TODO: REWRITE THIS TEST, IT WASN'T FINISHED, JUST COPIED
    it("Stake before and after sale has started", async () => {
        const lockingAmount = tokensForSale * 0.63

        const usdtPrice = amountToLamports(0.15 * lockingAmount, usdtDecimals)
        await usdtToken.mint(owner, usdtPrice)
        await privateSale.addParticipant(owner, 1, lockingAmount + 1)
        await usdtToken.approve(privateSale.address, usdtPrice)

        await timeMachine.advanceBlockAndSetTime(initRelease + day)

        let currLocked = lockingAmount / 3
        await privateSale.lockTokens(currLocked)

        // Wait 2 releases
        await privateSale.releaseTokens()
        await timeMachine.advanceTimeAndBlock(releaseInterval)
        await privateSale.releaseTokens()

        let target = amountToLamports(currLocked * (2 / totalReleases), crodoDecimals)
        let balance = Number(await crodoToken.balanceOf(owner))
        if (!cmpRanged(target, balance, target * 0.001)) {
            assert.equal(
                target,
                balance
            )
        }

        // Lock another batch of tokens and wait another 2 releases
        await privateSale.lockTokens(currLocked)
        await timeMachine.advanceTimeAndBlock(releaseInterval)
        await privateSale.releaseTokens()
        await timeMachine.advanceTimeAndBlock(releaseInterval)
        await privateSale.releaseTokens()

        currLocked *= 2
        target = balance + Number(amountToLamports(currLocked * (2 / totalReleases), crodoDecimals))
        balance = Number(await crodoToken.balanceOf(owner))
        if (!cmpRanged(target, balance, target * 0.001)) {
            assert.equal(
                target,
                balance
            )
        }

        privateSale.lockTokens(lockingAmount - currLocked)
        currLocked = lockingAmount
        const alreadyReleased = balance

        for (let i = 1; i < totalReleases - 4; ++i) {
            await timeMachine.advanceTimeAndBlock(releaseInterval)
            await privateSale.releaseTokens()

            target = alreadyReleased +
                Number(amountToLamports(lockingAmount, crodoDecimals)) * (i / totalReleases)
            balance = Number(await crodoToken.balanceOf(owner))
            // Due to division on types >8 bytes, either in contract or in javascript,
            // small inpercisions are allowed, the only important thing, is that after the last
            // release numbers must be exact.
            if (!cmpRanged(target, balance, target * 0.001)) {
                assert.equal(
                    target,
                    balance
                )
            }
        }

        await timeMachine.advanceTimeAndBlock(releaseInterval)
        await privateSale.releaseTokens()

        target = Number(amountToLamports(lockingAmount, crodoDecimals))
        balance = Number(await crodoToken.balanceOf(owner))
        assert.equal(
            target,
            balance
        )

        // Take USDT from contract
        const balanceBefore = Number(await usdtToken.balanceOf(owner))
        const contractUSDT = Number(await usdtToken.balanceOf(privateSale.address))
        await privateSale.pullUSDT(owner, contractUSDT)
        const balanceAfter = Number(await usdtToken.balanceOf(owner))

        assert.equal(
            balanceAfter,
            balanceBefore + contractUSDT
        )
        assert.equal(
            Number(await usdtToken.balanceOf(privateSale.address)),
            0
        )
    })

    it("test admin functions", async () => {
        const userReserve = 30
        await privateSale.addParticipant(user1, 1, 49)
        const firstReserve = userReserve - 15
        await privateSale.lockForParticipant(user1, firstReserve)
        await privateSale.lockForParticipant(user1, userReserve - firstReserve)

        assert.equal(
            Number(await privateSale.reservedBy(user1)),
            amountToLamports(userReserve, crodoDecimals)
        )
    })
})

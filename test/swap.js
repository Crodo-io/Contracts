const FixedSwap = artifacts.require("FixedSwap")
const TestToken = artifacts.require("TestToken")
const BigNumber = require("bignumber.js")
const timeMachine = require('ganache-time-traveler');

function amountToLamports (amount, decimals) {
    return new BigNumber(amount).multipliedBy(10 ** decimals).integerValue()
}

function getTimestamp() {
    return Math.floor(Date.now() / 1000)
}

contract("FixedSwap", (accounts) => {
    let fixedSwap
    let askToken
    let bidToken
    const owner = accounts[0]
    const feeAddress = accounts[1]

    const day = 60 * 60 * 24
    const month = day * 30
    const year = month * 12
    const askDecimals = 12
    const bidDecimals = 12
    const feePercentage = 1
    const tradeValue = amountToLamports(0.15, askDecimals)
    const tokensForSale = amountToLamports(100000, bidDecimals)
    const minAmount = amountToLamports(1, bidDecimals)
    const maxAmount = amountToLamports(100, bidDecimals)

    beforeEach(async () => {
        let snapshot = await timeMachine.takeSnapshot();
        snapshotId = snapshot['result'];

        askToken = await TestToken.new(askDecimals, owner, 0)
        bidToken = await TestToken.new(bidDecimals, owner, 0)
        fixedSwap = await FixedSwap.new(
            askToken.address,
            bidToken.address,
            tradeValue,
            tokensForSale,
            getTimestamp() + day,
            getTimestamp() + 6 * month,
            minAmount,
            maxAmount,
            false,
            amountToLamports(10000, bidDecimals),
            feeAddress,
            false
        )
        await fixedSwap.setFeePercentage(feePercentage);
    })

    afterEach(async() => {
        await timeMachine.revertToSnapshot(snapshotId);
    });

    it("basic swap", async () => {
        const swapAmount = amountToLamports(25, bidDecimals)
        const swapCost = swapAmount * tradeValue / (10 ** bidDecimals)
        await askToken.mint(owner, swapCost)
        await askToken.approve(fixedSwap.address, swapCost)

        await bidToken.mint(owner, tokensForSale)
        await bidToken.approve(fixedSwap.address, tokensForSale)
        await fixedSwap.fund(tokensForSale)

        assert.equal(
            Number(await bidToken.balanceOf(fixedSwap.address)),
            tokensForSale
        )
        assert.ok(await fixedSwap.isPreStart())

        // Skip 2 days to wait for the start date of the swap pool
        await timeMachine.advanceTimeAndBlock(day * 2)

        assert.ok(await fixedSwap.hasStarted())
        assert.ok(await fixedSwap.isOpen())

        let askBalanceBefore = await askToken.balanceOf(fixedSwap.address)
        await fixedSwap.swap(swapAmount)
        assert.equal(
            Number(await fixedSwap.boughtByAddress(owner)),
            swapAmount
        )
        assert.equal(
            Number(askBalanceBefore) + swapCost,
            Number(await askToken.balanceOf(fixedSwap.address))
        )

        // Wait for sale to end
        await timeMachine.advanceTimeAndBlock(month * 6)
        assert.ok(await fixedSwap.hasFinalized())
        await fixedSwap.redeemTokens(0);

        assert.equal(
            Number(await bidToken.balanceOf(owner)),
            Number(swapAmount)
        )
    })
})

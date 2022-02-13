const CrodoPrivateSale = artifacts.require("CrodoPrivateSale")
const TestToken = artifacts.require("TestToken")
const BigNumber = require("bignumber.js")

function amount_to_lamports(amount, decimals) {
    return new BigNumber(amount).multipliedBy(10 ** decimals)
}

contract("CrodoToken", (accounts) => {
    let crodoToken
    let usdtToken
    let privateSale
    let usdtPrice
    let tokensForSale
    const owner = accounts[0]
    const participant1 = accounts[1]
    const crodoDecimals = 18
    const usdtDecimals = 18

    beforeEach(async () => {
        crodoToken = await TestToken.new(crodoDecimals, owner, 0)
        usdtToken = await TestToken.new(usdtDecimals, owner, 0)
        usdtPrice = amount_to_lamports(0.15, usdtDecimals)
        tokensForSale = amount_to_lamports(100000, crodoDecimals)

        privateSale = await CrodoPrivateSale.new(crodoToken.address, usdtToken.address, usdtPrice)
        await crodoToken.mint(privateSale.address, tokensForSale)
    })

    it("user exceeded their buy limit", async () => {
        let usdtPrice = amount_to_lamports(0.15 * 50, usdtDecimals)
        await usdtToken.mint(owner, usdtPrice)
        await privateSale.addParticipant(owner, 1, 49)
        await usdtToken.approve(privateSale.address, usdtPrice)

        privateSale.lockTokens(50).then(res => {
            assert.fail("This shouldn't happen")
        }).catch(desc => {
            assert.equal(desc.code, -32000)
            assert.equal(desc.message, "rpc error: code = InvalidArgument desc = execution reverted: User tried to exceed their buy-high limit: invalid request")
        })
    })

    it("user doesn't have enough USDT", async () => {
        let usdtPrice = amount_to_lamports(0.15 * 10, usdtDecimals)
        // await usdtToken.mint(owner, usdtPrice)
        await privateSale.addParticipant(owner, 1, 100)
        await usdtToken.approve(privateSale.address, usdtPrice)

        privateSale.lockTokens(10).then(res => {
            assert.fail("This shouldn't happen")
        }).catch(desc => {
            assert.equal(desc.code, -32000)
            assert.equal(desc.message, "rpc error: code = InvalidArgument desc = execution reverted: User doesn't have enough USDT to buy requested tokens: invalid request")
        })
    })

    it("reserve and release 10 tokens", async () => {
        let usdtPrice = amount_to_lamports(0.15 * 10, usdtDecimals)
        await usdtToken.mint(owner, usdtPrice)
        await privateSale.addParticipant(owner, 1, 100)
        await usdtToken.approve(privateSale.address, usdtPrice)

        let userUSDTBefore = Number(await usdtToken.balanceOf(owner))
        await privateSale.lockTokens(10)

        assert.equal(
            Number(await privateSale.reservedBy(owner)),
            amount_to_lamports(10, usdtDecimals)
        )
        assert.equal(
            userUSDTBefore - usdtPrice,
            Number(await usdtToken.balanceOf(owner))
        )

        await privateSale.releaseTokens()
        assert.equal(
            amount_to_lamports(10, crodoDecimals),
            Number(await crodoToken.balanceOf(owner))
        )
    })
})
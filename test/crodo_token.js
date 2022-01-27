const DistributionContract = artifacts.require("CrodoDistributionContract")
const CrodoToken = artifacts.require("CrodoToken")

contract("CrodoToken", (accounts) => {
    let token
    const owner = accounts[0]
    const recipient = accounts[1]

    beforeEach(async () => {
        const dist = await DistributionContract.new()
        token = await CrodoToken.new(dist.address)
    })

    it("test basic attributes of the Crodo token", async () => {
        assert.equal(await token.name(), "CrodoToken")
        assert.equal(await token.symbol(), "CROD")
        assert.equal(await token.decimals(), 18)
    })

    it("test mint and transfer of tokens", async () => {
        const mintAmount = 100
        const transferAmount = 50
        await token.mint(owner, mintAmount)
        assert.equal(await token.balanceOf(owner), mintAmount)

        await token.transfer(recipient, transferAmount)
        assert.equal(await token.balanceOf(recipient), transferAmount)
        assert.equal(await token.balanceOf(owner), mintAmount - transferAmount)
    })

    it("transfer instruction emits Transfer event", async () => {
        const mintAmount = 100
        const transferAmount = 50
        await token.mint(owner, mintAmount)
        const { logs } = await token.transfer(recipient, transferAmount)
        const event = logs.find(e => e.event === "Transfer")
        assert.notEqual(event, undefined)
    })
})

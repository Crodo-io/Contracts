const DistributionContract = artifacts.require("CrodoDistributionContract");
const CrodoToken = artifacts.require("CrodoToken");

contract("CrodoToken", (accounts) => {
    let token;
    const owner = accounts[0];
    const recipient = accounts[1];

    beforeEach(async () => {
        const dist = await DistributionContract.new();
        token = await CrodoToken.new(dist.address);
    });

    it("test basic attributes of the Crodo token", async () => {
        assert.equal(await token.name(), "CrodoToken");
        assert.equal(await token.symbol(), "CROD");
        assert.equal(await token.decimals(), 18);
    });

    it("test mint and transfer of tokens", async () => {
        const mint_amount = 100;
        const transfer_amount = 50;
        await token.mint(owner, mint_amount);
        assert.equal(await token.balanceOf(owner), mint_amount);

        await token.transfer(recipient, transfer_amount);
        assert.equal(await token.balanceOf(recipient), transfer_amount);
        assert.equal(await token.balanceOf(owner), mint_amount - transfer_amount);
    });

    it("transfer instruction emits Transfer event", async() => {
        const mint_amount = 100;
        const transfer_amount = 50;
        await token.mint(owner, mint_amount);
        const { logs } = await token.transfer(recipient, transfer_amount);
        const event = logs.find(e => e.event == "Transfer");
        assert.notEqual(event, undefined);
    });
})

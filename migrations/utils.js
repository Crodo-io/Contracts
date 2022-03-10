const BigNumber = require("bignumber.js")
// Arguments are expected to be date identifiers in the following order:
// year, month, day, hour, minute, second
function getUnixDate (...args) {
    return Math.floor(new Date(...args).getTime() / 1000)
}

function amountToLamports (amount, decimals) {
    return new BigNumber(amount).multipliedBy(10 ** decimals).integerValue()
}

module.exports = { getUnixDate, amountToLamports }

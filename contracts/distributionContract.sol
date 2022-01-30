// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/*
 * Params for the CROD token:
 * Total supply - 100_000_000 CROD
 * Initial supply - 26_300_000 CROD
 *
 * Implemented vesting:
 *
 * 5% Seed - 20% unlocked at listing, 20% each month thereafter
 * 6% Private sale - 20% unlocked at listing, 20% each month thereafter
 * 2% Public sale - 20% unlocked at listing, 20% each month thereafter
 * 25% Team - 100% locked for 7 month, 10% unlocked each month thereafter
 * 5% Advisors - 100% locked for 7 months, 10% unlocked each month thereafter
 * 20% Liquidity - Fully unlocked
 * 32% marketing, staking rewards, airdrops, ambassador program - 10% unlocked, 5% unlocked each month. \
 *   Unused tokens for these purposes will be burned.
 */

contract CrodoDistributionContract is Pausable, Ownable {
    using SafeMath for uint256;

    uint256 public constant decimals = 1 ether;
    address[] public tokenOwners; /* Tracks distributions mapping (iterable) */
    uint48 public TGEDate = 0; /* Date From where the distribution starts (TGE) */
    uint256 public constant month = 30 days;
    uint256 public constant year = 365 days;
    uint256 public lastDateDistribution = 0;

    // TODO: Replace these addresses with correct ones
    address seedWallet = 0xA4399b7C8a6790c0c9174a68f512D10A791664e1;
    address privSaleWallet = 0xA4399b7C8a6790c0c9174a68f512D10A791664e1;
    address pubSaleWallet = 0xA4399b7C8a6790c0c9174a68f512D10A791664e1;
    address teamWallet = 0xA4399b7C8a6790c0c9174a68f512D10A791664e1;
    address advisorsWallet = 0xA4399b7C8a6790c0c9174a68f512D10A791664e1;
    address liquidityWallet = 0xA4399b7C8a6790c0c9174a68f512D10A791664e1;
    address otherWallet = 0xA4399b7C8a6790c0c9174a68f512D10A791664e1;

    mapping(address => DistributionStep[]) public distributions; /* Distribution object */

    ERC20 public erc20;

    struct DistributionStep {
        uint256 amountAllocated;
        uint256 currentAllocated;
        uint256 unlockDay;
        uint256 amountSent;
    }

    constructor() {
        setSeedRound();
        setPrivateRound();
        // setPublicRound();
        // setTeamRound();
        // setAdvisorsRound();
        // setLiquidityRound();
        // setOtherRound();
    }

    function setSeedRound() internal onlyOwner {
        // 5% Seed - 20% unlocked at listing, 20% each month thereafter
        for (uint8 i = 0; i < 5; ++i) {
            setInitialDistribution(seedWallet, 1000000, i * month);
        }
    }

    function setPrivateRound() internal onlyOwner {
        // 6% Private sale - 20% unlocked at listing, 20% each month thereafter
        for (uint8 i = 0; i < 5; ++i) {
            setInitialDistribution(privSaleWallet, 1200000, i * month);
        }
    }

    function setPublicRound() internal onlyOwner {
        // 2% Public sale - 20% unlocked at listing, 20% each month thereafter
        for (uint8 i = 0; i < 5; ++i) {
            setInitialDistribution(pubSaleWallet, 400000, i * month);
        }
    }

    function setTeamRound() internal onlyOwner {
        // 25% Team - 100% locked for 7 month, 10% unlocked each month thereafter
        for (uint8 i = 7; i < 17; ++i) {
            setInitialDistribution(teamWallet, 2500000, i * month);
        }
    }

    function setAdvisorsRound() internal onlyOwner {
        // 5% Advisors - 100% locked for 7 months, 10% unlocked each month thereafter
        for (uint8 i = 7; i < 17; ++i) {
            setInitialDistribution(advisorsWallet, 500000, i * month);
        }
    }

    function setLiquidityRound() internal onlyOwner {
        // 20% Liquidity - Fully unlocked
        setInitialDistribution(liquidityWallet, 20000000, 0);
    }

    function setOtherRound() internal onlyOwner {
        // 32% marketing, staking rewards, airdrops, ambassador program - 10% unlocked, 5% unlocked each month.
        setInitialDistribution(otherWallet, 10000000, 0);
        for (uint8 i = 1; i < 17; ++i) {
            setInitialDistribution(otherWallet, 5000000, i * month);
        }
    }

    function setTokenAddress(address _tokenAddress)
        external
        onlyOwner
        whenNotPaused
    {
        erc20 = ERC20(_tokenAddress);
    }

    function safeGuardAllTokens(address _address)
        external
        onlyOwner
        whenPaused
    {
        /* In case of needed urgency for the sake of contract bug */
        require(erc20.transfer(_address, erc20.balanceOf(address(this))));
    }

    function setTGEDate(uint48 _time) external onlyOwner whenNotPaused {
        TGEDate = _time;
    }

    /**
     *   Should allow any address to trigger it, but since the calls are atomic it should do only once per day
     */

    function triggerTokenSend() external whenNotPaused {
        /* Require TGE Date already been set */
        require(TGEDate != 0, "TGE date not set yet");
        /* TGE has not started */
        require(block.timestamp > TGEDate, "TGE still hasn't started");
        /* Test that the call be only done once per day */
        require(
            block.timestamp.sub(lastDateDistribution) > 1 days,
            "Can only be called once a day"
        );
        lastDateDistribution = block.timestamp;
        /* Go thru all tokenOwners */
        for (uint256 i = 0; i < tokenOwners.length; i++) {
            /* Get Address Distribution */
            DistributionStep[] memory d = distributions[tokenOwners[i]];
            /* Go thru all distributions array */
            for (uint256 j = 0; j < d.length; j++) {
                /* If lock time has passed and address didn't take all the tokens already */
                if (
                    (block.timestamp.sub(TGEDate) > d[j].unlockDay) &&
                    (d[j].currentAllocated > 0)
                ) {
                    uint256 sendingAmount = d[j].currentAllocated;
                    distributions[tokenOwners[i]][j]
                        .currentAllocated = distributions[tokenOwners[i]][j]
                        .currentAllocated
                        .sub(sendingAmount);
                    distributions[tokenOwners[i]][j].amountSent = distributions[
                        tokenOwners[i]
                    ][j].amountSent.add(sendingAmount);
                    require(erc20.transfer(tokenOwners[i], sendingAmount));
                }
            }
        }
    }

    function setInitialDistribution(
        address _address,
        uint256 _tokenAmount,
        uint256 _unlockDays
    ) internal onlyOwner whenNotPaused {
        /* Add tokenOwner to Eachable Mapping */
        bool isAddressPresent = false;

        /* Verify if tokenOwner was already added */
        for (uint256 i = 0; i < tokenOwners.length; i++) {
            if (tokenOwners[i] == _address) {
                isAddressPresent = true;
                break;
            }
        }
        /* Create DistributionStep Object */
        DistributionStep memory distributionStep = DistributionStep(
            _tokenAmount * decimals,
            _tokenAmount * decimals,
            _unlockDays,
            0
        );
        /* Attach */
        distributions[_address].push(distributionStep);

        /* If Address not present in array of iterable token owners */
        if (!isAddressPresent) {
            tokenOwners.push(_address);
        }
    }
}

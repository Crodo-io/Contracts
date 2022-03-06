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
 * 6% Seed - cliff for 6 month, 3.7% unlocked each month within 27 months
 * 8% Private sale - cliff for 3 month, 3,85% unlocked each month within 26 months
 * 8% Strategic sale - cliff for 3 month, 4,17% unlocked each month within 24 months
 * 4% Public sale - 12% unlocked, cliff for 3 month, 17,6% unlocked each month within 5 months
 * 15% Team - cliff for 17 months, 4% unlocked each month within 25 months
 * 6% Advisors - cliff for 17 months, 4% unlocked each month within 25 months
 * 12% Liquidity - Fully unlocked
 * 20% Strategic Reserve - cliff for 6 month, 2,85% unlocked each month within 35 months
 * 21% Community / Ecosystem - 5% unlocked, 2,97% unlocked each month within 33 months
 */

contract CrodoDistributionContract is Pausable, Ownable {
    using SafeMath for uint256;

    uint256 public decimals;
    address[] public tokenOwners; /* Tracks distributions mapping (iterable) */
    uint48 public TGEDate = 0; /* Date From where the distribution starts (TGE) */
    uint256 public constant month = 30 days;
    uint256 public constant year = 365 days;
    uint256 public lastDateDistribution = 0;

    // All these addresses must be unique
    address public seedWallet;
    address public privSaleWallet;
    address public strategicSaleWallet;
    address public pubSaleWallet;
    address public teamWallet;
    address public advisorsWallet;
    address public liquidityWallet;
    address public strategicWallet;
    address public communityWallet;

    mapping(address => DistributionStep[]) public distributions; /* Distribution object */

    ERC20 public erc20;

    struct DistributionStep {
        uint256 amountAllocated;
        uint256 currentAllocated;
        uint256 unlockDay;
        uint256 amountSent;
    }

    constructor(
        address _seedWallet,
        address _privSaleWallet,
        address _strategicSaleWallet,
        address _pubSaleWallet,
        address _teamWallet,
        address _advisorsWallet,
        address _liquidityWallet,
        address _strategicWallet,
        address _communityWallet
    ) Ownable() Pausable() {
        seedWallet = _seedWallet;
        privSaleWallet = _privSaleWallet;
        strategicSaleWallet = _strategicSaleWallet;
        pubSaleWallet = _pubSaleWallet;
        teamWallet = _teamWallet;
        advisorsWallet = _advisorsWallet;
        liquidityWallet = _liquidityWallet;
        strategicWallet = _strategicWallet;
        communityWallet = _communityWallet;
    }

    function initAllRounds() external onlyOwner {
        setSeedRound();
        setPrivateRound();
        setStrategicSaleRound();
        setPublicRound();
        setTeamRound();
        setAdvisorsRound();
        setLiquidityRound();
        setStrategicRound();
        setCommunityRound();
    }

    function setSeedRound() public onlyOwner {
        require(
            distributions[seedWallet].length == 0,
            "Catched try to reinitialize already initialized round"
        );
        // 6% Seed - cliff for 6 month, 3.7% unlocked each month within 27 months
        // The locking and vesting is done in seed sale contract.
        setInitialDistribution(seedWallet, 6000000, 0);
    }

    function setPrivateRound() public onlyOwner {
        require(
            distributions[privSaleWallet].length == 0,
            "Catched try to reinitialize already initialized round"
        );
        // 8% Private sale - cliff for 3 month, 3,85% unlocked each month within 26 months
        // The locking and vesting is done in private sale contract.
        setInitialDistribution(privSaleWallet, 8000000, 0);
    }

    function setStrategicSaleRound() public onlyOwner {
        require(
            distributions[strategicSaleWallet].length == 0,
            "Catched try to reinitialize already initialized round"
        );
        // 8% Strategic sale - cliff for 3 month, 4,17% unlocked each month within 24 months
        // The locking and vesting is done in strategic sale contract.
        setInitialDistribution(strategicSaleWallet, 8000000, 0);
    }

    function setPublicRound() public onlyOwner {
        require(
            distributions[pubSaleWallet].length == 0,
            "Catched try to reinitialize already initialized round"
        );
        // 4% Public sale - 12% unlocked, cliff for 3 month, 17,6% unlocked each month within 5 months
        setInitialDistribution(pubSaleWallet, 4000000, 0);
    }

    function setTeamRound() public onlyOwner {
        require(
            distributions[teamWallet].length == 0,
            "Catched try to reinitialize already initialized round"
        );
        // 15% Team - cliff for 17 months, 4% unlocked each month within 25 months
        for (uint8 i = 17; i < 42; ++i) {
            setInitialDistribution(teamWallet, 600000, i * month);
        }
    }

    function setAdvisorsRound() public onlyOwner {
        require(
            distributions[advisorsWallet].length == 0,
            "Catched try to reinitialize already initialized round"
        );
        // 6% Advisors - cliff for 17 months, 4% unlocked each month within 25 months
        for (uint8 i = 17; i < 42; ++i) {
            setInitialDistribution(advisorsWallet, 240000, i * month);
        }
    }

    function setLiquidityRound() public onlyOwner {
        require(
            distributions[liquidityWallet].length == 0,
            "Catched try to reinitialize already initialized round"
        );
        // 12% Liquidity - Fully unlocked
        setInitialDistribution(liquidityWallet, 12000000, 0);
    }

    function setStrategicRound() public onlyOwner {
        require(
            distributions[strategicWallet].length == 0,
            "Catched try to reinitialize already initialized round"
        );
        // 20% Strategic Reserve - cliff for 6 month, 2,85% unlocked each month within 35 months
        uint256 amountEachRound = 570000;
        for (uint8 i = 6; i < 40; ++i) {
            setInitialDistribution(strategicWallet, amountEachRound, i * month);
        }
        setInitialDistribution(strategicWallet, 20000000 - (amountEachRound * 34), 40 * month);
    }

    function setCommunityRound() public onlyOwner {
        require(
            distributions[communityWallet].length == 0,
            "Catched try to reinitialize already initialized round"
        );
        // 21% Community / Ecosystem - 5% unlocked, 2,97% unlocked each month within 32 months
        uint256 amountEachRound = 623700;
        setInitialDistribution(communityWallet, 1050000, 0);
        uint256 remainingForDist = 21000000 - 1050000;
        for (uint8 i = 1; i < 32; ++i) {
            setInitialDistribution(communityWallet, amountEachRound, i * month);
        }
        setInitialDistribution(communityWallet, remainingForDist - (amountEachRound * 31), 32 * month);
    }

    function setTokenAddress(address _tokenAddress)
        external
        onlyOwner
        whenNotPaused
    {
        erc20 = ERC20(_tokenAddress);
        decimals = 10 ** erc20.decimals();
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

    function getTGEDate() external view returns (uint48) {
        return TGEDate;
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

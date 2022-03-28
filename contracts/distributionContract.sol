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
    uint48 public TGEDate = 0; /* Date From where the distribution starts (TGE) */
    uint256 public constant month = 30 days;
    uint256 public constant year = 365 days;
    uint256 public lastDateDistribution = 0;

    // All these addresses must be unique
    address[] public seedWallet;
    address[] public privSaleWallet;
    address[] public strategicSaleWallet;
    address[] public pubSaleWallet;
    address[] public teamWallet;
    address[] public teamWallets = [
        0xcF528152C7619E23d0c6A16de75E6B30A45Bf502,
        0x72245A3E23E7F73e5eaD2857b990b74a27FB95d4,
        0xC1A14B3CC70d3a1FD4f8e45FeA6B0c755f5a3D4A,
        0xC6F8fa17836fEebBD836f7F5986942e8d102B683
    ]; // TODO: Change these to correct addresses
    address[] public advisorsWallet;
    address[] public liquidityWallet;
    address[] public strategicWallet;
    address[] public communityWallet;

    uint256 private currentCategory;
    /* Distribution object */
    mapping(uint256 => DistributionCategory) private distributionCategories;

    ERC20 public erc20;

    struct DistributionCategory {
        address[] destinations;
        DistributionStep[] distributions;
    }

    struct DistributionStep {
        uint256 amountAllocated;
        uint256 currentAllocated;
        uint256 unlockDay;
        uint256 amountSent;
    }

    constructor(
        address[] memory _seedWallet,
        address[] memory _privSaleWallet,
        address[] memory _strategicSaleWallet,
        address[] memory _pubSaleWallet,
        address[] memory _advisorsWallet,
        address[] memory _liquidityWallet,
        address[] memory _strategicWallet,
        address[] memory _communityWallet
    ) Ownable() Pausable() {
        seedWallet = _seedWallet;
        privSaleWallet = _privSaleWallet;
        strategicSaleWallet = _strategicSaleWallet;
        pubSaleWallet = _pubSaleWallet;
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
        // 6% Seed - cliff for 6 month, 3.7% unlocked each month within 27 months
        // The locking and vesting is done in seed sale contract.
        initializeDistributionCategory(currentCategory, seedWallet);
        addDistributionToCategory(currentCategory, 6000000, 0);
        ++currentCategory;
    }

    function setPrivateRound() public onlyOwner {
        // 8% Private sale - cliff for 3 month, 3,85% unlocked each month within 26 months
        // The locking and vesting is done in private sale contract.
        initializeDistributionCategory(currentCategory, privSaleWallet);
        addDistributionToCategory(currentCategory, 8000000, 0);
        ++currentCategory;
    }

    function setStrategicSaleRound() public onlyOwner {
        // 8% Strategic sale - cliff for 3 month, 4,17% unlocked each month within 24 months
        // The locking and vesting is done in strategic sale contract.
        initializeDistributionCategory(currentCategory, strategicSaleWallet);
        addDistributionToCategory(currentCategory, 8000000, 0);
        ++currentCategory;
    }

    function setPublicRound() public onlyOwner {
        // 4% Public sale - 12% unlocked, cliff for 3 month, 17,6% unlocked each month within 5 months
        initializeDistributionCategory(currentCategory, pubSaleWallet);
        addDistributionToCategory(currentCategory, 4000000, 0);
        ++currentCategory;
    }

    function setTeamRound() public onlyOwner {
        // 15% Team - cliff for 17 months, 4% unlocked each month within 25 months
        initializeDistributionCategory(currentCategory, teamWallets);
        for (uint8 i = 17; i < 42; ++i) {
            addDistributionToCategory(currentCategory, 600000, i * month);
        }
        ++currentCategory;
    }

    function setAdvisorsRound() public onlyOwner {
        // 6% Advisors - cliff for 17 months, 4% unlocked each month within 25 months
        initializeDistributionCategory(currentCategory, advisorsWallet);
        for (uint8 i = 17; i < 42; ++i) {
            addDistributionToCategory(currentCategory, 240000, i * month);
        }
        ++currentCategory;
    }

    function setLiquidityRound() public onlyOwner {
        // 12% Liquidity - Fully unlocked
        initializeDistributionCategory(currentCategory, liquidityWallet);
        addDistributionToCategory(currentCategory, 12000000, 0);
        ++currentCategory;
    }

    function setStrategicRound() public onlyOwner {
        // 20% Strategic Reserve - cliff for 6 month, 2,85% unlocked each month within 35 months
        initializeDistributionCategory(currentCategory, strategicWallet);
        uint256 amountEachRound = 570000;
        for (uint8 i = 6; i < 40; ++i) {
            addDistributionToCategory(
                currentCategory,
                amountEachRound,
                i * month
            );
        }
        addDistributionToCategory(
            currentCategory,
            20000000 - (amountEachRound * 34),
            40 * month
        );
        ++currentCategory;
    }

    function setCommunityRound() public onlyOwner {
        // 21% Community / Ecosystem - 5% unlocked, 2,97% unlocked each month within 32 months
        initializeDistributionCategory(currentCategory, communityWallet);
        uint256 amountEachRound = 623700;
        addDistributionToCategory(currentCategory, 1050000, 0);
        uint256 remainingForDist = 21000000 - 1050000;
        for (uint8 i = 1; i < 32; ++i) {
            addDistributionToCategory(
                currentCategory,
                amountEachRound,
                i * month
            );
        }
        addDistributionToCategory(
            currentCategory,
            remainingForDist - (amountEachRound * 31),
            32 * month
        );
        ++currentCategory;
    }

    function setTokenAddress(address _tokenAddress)
        external
        onlyOwner
        whenNotPaused
    {
        erc20 = ERC20(_tokenAddress);
        decimals = 10**erc20.decimals();
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
        for (uint256 i = 0; i < currentCategory; i++) {
            /* Get Address Distribution */
            DistributionCategory storage category = distributionCategories[i];
            DistributionStep[] storage d = category.distributions;
            /* Go thru all distributions array */
            for (uint256 j = 0; j < d.length; j++) {
                /* If lock time has passed and address didn't take all the tokens already */
                if (
                    (block.timestamp.sub(TGEDate) > d[j].unlockDay) &&
                    (d[j].currentAllocated > 0)
                ) {
                    uint256 sendingAmount = d[j].currentAllocated;
                    uint256 amountEach = sendingAmount /
                        category.destinations.length;
                    for (uint32 t = 0; t < category.destinations.length; t++) {
                        require(
                            erc20.transfer(category.destinations[t], amountEach)
                        );
                    }
                    d[j].currentAllocated = d[j].currentAllocated.sub(
                        sendingAmount
                    );
                    d[j].amountSent = d[j].amountSent.add(sendingAmount);
                }
            }
        }
    }

    function initializeDistributionCategory(
        uint256 _category,
        address[] memory _destinations
    ) internal onlyOwner whenNotPaused {
        distributionCategories[_category].destinations = _destinations;
    }

    function addDistributionToCategory(
        uint256 _category,
        uint256 _tokenAmount,
        uint256 _unlockDays
    ) internal onlyOwner whenNotPaused {
        /* Create DistributionStep Object */
        DistributionStep memory step = DistributionStep(
            _tokenAmount * decimals,
            _tokenAmount * decimals,
            _unlockDays,
            0
        );
        /* Attach */
        distributionCategories[_category].distributions.push(step);
    }
}

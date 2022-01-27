// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CrodoDistributionContract is Pausable, Ownable {
    using SafeMath for uint256;

    uint256 public constant decimals = 1 ether;
    address[] public tokenOwners; /* Tracks distributions mapping (iterable) */
    uint256 public TGEDate = 0; /* Date From where the distribution starts (TGE) */
    uint256 public constant month = 30 days;
    uint256 public constant year = 365 days;
    uint256 public lastDateDistribution = 0;

    mapping(address => DistributionStep[]) public distributions; /* Distribution object */

    ERC20 public erc20;

    struct DistributionStep {
        uint256 amountAllocated;
        uint256 currentAllocated;
        uint256 unlockDay;
        uint256 amountSent;
    }

    constructor() public {
        /* Seed */
        setInitialDistribution(
            0xA4399b7C8a6790c0c9174a68f512D10A791664e1,
            3000000,
            0 /* No Lock */
        );
        setInitialDistribution(
            0xA4399b7C8a6790c0c9174a68f512D10A791664e1,
            1500000,
            1 * month
        ); /* After 1 Month */
        setInitialDistribution(
            0xA4399b7C8a6790c0c9174a68f512D10A791664e1,
            1500000,
            2 * month
        ); /* After 2 Months */
        setInitialDistribution(
            0xA4399b7C8a6790c0c9174a68f512D10A791664e1,
            1500000,
            3 * month
        ); /* After 3 Months */
        setInitialDistribution(
            0xA4399b7C8a6790c0c9174a68f512D10A791664e1,
            1500000,
            4 * month
        ); /* After 4 Months */
        setInitialDistribution(
            0xA4399b7C8a6790c0c9174a68f512D10A791664e1,
            1500000,
            5 * month
        ); /* After 5 Months */
        setInitialDistribution(
            0xA4399b7C8a6790c0c9174a68f512D10A791664e1,
            1500000,
            6 * month
        ); /* After 6 Months */
        setInitialDistribution(
            0xA4399b7C8a6790c0c9174a68f512D10A791664e1,
            1500000,
            7 * month
        ); /* After 7 Months */
        setInitialDistribution(
            0xA4399b7C8a6790c0c9174a68f512D10A791664e1,
            1500000,
            8 * month
        ); /* After 8 Months */

        /* Private Sale */
        setInitialDistribution(
            0x24A8C45048cB7CF51fC74143fFdBd4CFF3638AC7,
            6875000,
            0 /* No Lock */
        );
        //setInitialDistribution(0x24A8C45048cB7CF51fC74143fFdBd4CFF3638AC7, 6875000, 1 * month); /* After 1 Month */
        //setInitialDistribution(0x24A8C45048cB7CF51fC74143fFdBd4CFF3638AC7, 6875000, 2 * month); /* After 2 Months */
        //setInitialDistribution(0x24A8C45048cB7CF51fC74143fFdBd4CFF3638AC7, 6875000, 3 * month); /* After 3 Months */

        /* Team & Advisors */
        //setInitialDistribution(0x5d1c9B0B0807573B8976733dF3BaAf0102E1b3F8, 2500000, year);
        //setInitialDistribution(0x5d1c9B0B0807573B8976733dF3BaAf0102E1b3F8, 2500000, year.add(3 * month)); /* After 3 Month */
        //setInitialDistribution(0x5d1c9B0B0807573B8976733dF3BaAf0102E1b3F8, 2500000, year.add(6 * month)); /* After 6 Month */
        //setInitialDistribution(0x5d1c9B0B0807573B8976733dF3BaAf0102E1b3F8, 2500000, year.add(9 * month)); /* After 9 Month */

        /* Network Growth Growth */
        //setInitialDistribution(0x36Dc5e71304a3826C54EF6F8a19C2c4160e8ce9c, 3000000, 0 /* No Lock */);
        //setInitialDistribution(0x36Dc5e71304a3826C54EF6F8a19C2c4160e8ce9c, 1000000, 1 * month); /* After 1 Month */
        //setInitialDistribution(0x36Dc5e71304a3826C54EF6F8a19C2c4160e8ce9c, 1000000, 2 * month); /* After 2 Months */

        /* Liquidity Fund */
        //setInitialDistribution(0xDD2AA97FB05aE47d1227FaAc488Ad8678e8Ea4F2, 5000000, 0 /* No Lock */);
        //setInitialDistribution(0xDD2AA97FB05aE47d1227FaAc488Ad8678e8Ea4F2, 2000000, 1 * month); /* After 1 Month */
        //setInitialDistribution(0xDD2AA97FB05aE47d1227FaAc488Ad8678e8Ea4F2, 2000000, 2 * month); /* After 2 Months */

        /* Foundational Reserve Fund */
        //setInitialDistribution(0x20373581F525d1b85f9F9B5e7594eD5EE9a8Bc21, 2500000, year);
        //setInitialDistribution(0x20373581F525d1b85f9F9B5e7594eD5EE9a8Bc21, 2500000, year.add(3 * month)); /* After 3 Month */
        //setInitialDistribution(0x20373581F525d1b85f9F9B5e7594eD5EE9a8Bc21, 2500000, year.add(6 * month)); /* After 6 Month */
        //setInitialDistribution(0x20373581F525d1b85f9F9B5e7594eD5EE9a8Bc21, 2500000, year.add(9 * month)); /* After 9 Month */
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

    function setTGEDate(uint256 _time) external onlyOwner whenNotPaused {
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
                if (
                    (block.timestamp.sub(TGEDate) > d[j].unlockDay) && /* Verify if unlockDay has passed */
                    (d[j].currentAllocated > 0) /* Verify if currentAllocated > 0, so that address has tokens to be sent still */
                ) {
                    uint256 sendingAmount;
                    sendingAmount = d[j].currentAllocated;
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CrodoPrivateSale is Ownable, Pausable {
    using SafeMath for uint256;

    event ParticipantAdded(address participant);
    event ParticipantRemoved(address participant);

    ERC20 public crodoToken;
    ERC20 public usdtToken;
    // address public USDTAddress = address(0x66e428c3f67a68878562e79A0234c1F83c208770);

    struct Participant {
        uint256 minBuyAllowed;
        uint256 maxBuyAllowed;
        uint256 reserved;
        uint256 sent;
    }

    uint256 public totalMaxBuyAllowed;
    uint256 public totalMinBuyAllowed;
    uint256 public totalBought;
    uint256 public USDTPerToken;
    uint48 public initReleaseDate;
    uint256 public latestRelease; // Time of the latest release
    uint48 public releaseInterval = 30 days;
    uint8 public totalReleases = 10;
    uint8 public currentRelease;

    mapping(address => Participant) public participants;
    address[] participantAddrs;

    constructor(
        address _crodoToken,
        address _usdtAddress,
        uint256 _USDTPerToken,
        uint48 _initReleaseDate
    ) Ownable() {
        crodoToken = ERC20(_crodoToken);
        usdtToken = ERC20(_usdtAddress);
        USDTPerToken = _USDTPerToken;
        initReleaseDate = _initReleaseDate;
    }

    function close() public whenNotPaused onlyOwner {
        _pause();
    }

    function reservedBy(address participant) public view returns (uint256) {
        return participants[participant].reserved;
    }

    function setReleaseInterval(uint48 _interval) external onlyOwner whenNotPaused {
        releaseInterval = _interval;
    }

    function contractBalance() internal view returns (uint256) {
        return crodoToken.balanceOf(address(this));
    }

    function getParticipant(address _participant)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        Participant memory participant = participants[_participant];
        return (
            participant.minBuyAllowed,
            participant.maxBuyAllowed,
            participant.reserved,
            participant.sent
        );
    }

    function addParticipant(
        address _participant,
        uint256 minBuyAllowed,
        uint256 maxBuyAllowed
    ) external onlyOwner whenNotPaused {
        Participant storage participant = participants[_participant];
        participant.minBuyAllowed = minBuyAllowed;
        participant.maxBuyAllowed = maxBuyAllowed;
        totalMinBuyAllowed += minBuyAllowed;
        totalMaxBuyAllowed += maxBuyAllowed;

        participantAddrs.push(_participant);
        emit ParticipantAdded(_participant);
    }

    function removeParticipant(address _participant) external onlyOwner whenNotPaused {
        Participant memory participant = participants[_participant];
        totalMaxBuyAllowed -= participant.maxBuyAllowed;
        totalMinBuyAllowed -= participant.minBuyAllowed;

        delete participants[_participant];
        emit ParticipantRemoved(_participant);
    }

    function calculateUSDTPrice(uint256 amount)
        internal
        view
        returns (uint256)
    {
        return amount * USDTPerToken;
    }

    // Main function to purchase tokens during Private Sale. Buyer pays in fixed
    // rate of USDT for requested amount of CROD tokens. The USDT tokens must be
    // delegated for use to this contract beforehand by the user (call to ERC20.approve)
    //
    // @IMPORTANT: `amount` is expected to be in non-decimal form,
    // so 'boughtTokens = amount * (10 ^ crodoToken.decimals())'
    //
    // We need to cover some cases here:
    // 1) Our contract doesn't have requested amount of tokens left
    // 2) User tries to exceed their buy limit
    // 3) User tries to purchase tokens below their min limit
    function lockTokens(uint256 amount) external whenNotPaused returns (uint256) {
        // Cover case 1
        require(
            (totalBought + amount * (10**crodoToken.decimals())) <
                contractBalance(),
            "Contract doesn't have requested amount of tokens left"
        );

        Participant storage participant = participants[msg.sender];

        // Cover case 2
        require(
            participant.reserved + amount < participant.maxBuyAllowed,
            "User tried to exceed their buy-high limit"
        );

        // Cover case 3
        require(
            participant.reserved + amount > participant.minBuyAllowed,
            "User tried to purchase tokens below their minimum limit"
        );

        uint256 usdtPrice = calculateUSDTPrice(amount);
        require(
            usdtToken.balanceOf(msg.sender) >= usdtPrice,
            "User doesn't have enough USDT to buy requested tokens"
        );

        require(
            usdtToken.allowance(msg.sender, address(this)) >= usdtPrice,
            "User hasn't delegated required amount of tokens for the operation"
        );

        usdtToken.transferFrom(msg.sender, address(this), usdtPrice);
        participant.reserved += amount * (10**crodoToken.decimals());
        totalBought += amount * (10**crodoToken.decimals());
        return amount;
    }

    // Releases locked tokens to buyers, after which resets all contract state to zero
    function releaseTokens() external onlyOwner whenPaused returns (uint256) {
        require(
            initReleaseDate <= block.timestamp,
            "Initial release date hasn't passed yet"
           );
        require(
            latestRelease + releaseInterval <= block.timestamp,
            string(abi.encodePacked(
                "Can only release tokens after interval has passed since last release, last release time: ",
                Strings.toString(latestRelease)
            ))
        );

        ++currentRelease;
        latestRelease = block.timestamp;
        uint256 tokensSent = 0;
        for (uint32 i = 0; i < participantAddrs.length; ++i) {
            address participantAddr = participantAddrs[i];
            Participant storage participant = participants[participantAddr];
            if (participant.reserved > 0) {
                uint256 roundAmount = participant.reserved / totalReleases;

                // If on the last release tokens don't round up after dividing,
                // just send the whole remaining tokens
                if (currentRelease >= totalReleases &&
                    roundAmount < (participant.reserved - participant.sent)
                ) {
                    roundAmount = participant.reserved - participant.sent;
                }

                require(
                    roundAmount <= contractBalance(),
                    "Internal Error: Contract doens't have enough tokens to transfer to buyer"
                );

                crodoToken.transfer(
                    participantAddr,
                    roundAmount
                );
                participant.sent += roundAmount;
                tokensSent += roundAmount;
            }
        }
        return tokensSent;
    }
}

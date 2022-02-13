// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrodoPrivateSale is Ownable {
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
    }

    uint256 public totalMaxBuyAllowed;
    uint256 public totalMinBuyAllowed;
    uint256 public totalBought;
    uint256 public USDTPerToken;

    mapping(address => Participant) public participants;
    address[] participantAddrs;

    constructor(address _crodoToken, address _usdtAddress, uint256 _USDTPerToken)
        Ownable()
    {
        crodoToken = ERC20(_crodoToken);
        usdtToken = ERC20(_usdtAddress);
        USDTPerToken = _USDTPerToken;
    }

    function reservedBy(address participant) public view returns (uint256) {
        return participants[participant].reserved;
    }

    function contractBalance() internal view returns (uint256) {
        return crodoToken.balanceOf(address(this));
    }

    function addParticipant(
        address _participant,
        uint256 minBuyAllowed,
        uint256 maxBuyAllowed
    ) external onlyOwner {
        Participant storage participant = participants[_participant];
        participant.minBuyAllowed = minBuyAllowed;
        participant.maxBuyAllowed = maxBuyAllowed;
        totalMinBuyAllowed += minBuyAllowed;
        totalMaxBuyAllowed += maxBuyAllowed;

        participantAddrs.push(_participant);
        emit ParticipantAdded(_participant);
    }

    function removeParticipant(
        address _participant
    ) external onlyOwner {
        Participant memory participant = participants[_participant];
        totalMaxBuyAllowed -= participant.maxBuyAllowed;
        totalMinBuyAllowed -= participant.minBuyAllowed;

        delete participants[_participant];
        emit ParticipantRemoved(_participant);
    }

    function calculateUSDTPrice(uint256 amount) internal view returns (uint256) {
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
    function lockTokens(uint256 amount) external returns (uint256) {
        // Cover case 1
        require(
            (totalBought + amount * (10 ** crodoToken.decimals())) < contractBalance(),
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
        participant.reserved += amount * (10 ** crodoToken.decimals());
        totalBought += amount * (10 ** crodoToken.decimals());
        return amount;
    }

    // Releases locked tokens to buyers, after which resets all contract state to zero
    function releaseTokens() external onlyOwner returns (uint256) {
        for (uint32 i = 0; i < participantAddrs.length; ++i) {
            address participantAddr = participantAddrs[i];
            Participant storage participant = participants[participantAddr];
            if (participant.reserved > 0) {
                // This check is pretty much unnecessary, tokens wouldn't be reserved if they exceed contract balance at
                // the point of reservation anyway, so if this require fails, then it must be caused by internal error.
                require(
                    participant.reserved < contractBalance(),
                    "Contract doens't have enough tokens to transfer to buyer"
                );
                crodoToken.transfer(participantAddr, participant.reserved);
                participant.reserved = 0;
            }
        }
        uint256 tokensSent = totalBought;
        totalBought = 0;
        return tokensSent;
    }
}

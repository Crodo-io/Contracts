// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Whitelist is Ownable {
    mapping(address => bool) public whitelist;
    address[] public whitelistedAddresses;
    bool public hasWhitelisting = false;

    event AddedToWhitelist(address[] indexed accounts);
    event RemovedFromWhitelist(address indexed account);

    modifier onlyWhitelisted() {
        if (hasWhitelisting) {
            require(isWhitelisted(msg.sender));
        }
        _;
    }

    constructor(bool _hasWhitelisting) {
        hasWhitelisting = _hasWhitelisting;
    }

    function add(address[] memory _addresses) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(whitelist[_addresses[i]] != true);
            whitelist[_addresses[i]] = true;
            whitelistedAddresses.push(_addresses[i]);
        }
        emit AddedToWhitelist(_addresses);
    }

    function remove(address _address, uint256 _index) public onlyOwner {
        require(_address == whitelistedAddresses[_index]);
        whitelist[_address] = false;
        delete whitelistedAddresses[_index];
        emit RemovedFromWhitelist(_address);
    }

    function getWhitelistedAddresses() public view returns (address[] memory) {
        return whitelistedAddresses;
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }
}

contract FixedSwap is Pausable, Whitelist {
    using SafeMath for uint256;
    uint256 increment = 0;

    mapping(uint256 => Purchase) public purchases; /* Purchasers mapping */
    address[] public buyers; /* Current Buyers Addresses */
    uint256[] public purchaseIds; /* All purchaseIds */
    mapping(address => uint256[]) public myPurchases; /* Purchasers mapping */

    ERC20 public bidToken;
    ERC20 public askToken;
    bool public isSaleFunded = false;
    uint256 public decimals;
    bool public unsoldTokensReedemed = false;
    uint256 public tradeValue; /* Price in askToken for single base unit of bidToken */
    uint256 public startDate; /* Start Date  */
    uint256 public endDate; /* End Date  */
    uint256 public individualMinimumAmount; /* Minimum Amount Per Address */
    uint256 public individualMaximumAmount; /* Maximum Amount Per Address */
    uint256 public minimumRaise; /* Minimum Amount of Tokens that have to be sold */
    uint256 public tokensAllocated; /* Tokens Available for Allocation - Dynamic */
    uint256 public tokensForSale; /* Tokens Available for Sale */
    bool public isTokenSwapAtomic; /* Make token release atomic or not */
    address public FEE_ADDRESS; /* Default Address for Fee Percentage */
    uint8 public feePercentage; /* Measured in single decimal points (i.e. 5 = 5%) */

    struct Purchase {
        uint256 amount;
        address purchaser;
        uint256 ethAmount;
        uint256 timestamp;
        bool wasFinalized; /* Confirm the tokens were sent already */
        bool reverted; /* Confirm the tokens were sent already */
    }

    event PurchaseEvent(
        uint256 amount,
        address indexed purchaser,
        uint256 timestamp
    );

    constructor(
        address _askTokenAddress,
        address _bidTokenAddress,
        uint256 _tradeValue,
        uint256 _tokensForSale,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _individualMinimumAmount,
        uint256 _individualMaximumAmount,
        bool _isTokenSwapAtomic,
        uint256 _minimumRaise,
        address _feeAddress,
        bool _hasWhitelisting
    ) Whitelist(_hasWhitelisting) {
        /* Confirmations */
        require(
            block.timestamp < _endDate,
            "End Date should be further than current date"
        );
        require(
            block.timestamp < _startDate,
            "End Date should be further than current date"
        );
        require(_startDate < _endDate, "End Date higher than Start Date");
        require(_tokensForSale > 0, "Tokens for Sale should be > 0");
        require(
            _tokensForSale > _individualMinimumAmount,
            "Tokens for Sale should be > Individual Minimum Amount"
        );
        require(
            _individualMaximumAmount >= _individualMinimumAmount,
            "Individual Maximim AMount should be > Individual Minimum Amount"
        );
        require(
            _minimumRaise <= _tokensForSale,
            "Minimum Raise should be < Tokens For Sale"
        );

        askToken = ERC20(_askTokenAddress);
        bidToken = ERC20(_bidTokenAddress);
        tradeValue = _tradeValue;
        tokensForSale = _tokensForSale;
        startDate = _startDate;
        endDate = _endDate;
        individualMinimumAmount = _individualMinimumAmount;
        individualMaximumAmount = _individualMaximumAmount;
        isTokenSwapAtomic = _isTokenSwapAtomic;

        if (!_isTokenSwapAtomic) {
            /* If raise is not atomic swap */
            minimumRaise = _minimumRaise;
        }

        FEE_ADDRESS = _feeAddress;
        decimals = bidToken.decimals();
    }

    /**
     * Modifier to make a function callable only when the contract has Atomic Swaps not available.
     */
    modifier isNotAtomicSwap() {
        require(!isTokenSwapAtomic, "Has to be non Atomic swap");
        _;
    }

    /**
     * Modifier to make a function callable only when the contract has Atomic Swaps not available.
     */
    modifier isSaleFinalized() {
        require(hasFinalized(), "Has to be finalized");
        _;
    }

    /**
     * Modifier to make a function callable only when the swap time is open.
     */
    modifier isSaleOpen() {
        require(isOpen(), "Has to be open");
        _;
    }

    /**
     * Modifier to make a function callable only when the contract has Atomic Swaps not available.
     */
    modifier isSalePreStarted() {
        require(isPreStart(), "Has to be pre-started");
        _;
    }

    /**
     * Modifier to make a function callable only when the contract has Atomic Swaps not available.
     */
    modifier isFunded() {
        require(isSaleFunded, "Has to be funded");
        _;
    }

    /* Get Functions */
    function isBuyer(uint256 purchase_id) public view returns (bool) {
        return (msg.sender == purchases[purchase_id].purchaser);
    }

    /* Get Functions */
    function totalRaiseCost() public view returns (uint256) {
        return (cost(tokensForSale));
    }

    function availableTokens() public view returns (uint256) {
        return bidToken.balanceOf(address(this));
    }

    function tokensLeft() public view returns (uint256) {
        return tokensForSale - tokensAllocated;
    }

    function hasMinimumRaise() public view returns (bool) {
        return (minimumRaise != 0);
    }

    /* Verify if minimum raise was not achieved */
    function minimumRaiseNotAchieved() public view returns (bool) {
        require(
            cost(tokensAllocated) < cost(minimumRaise),
            "TotalRaise is bigger than minimum raise amount"
        );
        return true;
    }

    /* Verify if minimum raise was achieved */
    function minimumRaiseAchieved() public view returns (bool) {
        if (hasMinimumRaise()) {
            require(
                cost(tokensAllocated) >= cost(minimumRaise),
                "TotalRaise is less than minimum raise amount"
            );
        }
        return true;
    }

    function hasFinalized() public view returns (bool) {
        return block.timestamp > endDate;
    }

    function hasStarted() public view returns (bool) {
        return block.timestamp >= startDate;
    }

    function isPreStart() public view returns (bool) {
        return block.timestamp < startDate;
    }

    function isOpen() public view returns (bool) {
        return hasStarted() && !hasFinalized();
    }

    function hasMinimumAmount() public view returns (bool) {
        return (individualMinimumAmount != 0);
    }

    function cost(uint256 _amount) public view returns (uint256) {
        return _amount.mul(tradeValue).div(10**decimals);
    }

    function boughtByAddress(address _buyer) public view returns (uint256) {
        uint256[] memory _purchases = getMyPurchases(_buyer);
        uint256 purchaserTotalAmountPurchased = 0;
        for (uint256 i = 0; i < _purchases.length; i++) {
            Purchase memory _purchase = purchases[_purchases[i]];
            purchaserTotalAmountPurchased = purchaserTotalAmountPurchased.add(
                _purchase.amount
            );
        }
        return purchaserTotalAmountPurchased;
    }

    function getPurchase(uint256 _purchase_id)
        external
        view
        returns (
            uint256,
            address,
            uint256,
            uint256,
            bool,
            bool
        )
    {
        Purchase memory purchase = purchases[_purchase_id];
        return (
            purchase.amount,
            purchase.purchaser,
            purchase.ethAmount,
            purchase.timestamp,
            purchase.wasFinalized,
            purchase.reverted
        );
    }

    function getPurchaseIds() public view returns (uint256[] memory) {
        return purchaseIds;
    }

    function getBuyers() public view returns (address[] memory) {
        return buyers;
    }

    function getMyPurchases(address _address)
        public
        view
        returns (uint256[] memory)
    {
        return myPurchases[_address];
    }

    function setFeePercentage(uint8 _feePercentage) public onlyOwner {
        require(feePercentage == 0, "Fee Percentage can not be modyfied once set");
        require(_feePercentage <= 99, "Fee Percentage has to be < 100");
        feePercentage = _feePercentage;
    }

    /* Fund - Pre Sale Start */
    function fund(uint256 _amount) public isSalePreStarted {
        /* Confirm transfered tokens is no more than needed */
        require(
            availableTokens().add(_amount) <= tokensForSale,
            "Transfered tokens have to be equal or less than proposed"
        );

        /* Transfer Funds */
        require(
            bidToken.transferFrom(msg.sender, address(this), _amount),
            "Failed ERC20 token transfer"
        );

        /* If Amount is equal to needed - sale is ready */
        if (availableTokens() == tokensForSale) {
            isSaleFunded = true;
        }
    }

    /* Action Functions */
    function swap(uint256 _amount)
        external
        payable
        whenNotPaused
        isFunded
        isSaleOpen
        onlyWhitelisted
    {
        /* Confirm Amount is positive */
        require(_amount > 0, "Amount has to be positive");

        /* Confirm Amount is less than tokens available */
        require(
            _amount <= tokensLeft(),
            "Amount is less than tokens available"
        );

        uint256 purchaseCost = cost(_amount);

        /* Confirm the user has funds for the transfer, confirm the value is equal */
        require(
            askToken.balanceOf(msg.sender) >= purchaseCost,
            "User doesn't have enough askToken for purchase"
        );

        /* Confirm Amount is bigger than minimum Amount */
        require(
            _amount >= individualMinimumAmount,
            "Amount is bigger than minimum amount"
        );

        /* Confirm Amount is smaller than maximum Amount */
        require(
            _amount <= individualMaximumAmount,
            "Amount is smaller than maximum amount"
        );

        /* Verify all user purchases, loop thru them */
        uint256 purchaserTotalAmountPurchased = boughtByAddress(msg.sender);
        require(
            purchaserTotalAmountPurchased.add(_amount) <=
                individualMaximumAmount,
            "Address has already passed the max amount of swap"
        );

        if (isTokenSwapAtomic) {
            /* Confirm transfer */
            require(
                bidToken.transfer(msg.sender, _amount),
                "ERC20 transfer didn't work"
            );
        }

        uint256 purchase_id = increment;
        increment = increment.add(1);

        askToken.transferFrom(msg.sender, address(this), purchaseCost);
        /* Create new purchase */
        Purchase memory purchase = Purchase(
            _amount,
            msg.sender,
            purchaseCost,
            block.timestamp,
            isTokenSwapAtomic, /* If Atomic Swap */
            false
        );
        purchases[purchase_id] = purchase;
        purchaseIds.push(purchase_id);
        myPurchases[msg.sender].push(purchase_id);
        buyers.push(msg.sender);
        tokensAllocated = tokensAllocated.add(_amount);
        emit PurchaseEvent(_amount, msg.sender, block.timestamp);
    }

    /* Redeem tokens when the sale was finalized */
    function redeemTokens(uint256 purchase_id)
        external
        isNotAtomicSwap
        isSaleFinalized
        whenNotPaused
    {
        /* Confirm it exists and was not finalized */
        require(
            (purchases[purchase_id].amount != 0) &&
                !purchases[purchase_id].wasFinalized,
            "Purchase is either 0 or finalized"
        );
        require(isBuyer(purchase_id), "Address is not buyer");
        purchases[purchase_id].wasFinalized = true;
        require(
            bidToken.transfer(msg.sender, purchases[purchase_id].amount),
            "ERC20 transfer failed"
        );
    }

    /* Retrieve Minumum Amount */
    function redeemGivenMinimumGoalNotAchieved(uint256 purchase_id)
        external
        isSaleFinalized
        isNotAtomicSwap
    {
        require(hasMinimumRaise(), "Minimum raise has to exist");
        require(minimumRaiseNotAchieved(), "Minimum raise has to be reached");
        /* Confirm it exists and was not finalized */
        require(
            (purchases[purchase_id].amount != 0) &&
                !purchases[purchase_id].wasFinalized,
            "Purchase is either 0 or finalized"
        );
        require(isBuyer(purchase_id), "Address is not buyer");
        purchases[purchase_id].wasFinalized = true;
        purchases[purchase_id].reverted = true;
        askToken.transfer(msg.sender, purchases[purchase_id].ethAmount);
    }

    /* Admin Functions */
    function withdrawFunds(address tokensReceiver) external onlyOwner whenNotPaused isSaleFinalized {
        require(minimumRaiseAchieved(), "Minimum raise has to be reached");
        uint256 contractBalance = askToken.balanceOf(address(this));
        uint256 feeAmount = contractBalance.mul(feePercentage).div(100);
        askToken.transfer(FEE_ADDRESS, feeAmount);
        askToken.transfer(tokensReceiver, contractBalance - feeAmount);
    }

    function withdrawUnsoldTokens() external onlyOwner isSaleFinalized {
        require(!unsoldTokensReedemed);
        uint256 unsoldTokens;
        if (hasMinimumRaise() && (cost(tokensAllocated) < cost(minimumRaise))) {
            /* Minimum Raise not reached */
            unsoldTokens = tokensForSale;
        } else {
            /* If minimum Raise Achieved Redeem All Tokens minus the ones */
            unsoldTokens = tokensForSale.sub(tokensAllocated);
        }

        if (unsoldTokens > 0) {
            unsoldTokensReedemed = true;
            require(
                bidToken.transfer(msg.sender, unsoldTokens),
                "ERC20 transfer failed"
            );
        }
    }

    function removeOtherERC20Tokens(address _tokenAddress, address _to)
        external
        onlyOwner
        isSaleFinalized
    {
        require(
            _tokenAddress != address(bidToken),
            "Token Address has to be diff than the bidToken subject to sale"
        ); // Confirm tokens addresses are different from main sale one
        ERC20 erc20Token = ERC20(_tokenAddress);
        require(
            erc20Token.transfer(_to, erc20Token.balanceOf(address(this))),
            "ERC20 Token transfer failed"
        );
    }

    /* Safe Pull function */
    function safePull() external onlyOwner whenPaused {
        address payable seller = payable(msg.sender);
        seller.transfer(address(this).balance);
        bidToken.transfer(msg.sender, bidToken.balanceOf(address(this)));
        askToken.transfer(msg.sender, askToken.balanceOf(address(this)));
    }
}

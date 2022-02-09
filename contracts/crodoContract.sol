// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CRDStake is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    event Stake(address indexed wallet, uint256 amount, uint256 date);
    event Withdraw(address indexed wallet, uint256 amount, uint256 date);
    event Claimed(
        address indexed wallet,
        address indexed rewardToken,
        uint256 amount
    );

    event RewardTokenChanged(
        address indexed oldRewardToken,
        uint256 returnedAmount,
        address indexed newRewardToken
    );
    event LockTimePeriodMinChanged(uint48 lockTimePeriodMin);
    event LockTimePeriodMaxChanged(uint48 lockTimePeriodMax);
    event StakeRewardFactorChanged(uint256 stakeRewardFactor);
    event StakeRewardEndTimeChanged(uint48 stakeRewardEndTime);
    event RewardsBurned(address indexed staker, uint256 amount);
    event ERC20TokensRemoved(
        address indexed tokenAddress,
        address indexed receiver,
        uint256 amount
    );

    uint48 public constant MAX_TIME = type(uint48).max; // = 2^48 - 1

    struct User {
        uint48 stakeTime;
        uint48 unlockTime;
        uint48 lockTime;
        // Used to calculate how long the tokens are being staked,
        // the difference between `stakeTime` is that `stakedSince` only updates
        // when user withdraws tokens from the stake pull.
        uint48 stakedSince;
        uint160 stakeAmount;
        uint256 accumulatedRewards;
    }

    mapping(address => User) public userMap;

    uint256 public tokenTotalStaked; // sum of all staked tokens

    address public immutable stakingToken; // address of token which can be staked into this contract
    address public rewardToken; // address of reward token

    /**
     * Using block.timestamp instead of block.number for reward calculation
     * 1) Easier to handle for users
     * 2) Should result in same rewards across different chain with different block times
     * 3) "The current block timestamp must be strictly larger than the timestamp of the last block, ...
     *     but the only guarantee is that it will be somewhere between the timestamps ...
     *     of two consecutive blocks in the canonical chain."
     *    https://docs.soliditylang.org/en/v0.7.6/cheatsheet.html?highlight=block.timestamp#global-variables
     */

    // time in seconds a user has to wait after calling unlock until staked token can be withdrawn
    uint48 public lockTimePeriodMin;
    uint48 public lockTimePeriodMax;
    uint48 public stakeRewardEndTime; // unix time in seconds when the reward scheme will end
    uint256 public stakeRewardFactor; // time in seconds * amount of staked token to receive 1 reward token

    constructor(
        address _stakingToken,
        uint48 _lockTimePeriodMin,
        uint48 _lockTimePeriodMax
    ) {
        require(_stakingToken != address(0), "stakingToken.address == 0");
        stakingToken = _stakingToken;
        lockTimePeriodMin = _lockTimePeriodMin;
        lockTimePeriodMax = _lockTimePeriodMax;
        // set some defaults
        stakeRewardFactor = 1000 * 1 days; // a user has to stake 1000 token for 1 day to receive 1 reward token
        stakeRewardEndTime = uint48(block.timestamp + 366 days); // reward scheme ends in 1 year
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * based on OpenZeppelin SafeCast v4.3
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.3/contracts/utils/math/SafeCast.sol
     */

    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "value doesn't fit in 48 bits");
        return uint48(value);
    }

    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "value doesn't fit in 160 bits");
        return uint160(value);
    }

    /**
     * External API functions
     */

    function stakeTime(address _staker)
        external
        view
        returns (uint48 dateTime)
    {
        return userMap[_staker].stakeTime;
    }

    function stakedSince(address _staker)
        external
        view
        returns (uint48 dateTime)
    {
        return userMap[_staker].stakedSince;
    }

    function stakeAmount(address _staker)
        external
        view
        returns (uint256 balance)
    {
        return userMap[_staker].stakeAmount;
    }

    function getLockTime(address _staker)
        external
        view
        returns (uint48 lockTime)
    {
        return userMap[_staker].lockTime;
    }

    // redundant with stakeAmount() for compatibility
    function balanceOf(address _staker)
        external
        view
        returns (uint256 balance)
    {
        return userMap[_staker].stakeAmount;
    }

    function userAccumulatedRewards(address _staker)
        external
        view
        returns (uint256 rewards)
    {
        return userMap[_staker].accumulatedRewards;
    }

    /**
     * @dev return unix epoch time when staked tokens will be unlocked
     * @dev return MAX_INT_UINT48 = 2**48-1 if user has no token staked
     * @dev this always allows an easy check with : require(block.timestamp > getUnlockTime(account));
     * @return unlockTime unix epoch time in seconds
     */
    function getUnlockTime(address _staker)
        public
        view
        returns (uint48 unlockTime)
    {
        return
            userMap[_staker].stakeAmount > 0
                ? userMap[_staker].unlockTime
                : MAX_TIME;
    }

    /**
     * @return balance of reward tokens held by this contract
     */
    function getRewardTokenBalance() public view returns (uint256 balance) {
        if (rewardToken == address(0)) return 0;
        balance = IERC20(rewardToken).balanceOf(address(this));
        if (stakingToken == rewardToken) {
            balance -= tokenTotalStaked;
        }
    }

    // onlyOwner / DEFAULT_ADMIN_ROLE functions --------------------------------------------------

    /**
     * @notice setting rewardToken to address(0) disables claim/mint
     * @notice if there was a reward token set before, return remaining tokens to msg.sender/admin
     * @param newRewardToken address
     */
    function setRewardToken(address newRewardToken)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        address oldRewardToken = rewardToken;
        uint256 rewardBalance = getRewardTokenBalance(); // balance of oldRewardToken
        if (rewardBalance > 0) {
            IERC20(oldRewardToken).safeTransfer(msg.sender, rewardBalance);
        }
        rewardToken = newRewardToken;
        emit RewardTokenChanged(oldRewardToken, rewardBalance, newRewardToken);
    }

    /**
     * @notice set min time a user has to wait after calling unlock until staked token can be withdrawn
     * @param _lockTimePeriodMin time in seconds
     */
    function setLockTimePeriodMin(uint48 _lockTimePeriodMin)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        lockTimePeriodMin = _lockTimePeriodMin;
        emit LockTimePeriodMinChanged(_lockTimePeriodMin);
    }

    /**
     * @notice set max time a user has to wait after calling unlock until staked token can be withdrawn
     * @param _lockTimePeriodMax time in seconds
     */
    function setLockTimePeriodMax(uint48 _lockTimePeriodMax)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        lockTimePeriodMax = _lockTimePeriodMax;
        emit LockTimePeriodMaxChanged(_lockTimePeriodMax);
    }

    /**
     * @notice see calculateUserClaimableReward() docs
     * @dev requires that reward token has the same decimals as stake token
     * @param _stakeRewardFactor time in seconds * amount of staked token to receive 1 reward token
     */
    function setStakeRewardFactor(uint256 _stakeRewardFactor)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        stakeRewardFactor = _stakeRewardFactor;
        emit StakeRewardFactorChanged(_stakeRewardFactor);
    }

    /**
     * @notice set block time when stake reward scheme will end
     * @param _stakeRewardEndTime unix time in seconds
     */
    function setStakeRewardEndTime(uint48 _stakeRewardEndTime)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            stakeRewardEndTime > block.timestamp,
            "time has to be in the future"
        );
        stakeRewardEndTime = _stakeRewardEndTime;
        emit StakeRewardEndTimeChanged(_stakeRewardEndTime);
    }

    /**
     * ADMIN_ROLE has to set BURNER_ROLE
     * allows an external (lottery token sale) contract to substract rewards
     */
    function burnRewards(address _staker, uint256 _amount)
        external
        onlyRole(BURNER_ROLE)
    {
        User storage user = _updateRewards(_staker);

        if (_amount < user.accumulatedRewards) {
            user.accumulatedRewards -= _amount; // safe
        } else {
            user.accumulatedRewards = 0; // burn at least all what's there
        }
        emit RewardsBurned(_staker, _amount);
    }

    /** msg.sender external view convenience functions *********************************/

    function stakeAmount_msgSender() public view returns (uint256) {
        return userMap[msg.sender].stakeAmount;
    }

    function stakeLockTime_msgSender() external view returns (uint48) {
        return userMap[msg.sender].lockTime;
    }

    function stakeTime_msgSender() external view returns (uint48) {
        return userMap[msg.sender].stakeTime;
    }

    function getUnlockTime_msgSender()
        external
        view
        returns (uint48 unlockTime)
    {
        return getUnlockTime(msg.sender);
    }

    function userClaimableRewards_msgSender() external view returns (uint256) {
        return userClaimableRewards(msg.sender);
    }

    function userAccumulatedRewards_msgSender()
        external
        view
        returns (uint256)
    {
        return userMap[msg.sender].accumulatedRewards;
    }

    function userTotalRewards_msgSender() external view returns (uint256) {
        return userTotalRewards(msg.sender);
    }

    function getEarnedRewardTokens_msgSender() external view returns (uint256) {
        return getEarnedRewardTokens(msg.sender);
    }

    /** public external view functions (also used internally) **************************/

    /**
     * calculates unclaimed rewards
     * unclaimed rewards = expired time since last stake/unstake transaction * current staked amount
     *
     * We have to cover 6 cases here :
     * 1) block time < stake time < end time   : should never happen => error
     * 2) block time < end time   < stake time : should never happen => error
     * 3) end time   < block time < stake time : should never happen => error
     * 4) end time   < stake time < block time : staked after reward period is over => no rewards
     * 5) stake time < block time < end time   : end time in the future
     * 6) stake time < end time   < block time : end time in the past & staked before
     * @param _staker address
     * @return claimableRewards = timePeriod * stakeAmount
     */
    function userClaimableRewards(address _staker)
        public
        view
        returns (uint256)
    {
        User storage user = userMap[_staker];
        // case 1) 2) 3)
        // stake time in the future - should never happen - actually an (internal ?) error
        if (block.timestamp <= user.stakeTime) return 0;

        // case 4)
        // staked after reward period is over => no rewards
        // end time < stake time < block time
        if (stakeRewardEndTime <= user.stakeTime) return 0;

        uint256 timePeriod;

        // case 5
        // we have not reached the end of the reward period
        // stake time < block time < end time
        if (block.timestamp <= stakeRewardEndTime) {
            timePeriod = block.timestamp - user.stakeTime; // covered by case 1) 2) 3) 'if'
        } else {
            // case 6
            // user staked before end of reward period , but that is in the past now
            // stake time < end time < block time
            timePeriod = stakeRewardEndTime - user.stakeTime; // covered case 4)
        }

        return timePeriod * user.stakeAmount;
    }

    function userTotalRewards(address _staker) public view returns (uint256) {
        return
            userClaimableRewards(_staker) + userMap[_staker].accumulatedRewards;
    }

    function getEarnedRewardTokens(address _staker)
        public
        view
        returns (uint256 claimableRewardTokens)
    {
        if (address(rewardToken) == address(0) || stakeRewardFactor == 0) {
            return 0;
        } else {
            return userTotalRewards(_staker) / stakeRewardFactor; // safe
        }
    }

    /**
     *  @dev whenver the staked balance changes do ...
     *
     *  @dev calculate userClaimableRewards = previous staked amount * (current time - last stake time)
     *  @dev add userClaimableRewards to userAccumulatedRewards
     *  @dev reset userClaimableRewards to 0 by setting stakeTime to current time
     *  @dev not used as doing it inline, local, within a function consumes less gas
     *
     *  @return user reference pointer for further processing
     */
    function _updateRewards(address _staker)
        internal
        returns (User storage user)
    {
        // calculate reward credits using previous staking amount and previous time period
        // add new reward credits to already accumulated reward credits
        user = userMap[_staker];
        user.accumulatedRewards += userClaimableRewards(_staker);

        // update stake Time to current time (start new reward period)
        // will also reset userClaimableRewards()
        user.stakeTime = toUint48(block.timestamp);

        if (user.stakedSince == 0) {
            user.stakedSince = toUint48(block.timestamp);
        }
    }

    /**
     * add stake token to staking pool
     * @dev requires the token to be approved for transfer
     * @dev we assume that (our) stake token is not malicious, so no special checks
     * @param _amount of token to be staked
     * @param _lockTime period for staking
     */
    function _stake(uint256 _amount, uint48 _lockTime)
        internal
        returns (uint256)
    {
        require(_amount > 0, "stake amount must be > 0");
        require(
            _lockTime <= lockTimePeriodMax,
            "lockTime must by < lockTimePeriodMax"
        );
        require(
            _lockTime >= lockTimePeriodMin,
            "lockTime must by > lockTimePeriodMin"
        );

        User storage user = _updateRewards(msg.sender); // update rewards and return reference to user

        require(
            block.timestamp + _lockTime >= user.unlockTime,
            "locktime must be >= current lock time"
        );

        user.stakeAmount = toUint160(user.stakeAmount + _amount);
        tokenTotalStaked += _amount;

        user.unlockTime = toUint48(block.timestamp + _lockTime);

        user.lockTime = toUint48(_lockTime);

        // using SafeERC20 for IERC20 => will revert in case of error
        IERC20(stakingToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        emit Stake(msg.sender, _amount, toUint48(block.timestamp)); // = user.stakeTime
        return _amount;
    }

    /**
     * withdraw staked token, ...
     * do not withdraw rewards token (it might not be worth the gas)
     * @return amount of tokens sent to user's account
     */
    function _withdraw(uint256 amount) internal returns (uint256) {
        require(amount > 0, "amount to withdraw not > 0");
        require(
            block.timestamp > getUnlockTime(msg.sender),
            "staked tokens are still locked"
        );

        User storage user = _updateRewards(msg.sender); // update rewards and return reference to user

        require(amount <= user.stakeAmount, "withdraw amount > staked amount");
        user.stakeAmount -= toUint160(amount);
        user.stakedSince = toUint48(block.timestamp);
        tokenTotalStaked -= amount;

        // using SafeERC20 for IERC20 => will revert in case of error
        IERC20(stakingToken).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, toUint48(block.timestamp)); // = user.stakeTime
        return amount;
    }

    /**
     * claim reward tokens for accumulated reward credits
     * ... but do not unstake staked token
     */
    function _claim() internal returns (uint256) {
        require(rewardToken != address(0), "no reward token contract");
        uint256 earnedRewardTokens = getEarnedRewardTokens(msg.sender);
        require(earnedRewardTokens > 0, "no tokens to claim");

        // like _updateRewards() , but reset all rewards to 0
        User storage user = userMap[msg.sender];
        user.accumulatedRewards = 0;
        user.stakeTime = toUint48(block.timestamp); // will reset userClaimableRewards to 0
        user.stakedSince = toUint48(block.timestamp);
        // user.stakeAmount = unchanged

        require(
            earnedRewardTokens <= getRewardTokenBalance(),
            "not enough reward tokens"
        ); // redundant but dedicated error message
        IERC20(rewardToken).safeTransfer(msg.sender, earnedRewardTokens);

        emit Claimed(msg.sender, rewardToken, earnedRewardTokens);
        return earnedRewardTokens;
    }

    function stake(uint256 _amount, uint48 _lockTime)
        external
        nonReentrant
        returns (uint256)
    {
        return _stake(_amount, _lockTime);
    }

    function claim() external nonReentrant returns (uint256) {
        return _claim();
    }

    function withdraw(uint256 amount) external nonReentrant returns (uint256) {
        return _withdraw(amount);
    }

    function withdrawAll() external nonReentrant returns (uint256) {
        return _withdraw(stakeAmount_msgSender());
    }

    /**
     * Do not accept accidently sent ETH :
     * If neither a receive Ether nor a payable fallback function is present,
     * the contract cannot receive Ether through regular transactions and throws an exception.
     * https://docs.soliditylang.org/en/v0.8.7/contracts.html#receive-ether-function
     */

    /**
     * @notice withdraw accidently sent ERC20 tokens
     * @param _tokenAddress address of token to withdraw
     */
    function removeOtherERC20Tokens(address _tokenAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _tokenAddress != address(stakingToken),
            "can not withdraw staking token"
        );
        uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).safeTransfer(msg.sender, balance);
        emit ERC20TokensRemoved(_tokenAddress, msg.sender, balance);
    }
}

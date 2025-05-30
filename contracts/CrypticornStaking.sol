// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// OpenZeppelin Imports
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract CrypticornStaking is Ownable, ReentrancyGuard {
    IERC20 public stakingToken;

    /// @dev 1e18 is used as a multiplier for APY calculations.
    uint256 public constant DECIMALS = 1e18;
    uint256 public constant ONE_YEAR = 365 days;

    // ========================
    // Structures & Mappings
    // ========================

    /// @dev Settings for each pool.
    struct Pool {
        uint256 lockPeriod; // Duration tokens must be locked (in seconds)
        uint256 apy; // APY expressed with DECIMALS precision (e.g. 2% = 2e16)
    }
    /// Three pools are available (keys: 1,2,3)
    mapping(uint8 => Pool) public pools;

    /// @dev A user's stake per pool.
    struct Stake {
        uint256 rewardBase; // Amount used for reward calculation (initial + added stake)
        uint256 currentStake; // Actual tokens physically held for the user (may be reduced by fee withdrawals)
        uint256 startTime; // Timestamp when the reward calculation last reset
        bool exists;
    }
    /// Mapping: user => poolId => Stake
    mapping(address => mapping(uint8 => Stake)) public stakes;

    /// @dev For user‑initiated withdrawals, the request is stored until the owner confirms.
    struct PendingWithdrawal {
        uint256 amount;
        bool exists;
    }
    /// Mapping: user => poolId => PendingWithdrawal
    mapping(address => mapping(uint8 => PendingWithdrawal))
        public pendingWithdrawals;

    /// @dev List of all stakers (for view functions, if needed)
    address[] public stakers;
    mapping(address => bool) public hasStaked;

    // ========================
    // Events
    // ========================
    event Staked(
        address indexed user,
        uint8 indexed poolId,
        uint256 amount,
        uint256 lockPeriod,
        uint256 apy
    );
    event StakeAdded(
        address indexed user,
        uint8 indexed poolId,
        uint256 amount
    );
    event RewardClaimed(
        address indexed user,
        uint8 indexed poolId,
        uint256 reward
    );
    event WithdrawalRequested(
        address indexed user,
        uint8 indexed poolId,
        uint256 amount
    );
    event WithdrawalCancelled(address indexed user, uint8 indexed poolId);
    event WithdrawalConfirmed(
        address indexed user,
        uint8 indexed poolId,
        uint256 amount
    );
    event OwnerFeeWithdrawal(
        address indexed user,
        uint8 indexed poolId,
        uint256 amount
    );
    event PoolUpdated(
        uint8 indexed poolId,
        uint256 newLockPeriod,
        uint256 newAPY
    );

    // ========================
    // Constructor & Initialization
    // ========================
    constructor(IERC20 _stakingToken) Ownable(msg.sender) {
        stakingToken = _stakingToken;
        // Initialize three pools with default settings:
        // Pool 1: Lock period 0 days, APY 2% (2e16)
        pools[1] = Pool({lockPeriod: 0, apy: 2e16});
        // Pool 2: Lock period 90 days, APY 10% (10e16)
        pools[2] = Pool({lockPeriod: 90 days, apy: 10e16});
        // Pool 3: Lock period 180 days, APY 15% (15e16)
        pools[3] = Pool({lockPeriod: 180 days, apy: 15e16});
    }

    // ========================
    // External Functions
    // ========================

    /**
     * @notice Stake tokens in a chosen pool.
     * @param poolId The pool to stake in (1,2, or 3).
     * @param amount The token amount to stake.
     */
    function stake(uint8 poolId, uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        require(poolId >= 1 && poolId <= 3, "Invalid pool");

        // Transfer staked tokens from the user.
        stakingToken.transferFrom(msg.sender, address(this), amount);

        Stake storage userStake = stakes[msg.sender][poolId];
        if (userStake.exists) {
            // If already staking in this pool, claim pending rewards first...
            _claimRewards(msg.sender, poolId);
            // ...then add the new amount.
            userStake.rewardBase += amount;
            userStake.currentStake += amount;
            userStake.startTime = block.timestamp; // reset reward timer
            emit StakeAdded(msg.sender, poolId, amount);
        } else {
            // New stake in this pool.
            stakes[msg.sender][poolId] = Stake({
                rewardBase: amount,
                currentStake: amount,
                startTime: block.timestamp,
                exists: true
            });
            // Add to stakers list if not already present.
            if (!hasStaked[msg.sender]) {
                stakers.push(msg.sender);
                hasStaked[msg.sender] = true;
            }
            emit Staked(
                msg.sender,
                poolId,
                amount,
                pools[poolId].lockPeriod,
                pools[poolId].apy
            );
        }
    }

    /**
     * @notice Add more tokens to an existing stake.
     * @param poolId The pool in which to add stake.
     * @param amount The additional token amount.
     */
    function addStake(uint8 poolId, uint256 amount) external nonReentrant {
        require(poolId >= 1 && poolId <= 3, "Invalid pool");
        require(amount > 0, "Cannot add 0");

        Stake storage userStake = stakes[msg.sender][poolId];
        require(userStake.exists, "No existing stake, use stake()");

        // Claim pending rewards first.
        _claimRewards(msg.sender, poolId);

        // Transfer new tokens and update stake.
        stakingToken.transferFrom(msg.sender, address(this), amount);
        userStake.rewardBase += amount;
        userStake.currentStake += amount;
        userStake.startTime = block.timestamp; // reset reward timer
        emit StakeAdded(msg.sender, poolId, amount);
    }

    /**
     * @notice Claim accumulated rewards without modifying stake.
     * @param poolId The pool from which to claim rewards.
     */
    function claimRewards(uint8 poolId) external nonReentrant {
        require(poolId >= 1 && poolId <= 3, "Invalid pool");
        Stake storage userStake = stakes[msg.sender][poolId];
        require(userStake.exists, "No stake");
        _claimRewards(msg.sender, poolId);
    }

    /**
     * @notice Request withdrawal of a portion of your stake.
     *         (The pool's lockPeriod must have passed.)
     *         The request is stored until the owner confirms.
     * @param poolId The pool from which to withdraw.
     * @param amount The amount to withdraw.
     */
    function requestWithdrawal(
        uint8 poolId,
        uint256 amount
    ) external nonReentrant {
        require(poolId >= 1 && poolId <= 3, "Invalid pool");
        Stake storage userStake = stakes[msg.sender][poolId];
        require(userStake.exists, "No stake");
        require(
            amount > 0 && amount <= userStake.currentStake,
            "Invalid amount"
        );

        // For user withdrawal, require the lockPeriod has passed.
        uint256 lockPeriod = pools[poolId].lockPeriod;
        require(
            block.timestamp >= userStake.startTime + lockPeriod,
            "Stake is locked"
        );

        PendingWithdrawal storage pending = pendingWithdrawals[msg.sender][
            poolId
        ];
        require(!pending.exists, "Withdrawal already pending");

        pendingWithdrawals[msg.sender][poolId] = PendingWithdrawal({
            amount: amount,
            exists: true
        });
        emit WithdrawalRequested(msg.sender, poolId, amount);
    }

    /**
     * @notice Cancel a pending withdrawal request.
     * @param poolId The pool for which to cancel withdrawal.
     */
    function cancelWithdrawal(uint8 poolId) external nonReentrant {
        require(poolId >= 1 && poolId <= 3, "Invalid pool");
        PendingWithdrawal storage pending = pendingWithdrawals[msg.sender][
            poolId
        ];
        require(pending.exists, "No pending withdrawal");
        delete pendingWithdrawals[msg.sender][poolId];
        emit WithdrawalCancelled(msg.sender, poolId);
    }

    /**
     * @notice Owner confirms a user's pending withdrawal request.
     *         Before transferring the stake, the contract first claims the rewards
     *         (so the user gets rewards calculated on his full rewardBase) and then
     *         reduces both rewardBase and currentStake.
     * @param user The address of the user.
     * @param poolId The pool from which to withdraw.
     */
    function confirmWithdrawal(
        address user,
        uint8 poolId
    ) external onlyOwner nonReentrant {
        require(poolId >= 1 && poolId <= 3, "Invalid pool");

        PendingWithdrawal storage pending = pendingWithdrawals[user][poolId];
        require(pending.exists, "No pending withdrawal");

        uint256 amount = pending.amount;
        Stake storage userStake = stakes[user][poolId];
        require(userStake.exists, "No stake for user");
        require(
            amount <= userStake.currentStake,
            "Amount exceeds current stake"
        );

        // Claim rewards first.
        _claimRewards(user, poolId);

        // For user withdrawals, reduce both the reward base and the current stake.
        userStake.rewardBase -= amount;
        userStake.currentStake -= amount;

        // Transfer the requested amount to the user.
        stakingToken.transfer(user, amount);

        // Clear the pending request.
        delete pendingWithdrawals[user][poolId];
        emit WithdrawalConfirmed(user, poolId, amount);
    }

    /**
     * @notice Owner can adjust a pending withdrawal (before confirmation).
     * @param user The address of the user.
     * @param poolId The pool id.
     * @param newAmount The new withdrawal amount.
     */
    function adjustWithdrawal(
        address user,
        uint8 poolId,
        uint256 newAmount
    ) external onlyOwner nonReentrant {
        require(poolId >= 1 && poolId <= 3, "Invalid pool");
        PendingWithdrawal storage pending = pendingWithdrawals[user][poolId];
        require(pending.exists, "No pending withdrawal");
        Stake storage userStake = stakes[user][poolId];
        require(
            newAmount > 0 && newAmount <= userStake.currentStake,
            "Invalid new amount"
        );
        pending.amount = newAmount;
        // (Optionally, emit an event for adjustment.)
    }

    /**
     * @notice Owner withdraws tokens from a user's stake (for fees).
     *         In this case, the user's reward base remains unchanged so he continues
     *         to earn rewards on the full initial+added amount.
     * @param user The address of the user.
     * @param poolId The pool id.
     * @param amount The amount to withdraw.
     */
    function ownerFeeWithdrawal(
        address user,
        uint8 poolId,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(poolId >= 1 && poolId <= 3, "Invalid pool");
        Stake storage userStake = stakes[user][poolId];
        require(userStake.exists, "No stake for user");
        require(
            amount > 0 && amount <= userStake.currentStake,
            "Invalid amount"
        );

        // Do not claim rewards here—the reward base stays the same.
        userStake.currentStake -= amount;
        stakingToken.transfer(msg.sender, amount);
        emit OwnerFeeWithdrawal(user, poolId, amount);
    }

    /**
     * @notice Owner can update pool settings (lockPeriod and APY).
     * @param poolId The pool id (1, 2, or 3).
     * @param newLockPeriod The new lock time in seconds.
     * @param newAPY The new APY (with DECIMALS precision).
     */
    function updatePool(
        uint8 poolId,
        uint256 newLockPeriod,
        uint256 newAPY
    ) external onlyOwner {
        require(poolId >= 1 && poolId <= 3, "Invalid pool");
        pools[poolId].lockPeriod = newLockPeriod;
        pools[poolId].apy = newAPY;
        emit PoolUpdated(poolId, newLockPeriod, newAPY);
    }

    // ========================
    // Internal Functions
    // ========================

    /**
     * @dev Claim pending rewards for a given user and pool.
     *      The reward is calculated as:
     *      reward = rewardBase * apy * elapsedTime / (ONE_YEAR * DECIMALS)
     *      After claiming, the startTime resets to now.
     * @param user The address of the user.
     * @param poolId The pool id.
     * @return reward The amount of reward claimed.
     */
    function _claimRewards(
        address user,
        uint8 poolId
    ) internal returns (uint256 reward) {
        Stake storage userStake = stakes[user][poolId];
        if (!userStake.exists) return 0;
        uint256 elapsed = block.timestamp - userStake.startTime;
        if (elapsed == 0) return 0;

        uint256 apy = pools[poolId].apy;
        reward = (userStake.rewardBase * apy * elapsed) / (ONE_YEAR * DECIMALS);
        if (reward > 0) {
            stakingToken.transfer(user, reward);
            emit RewardClaimed(user, poolId, reward);
        }
        // Reset the reward timer.
        userStake.startTime = block.timestamp;
    }

    // ========================
    // View Functions
    // ========================

    /**
     * @notice Get details of a user's stake in a pool.
     * @param user The address of the user.
     * @param poolId The pool id.
     * @return _rewardBase The reward base (initial+added amount).
     * @return _currentStake The actual tokens still held for the user.
     * @return _startTime The last reward reset timestamp.
     * @return _lockPeriod The pool lock duration.
     * @return _apy The pool APY.
     * @return _pendingReward The reward accrued since the last reset.
     */
    function getStakeDetails(
        address user,
        uint8 poolId
    )
        external
        view
        returns (
            uint256 _rewardBase,
            uint256 _currentStake,
            uint256 _startTime,
            uint256 _lockPeriod,
            uint256 _apy,
            uint256 _pendingReward
        )
    {
        require(poolId >= 1 && poolId <= 3, "Invalid pool");
        Stake storage userStake = stakes[user][poolId];
        require(userStake.exists, "No stake for user");
        Pool storage pool = pools[poolId];
        uint256 elapsed = block.timestamp - userStake.startTime;
        _pendingReward =
            (userStake.rewardBase * pool.apy * elapsed) /
            (ONE_YEAR * DECIMALS);
        return (
            userStake.rewardBase,
            userStake.currentStake,
            userStake.startTime,
            pool.lockPeriod,
            pool.apy,
            _pendingReward
        );
    }

    /**
     * @notice (Gas‑intensive) Returns the total tokens staked across all users and pools.
     */
    function getTotalStaked() external view returns (uint256 total) {
        for (uint256 i = 0; i < stakers.length; i++) {
            address user = stakers[i];
            for (uint8 poolId = 1; poolId <= 3; poolId++) {
                total += stakes[user][poolId].currentStake;
            }
        }
    }

    function rescueBNB() external onlyOwner {
        uint256 contractETHBalance = address(this).balance;
        payable(owner()).transfer(contractETHBalance);
    }

    function rescueERC20(address tokenAdd, uint256 amount) external onlyOwner {
        IERC20(tokenAdd).transfer(owner(), amount);
    }
}
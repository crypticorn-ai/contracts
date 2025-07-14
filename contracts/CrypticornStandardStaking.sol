// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// OpenZeppelin Imports
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CrypticornStandardStaking is Ownable, ReentrancyGuard {
    IERC20 public immutable stakingToken;
    uint256 public apy; // APY in basis points (10000 = 100%)
    uint256 public constant SECONDS_PER_YEAR = 31536000; // 365 days
    
    struct Staker {
        uint256 stakedAmount;
        uint256 rewardsAccumulated;
        uint256 lastUpdateTime;
        uint256 totalRewardsClaimed; // Track claimed rewards
    }

    mapping(address => Staker) public stakers;
    uint256 public totalStaked;
    uint256 public totalRewardsPaid;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event APYUpdated(uint256 newApy);
    event EmergencyUnstake(address indexed user, uint256 amount);

    constructor(address _stakingToken, uint256 _initialApy) Ownable(msg.sender) {
        require(_stakingToken != address(0), "Invalid token address");
        stakingToken = IERC20(_stakingToken);
        apy = _initialApy;
    }

    // ========== VIEW FUNCTIONS ========== //

    /**
     * @dev Get user's staking details
     * @param _user Wallet address to check
     * @return stakedAmount Currently staked tokens
     * @return pendingRewards Unclaimed rewards
     * @return totalEarned Total rewards earned (claimed + pending)
     * @return lastUpdateTime Last reward calculation time
     */
    function getUserInfo(address _user) public view returns (
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 totalEarned,
        uint256 lastUpdateTime
    ) {
        Staker memory staker = stakers[_user];
        uint256 rewards = getPendingRewards(_user);
        return (
            staker.stakedAmount,
            rewards,
            staker.totalRewardsClaimed + rewards,
            staker.lastUpdateTime
        );
    }

    /**
     * @dev Get pending rewards for a user
     * @param _user Wallet address to check
     * @return Amount of pending rewards in token units
     */
    function getPendingRewards(address _user) public view returns (uint256) {
        Staker memory staker = stakers[_user];
        if (staker.stakedAmount == 0) return staker.rewardsAccumulated;
        
        uint256 timeStaked = block.timestamp - staker.lastUpdateTime;
        uint256 annualReward = (staker.stakedAmount * apy) / 10000;
        uint256 pendingRewards = (annualReward * timeStaked) / SECONDS_PER_YEAR;
        
        return staker.rewardsAccumulated + pendingRewards;
    }

    /**
     * @dev Get total rewards earned by user (claimed + pending)
     * @param _user Wallet address to check
     * @return Total rewards earned
     */
    function getTotalEarned(address _user) external view returns (uint256) {
        (, , uint256 totalEarned, ) = getUserInfo(_user);
        return totalEarned;
    }

    /**
     * @dev Get user's staked balance
     * @param _user Wallet address to check
     * @return Amount of tokens currently staked
     */
    function getStakedBalance(address _user) external view returns (uint256) {
        return stakers[_user].stakedAmount;
    }

    // ========== USER OPERATIONS ========== //

    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake 0");
        
        Staker storage staker = stakers[msg.sender];
        _updateRewards(msg.sender);
        
        staker.stakedAmount += _amount;
        totalStaked += _amount;
        
        require(
            stakingToken.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        
        emit Staked(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot unstake 0");
        
        Staker storage staker = stakers[msg.sender];
        require(staker.stakedAmount >= _amount, "Insufficient balance");
        
        _updateRewards(msg.sender);
        
        staker.stakedAmount -= _amount;
        totalStaked -= _amount;
        
        require(
            stakingToken.transfer(msg.sender, _amount),
            "Transfer failed"
        );
        
        emit Unstaked(msg.sender, _amount);
    }

    function claimRewards() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        _updateRewards(msg.sender);
        
        uint256 rewards = staker.rewardsAccumulated;
        require(rewards > 0, "No rewards to claim");
        
        staker.rewardsAccumulated = 0;
        staker.totalRewardsClaimed += rewards;
        totalRewardsPaid += rewards;
        
        require(
            stakingToken.transfer(msg.sender, rewards),
            "Reward transfer failed"
        );
        
        emit RewardsClaimed(msg.sender, rewards);
    }

    // ========== INTERNAL & OWNER FUNCTIONS ========== //

    function _updateRewards(address _user) internal {
        Staker storage staker = stakers[_user];
        staker.rewardsAccumulated = getPendingRewards(_user);
        staker.lastUpdateTime = block.timestamp;
    }

    function setAPY(uint256 _newApy) external onlyOwner {
        require(_newApy <= 100000, "APY too high (max 1000%)");
        apy = _newApy;
        emit APYUpdated(_newApy);
    }

    function emergencyUnstake() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        uint256 amount = staker.stakedAmount;
        require(amount > 0, "Nothing to unstake");
        
        staker.stakedAmount = 0;
        staker.rewardsAccumulated = 0;
        totalStaked -= amount;
        
        require(
            stakingToken.transfer(msg.sender, amount),
            "Transfer failed"
        );
        
        emit EmergencyUnstake(msg.sender, amount);
    }

    // Withdraw excess reward tokens
    function withdrawExcessRewards(uint256 _amount) external onlyOwner {
        uint256 contractBalance = stakingToken.balanceOf(address(this));
        uint256 requiredBalance = totalStaked + totalRewardsPaid;
        
        require(
            contractBalance >= requiredBalance + _amount,
            "Insufficient excess balance"
        );
        
        require(
            stakingToken.transfer(owner(), _amount),
            "Transfer failed"
        );
    }
}
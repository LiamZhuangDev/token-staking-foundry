// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract GopherStaking is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    // staking token == reward token
    IERC20 public token;

    // reward tokens distributed per block
    uint256 public rewardPerBlock;

    // accumulated rewards per share, times 1e18 for precision
    uint256 public accRewardPerShare;

    // last block number that rewards were distributed
    uint256 public lastRewardBlock;

    // total amount of tokens staked
    uint256 public totalStaked;

    // ========================
    // Roles
    // ========================
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE"); // can upgrade the contract implementation
    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE"); // can change reward rate and fund the reward pool

    struct UserInfo {
        uint256 amount; // How many tokens the user has staked.
        uint256 rewardDebt; // How many rewards the user has already been paid out.
    }

    mapping(address => UserInfo) public users;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPerBlockUpdated(uint256 newRewardPerBlock);
    event RewardClaimed(address indexed user, uint256 amount);

    // The implementation contract should NEVER be initialized directly.
    // Constructor runs ONCE when implementation is deployed.
    // It permanently locks initialization on the implementation contract.
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _token, uint256 _rewardPerBlock) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        token = IERC20(_token);
        rewardPerBlock = _rewardPerBlock;
        lastRewardBlock = block.number;

        // ============================
        // Setup roles
        // ============================
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(REWARD_MANAGER_ROLE, admin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocks = block.number - lastRewardBlock;
        uint256 rewards = blocks * rewardPerBlock;
        accRewardPerShare += (rewards * 1e18) / totalStaked;
        lastRewardBlock = block.number;
    }

    function pendingRewards(address _user) public view returns (uint256) {
        UserInfo storage user = users[_user];
        uint256 _accRewardPerShare = accRewardPerShare;

        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 blocks = block.number - lastRewardBlock;
            uint256 rewards = blocks * rewardPerBlock;
            _accRewardPerShare += (rewards * 1e18) / totalStaked;
        }

        return (user.amount * _accRewardPerShare) / 1e18 - user.rewardDebt;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");

        UserInfo storage user = users[msg.sender];

        _updatePool();

        // pay pending rewards first
        uint256 pending = (user.amount * accRewardPerShare) / 1e18 - user.rewardDebt;
        if (pending > 0) {
            token.safeTransfer(msg.sender, pending);

            emit RewardClaimed(msg.sender, pending);
        }

        // transfer staked tokens to the contract
        token.safeTransferFrom(msg.sender, address(this), amount);

        // update user info
        user.amount += amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e18;

        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    // if amount is 0, it will just claim rewards without withdrawing any staked tokens
    function withdraw(uint256 amount) external {
        UserInfo storage user = users[msg.sender];
        require(user.amount >= amount, "Not enough staked");

        _updatePool();

        // pay pending rewards first
        uint256 pending = (user.amount * accRewardPerShare) / 1e18 - user.rewardDebt;
        if (pending > 0) {
            token.safeTransfer(msg.sender, pending);

            emit RewardClaimed(msg.sender, pending);
        }

        // update user info before transferring tokens out to prevent reentrancy issues
        if (amount > 0) {
            user.amount -= amount;
            totalStaked -= amount;
            token.safeTransfer(msg.sender, amount);
        }

        // update reward debt after withdrawal to reflect the new staked amount
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e18;

        emit Withdrawn(msg.sender, amount);
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyRole(REWARD_MANAGER_ROLE) {
        // update pool to distribute rewards up to the current block before changing the reward rate
        _updatePool();
        // set new reward per block
        rewardPerBlock = _rewardPerBlock;

        emit RewardPerBlockUpdated(_rewardPerBlock);
    }

    function fund(uint256 amount) external onlyRole(REWARD_MANAGER_ROLE) {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }
}

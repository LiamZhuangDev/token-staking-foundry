// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GopherStaking is Ownable {
    using SafeERC20 for IERC20;

    // staking token == reward token
    IERC20 public immutable token;

    // reward tokens distributed per block
    uint256 public rewardPerBlock;

    // accumulated rewards per share, times 1e18 for precision
    uint256 public accRewardPerShare;

    // last block number that rewards were distributed
    uint256 public lastRewardBlock;

    // total amount of tokens staked
    uint256 public totalStaked;

    struct UserInfo {
        uint256 amount; // How many tokens the user has staked.
        uint256 rewardDebt; // How many rewards the user has already been paid out.
    }

    mapping(address => UserInfo) public users;

    constructor(
        address _token,
        uint256 _rewardPerBlock
    ) Ownable(msg.sender) {
        token = IERC20(_token);
        rewardPerBlock = _rewardPerBlock;
        lastRewardBlock = block.number; // block is a global variable provided by the EVM/Solidity runtime.
    }

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
        }

        // transfer staked tokens to the contract
        token.safeTransferFrom(msg.sender, address(this), amount);
        
        // update user info
        user.amount += amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e18;

        totalStaked += amount;
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
        }
        
        // update user info before transferring tokens out to prevent reentrancy issues
        if (amount > 0) {
            user.amount -= amount;
            totalStaked -= amount;
            token.safeTransfer(msg.sender, amount);
        }

        // update reward debt after withdrawal to reflect the new staked amount
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e18;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        // update pool to distribute rewards up to the current block before changing the reward rate
        _updatePool();
        // set new reward per block
        rewardPerBlock = _rewardPerBlock;
    }

    function fund(uint256 amount) external onlyOwner {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }
}
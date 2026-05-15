// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {GopherToken} from "../src/GopherToken.sol";
import {GopherStaking} from "../src/GopherStaking.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GopherStakingTest is Test {
    GopherToken public token;
    GopherStaking public staking;

    address public admin = address(this);
    address public alice = address(1);
    address public bob = address(2);

    uint256 public constant INITIAL_USER_BALANCE = 1_000 ether;
    uint256 public constant REWARD_PER_BLOCK = 1 ether;

    function setUp() public {
        // deploy token
        token = new GopherToken();

        // deploy staking implementation
        GopherStaking implementation = new GopherStaking();

        // encode initialize call
        bytes memory initData = abi.encodeCall(GopherStaking.initialize, (admin, address(token), REWARD_PER_BLOCK));

        // deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        // interact with proxy as staking contract
        staking = GopherStaking(address(proxy));

        // give users tokens
        token.transfer(alice, INITIAL_USER_BALANCE);

        token.transfer(bob, INITIAL_USER_BALANCE);

        // fund staking contract with rewards
        uint256 rewardPool = 100_000 ether;

        token.transfer(address(staking), rewardPool);
    }

    /*//////////////////////////////////////////////////////////////
                            STAKE TESTS
    //////////////////////////////////////////////////////////////*/

    function testStake() public {
        uint256 amount = 100 ether;

        vm.startPrank(alice);

        token.approve(address(staking), amount);
        staking.stake(amount);

        vm.stopPrank();

        (uint256 stakedAmount, uint256 rewardDebt) = staking.users(alice);

        assertEq(stakedAmount, amount);
        assertEq(rewardDebt, 0);
        assertEq(staking.totalStaked(), amount);

        // alice wallet balance reduced
        assertEq(token.balanceOf(alice), INITIAL_USER_BALANCE - amount);
    }

    function testCannotStakeZero() public {
        vm.startPrank(alice);

        vm.expectRevert("Cannot stake 0");
        staking.stake(0);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        REWARD ACCRUAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testPendingRewards() public {
        uint256 amount = 100 ether;

        vm.startPrank(alice);

        token.approve(address(staking), amount);
        staking.stake(amount);

        vm.stopPrank();

        // move forward 10 blocks
        vm.roll(block.number + 10);

        uint256 pending = staking.pendingRewards(alice);

        // 10 blocks * 1 token per block
        assertEq(pending, 10 ether);

        // move forward 5 blocks
        vm.roll(block.number + 5);

        pending = staking.pendingRewards(alice);

        // 5 blocks * 1 token per block + previous 10 tokens
        assertEq(pending, 15 ether);
    }

    function testClaimRewardsViaWithdrawZero() public {
        uint256 amount = 100 ether;

        vm.startPrank(alice);

        token.approve(address(staking), amount);
        staking.stake(amount);

        vm.roll(block.number + 10);

        uint256 balanceBefore = token.balanceOf(alice);

        // claim rewards only
        staking.withdraw(0);

        uint256 balanceAfter = token.balanceOf(alice);

        vm.stopPrank();

        assertEq(balanceAfter - balanceBefore, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function testWithdraw() public {
        uint256 amount = 100 ether;

        vm.startPrank(alice);

        token.approve(address(staking), amount);
        staking.stake(amount);

        vm.roll(block.number + 10);

        staking.withdraw(40 ether);

        vm.stopPrank();

        (uint256 stakedAmount, uint256 rewardDebt) = staking.users(alice);

        // remaining stake
        assertEq(stakedAmount, 60 ether);

        // total staked updated
        assertEq(staking.totalStaked(), 60 ether);

        // reward debt should reflect new stake amount
        assertEq(rewardDebt, (60 ether * staking.accRewardPerShare()) / 1e18);
    }

    function testCannotWithdrawMoreThanStaked() public {
        vm.startPrank(alice);

        vm.expectRevert("Not enough staked");
        staking.withdraw(1 ether);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI USER TESTS
    //////////////////////////////////////////////////////////////*/

    function testMultipleUsersRewards() public {
        // alice stakes 100
        vm.startPrank(alice);
        token.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();

        // after 10 blocks, bob joins
        vm.roll(block.number + 10);

        vm.startPrank(bob);
        token.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();

        // another 10 blocks pass
        vm.roll(block.number + 10);

        uint256 alicePending = staking.pendingRewards(alice);
        uint256 bobPending = staking.pendingRewards(bob);

        // alice:
        // first 10 blocks alone = 10
        // next 10 blocks shared = 5
        // total = 15
        assertEq(alicePending, 15 ether);

        // bob:
        // only shared phase = 5
        assertEq(bobPending, 5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNER FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetRewardPerBlock() public {
        staking.setRewardPerBlock(2 ether);

        assertEq(staking.rewardPerBlock(), 2 ether);
    }

    function testOnlyOwnerCanSetRewardPerBlock() public {
        vm.startPrank(alice);

        vm.expectRevert();
        staking.setRewardPerBlock(2 ether);

        vm.stopPrank();
    }

    function testFund() public {
        uint256 amount = 1_000 ether;

        // owner approves staking contract
        token.approve(address(staking), amount);

        uint256 beforeBalance = token.balanceOf(address(staking));

        staking.fund(amount);

        uint256 afterBalance = token.balanceOf(address(staking));

        assertEq(afterBalance - beforeBalance, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        ACC REWARD TESTS
    //////////////////////////////////////////////////////////////*/

    function testAccRewardPerShareUpdates() public {
        vm.startPrank(alice);

        token.approve(address(staking), 100 ether);
        staking.stake(100 ether);

        vm.stopPrank();

        vm.roll(block.number + 10);

        staking.pendingRewards(alice);

        // manually trigger update
        vm.prank(alice);
        staking.withdraw(0);

        uint256 expected = (10 ether * 1e18) / 100 ether;

        assertEq(staking.accRewardPerShare(), expected);
    }
}

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {GopherToken} from "../src/GopherToken.sol";
import {GopherStaking} from "../src/GopherStaking.sol";

contract Deploy is Script {
    function run() public {
        // load privte key from .env file
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // deploy GopherToken
        GopherToken token = new GopherToken();

        // deploy GopherStaking
        // set reward per block to 1 token, 1e18 (10 ** 18) amount of smallest units of the token
        uint256 rewardPerBlock = 1 ether;
        GopherStaking staking = new GopherStaking(address(token), rewardPerBlock);

        // fund staking contract with tokens for rewards
        uint256 initialRewardBalance = 100_000 * 1 ether;
        // two ways to fund the staking contract:
        // 1. approve and fund
        // // approve staking contract to spend deployer's tokens
        // token.approve(address(staking), initialRewardBalance);
        // // staking contract pulls the tokens
        // staking.fund(initialRewardBalance);
        // or
        // 2. simply transfer tokens to the staking contract
        token.transfer(address(staking), initialRewardBalance);

        vm.stopBroadcast();

        console.log("GopherToken deployed at:", address(token));
        console.log("GopherStaking deployed at:", address(staking));
    }
}

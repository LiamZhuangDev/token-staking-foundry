// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "forge-std/Script.sol";

import {GopherToken} from "../src/GopherToken.sol";
import {GopherStaking} from "../src/GopherStaking.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // deploy token
        GopherToken token = new GopherToken();

        // deploy implementation
        GopherStaking implementation = new GopherStaking();

        uint256 rewardPerBlock = 1 ether;

        // encode initialize call
        bytes memory initData = abi.encodeCall(GopherStaking.initialize, (msg.sender, address(token), rewardPerBlock));

        // deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        // treat proxy as staking contract
        GopherStaking staking = GopherStaking(address(proxy));

        // fund staking contract
        uint256 initialRewardBalance = 100_000 ether;

        token.transfer(address(staking), initialRewardBalance);

        vm.stopBroadcast();

        console.log("GopherToken deployed at:", address(token));

        console.log("GopherStaking implementation:", address(implementation));

        console.log("GopherStaking proxy:", address(staking));
    }
}

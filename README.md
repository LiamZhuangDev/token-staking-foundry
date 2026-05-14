### Create project
```shell
$ forge init token-staking-foundry
$ cd token-staking-foundry
```

### Create `GopherToken.sol`
```solidity
// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GopherToken is ERC20 {
    constructor() ERC20("GopherToken", "GPT") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
```

```shell
$ forge install OpenZeppelin/openzeppelin-contracts
```

Create remapping `remappings.txt` to translate Solidity import paths into actual filesystem paths
```
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
forge-std/=lib/forge-std/src/
```
### Create `GopherStaking.sol`
See https://github.com/LiamZhuangDev/token-staking-foundry/commit/8fcdc9ed30af6503ccfb1f2fce14ccb22c41f3fd
```
Formula to calculate pending rewards = (user.amount * accRewardPerShare) / decimals - user.rewardDebt
```

### Build

```shell
$ forge build
```

### Format

```shell
$ forge fmt
```

### Deploy
```
src/
├── GopherToken.sol
└── GopherStaking.sol

script/
└── Deploy.s.sol

foundry.toml
```
- Start Anvil local node
  ```shell
  anvil
  ```
- Update vars in `.env`
  ```
  DEPLOYER_PRIVATE_KEY=0x<PRIVATE_KEY_ANVIL_PROVIDED>
  RPC_URL=http://127.0.0.1:8545
  ```
- Create `Deploy.s.sol`
  ```solidity
  uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

  vm.startBroadcast(deployerPrivateKey);

  // deploy GopherToken
  GopherToken token = new GopherToken();

  // deploy GopherStaking
  uint256 rewardPerBlock = 1 ether;
  GopherStaking staking = new GopherStaking(address(token), rewardPerBlock);

  vm.stopBroadcast();
  ```
- Run forge script to deploy
  ```shell
  # load environment vars from the .env file into the current shell session
  $ source .env

  $ forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast
  ```

### Interaction

```shell
# Approve staking contract
# !!!must run first or reverted due to ERC20InsufficientAllowance
cast send <TOKEN_ADDRESS> \
  "approve(address, uint256)" \
  <STAKING_ADDRESS> \
  100000000000000000000 \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --rpc-url $RPC_URL

# Stak
cast send <STAKING_ADDRESS> \
  "stake(uint256)" \
  100000000000000000000 \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --rpc-url $RPC_URL

# Claim rewards only
cast send <STAKING_ADDRESS> \
  "withdraw(uint256)" \
  0 \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --rpc-url $RPC_URL

# Check Deployer Token Balance
cast call <TOKEN_ADDRESS> \
  "balanceOf(address)(uint256)" \
  <DEPLOYER_ADDRESS> \
  --rpc-url $RPC_URL

# Withdraw stake
cast send <STAKING_ADDRESS> \
  "withdraw(uint256)" \
  50000000000000000000 \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### Test
- Create `GopherStaking.t.sol` 
  ```solidity
  contract GopherStakingTest is Test {
      GopherToken public token;
      GopherStaking public staking;
      address public owner = address(this);
      address public alice = address(1);
      address public bob = address(2);
      uint256 public constant INITIAL_USER_BALANCE = 1_000 ether;
      uint256 public constant REWARD_PER_BLOCK = 1 ether;
      
      function setUp() public {
          // deploy contracts
          token = new GopherToken();
          staking = new GopherStaking(address(token), REWARD_PER_BLOCK);
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
          assertEq(
              token.balanceOf(alice),
              INITIAL_USER_BALANCE - amount
          );
      }

      // other tests
  }
  ```
- Run forge test
  ```shell
  $ forge test
  ```
- Run test with Gas Report
  ```shell
  forge test --gas-report
  ```
- Test Coverage
  ```shell
  $ forge coverage
  ```
- How to find missing branches
  - Generate coverage file
  ```shell
  $ forge coverage --report debug > coverage.txt
  ```
  - and look for `hits: 0` in `coverage.txt`
  ```
  Branch (branch: 1, path: 0)
  hits: 0
  ```
  - add test function to improve the coverage

### Gas Snapshots
- creates a gas usage snapshot file for your tests, mainly used for detecting gas regressions
  ```shell
  $ forge snapshot
  ```

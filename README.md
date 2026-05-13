## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Create project
```shell
forge init token-staking-foundry
cd token-staking-foundry
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
forge install OpenZeppelin/openzeppelin-contracts
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
  source .env

  forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast
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
---

























### Test

```shell
$ forge test
```



### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

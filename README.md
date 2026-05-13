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

```shell
forge build
```
### Create `GopherStaking.sol`
See https://github.com/LiamZhuangDev/token-staking-foundry/commit/8fcdc9ed30af6503ccfb1f2fce14ccb22c41f3fd
```
Formula to calculate pending rewards = (user.amount * accRewardPerShare) / decimals - user.rewardDebt
```
---
### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
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

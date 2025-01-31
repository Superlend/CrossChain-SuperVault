## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

-   **SuperVault.sol**: Main contract handling the vault logic and interaction with underlying wrapper/fuse contracts.
-   **AaveV3Wrapper.sol**: Wrapper contract for interacting with the Aave V3 protocol.
-   **CompoundV3Wrapper.sol**: Wrapper contract for interacting with the Compound V3 protocol.
-   **AaveV3Spoke.sol**: Spoke contract for interacting with the Aave V3 protocol on destination chains.

-   **Architecture**: https://excalidraw.com/#json=A9x44P-yUQKIu4Bldloho,oQLMmGKjLOUutTl6N4Pifg

## Usage

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
# Superlend-Best-Returns-Vault

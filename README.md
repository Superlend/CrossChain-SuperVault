## CrossChain-SuperVault

This is a cross-chain vault that allows users to deposit assets into the vault and vault mints share tokens, while in the backgrounf according to the strategies added in DepositQueue the funds are deposited in those protocols. After that whenever rebalancing happens the funds are withdrawn and sent to the destination chain spoke contracts and deposited in underlying protocols.

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

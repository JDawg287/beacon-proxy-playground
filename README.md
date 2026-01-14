# Beacon Proxy Playground

A Foundry-based playground demonstrating OpenZeppelin Beacon Proxy patterns with EIP-7201 namespaced storage.

## Overview

This project implements a Token Vault using the beacon proxy pattern, showcasing:

- **EIP-7201 Namespaced Storage** - Upgrade-safe storage layout
- **Beacon Proxy Pattern** - Single upgrade point for multiple proxies
- **Re-entrancy Protection** - Custom guard using namespaced storage
- **Immutable Factory** - Trustless proxy deployment

## Architecture

```
External Multisig/Timelock ──owns──► UpgradeableBeacon
                                            │
                                            │ holds implementation
                                            ▼
┌──────────────────┐              ┌──────────────────┐
│ BeaconProxyFactory│──references─►│ TokenVaultV1/V2  │
│ (immutable)       │              │ (implementation) │
└────────┬─────────┘              └──────────────────┘
         │ deploys
         ▼
┌──────────────────┐
│ BeaconProxy      │──delegatecall──► implementation
│ (per deployment) │
└──────────────────┘
```

## Contracts

| Contract | Description |
|----------|-------------|
| `TokenVaultV1.sol` | Initial vault implementation with deposit/withdraw |
| `TokenVaultV2.sol` | Upgraded implementation adding `withdrawTo()` |
| `BeaconProxyFactory.sol` | Immutable factory for deploying beacon proxies |
| `ITokenVault.sol` | Interface for vault implementations |

## Features

### Token Vault
- Deposit ERC20 tokens
- Withdraw to self (V1) or to any address (V2)
- Per-user balance tracking
- Single allowed token per vault instance

### Security
- Re-entrancy protection on all state-changing functions
- EIP-7201 namespaced storage prevents storage collisions
- Immutable factory promotes decentralized trust
- Beacon ownership enables controlled upgrades

## Installation

```bash
# Clone the repository
git clone https://github.com/JDawg287/beacon-proxy-playground.git
cd beacon-proxy-playground

# Install dependencies
forge install
```

## Usage

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/TokenVault.t.sol

# Gas report
forge test --gas-report
```

### Deploy

1. Set environment variables:
```bash
export PRIVATE_KEY=<your-private-key>
export BEACON_OWNER=<multisig-or-timelock-address>
```

2. Deploy infrastructure:
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url <RPC_URL> --broadcast
```

3. Deploy a proxy:
```bash
export FACTORY=<factory-address>
export VAULT_OWNER=<vault-owner-address>
export ALLOWED_TOKEN=<erc20-token-address>

forge script script/Deploy.s.sol:DeployProxyScript --rpc-url <RPC_URL> --broadcast
```

### Upgrade

```bash
export BEACON_OWNER_PRIVATE_KEY=<beacon-owner-key>
export BEACON=<beacon-address>
export NEW_IMPLEMENTATION=<new-implementation-address>

forge script script/Deploy.s.sol:UpgradeScript --rpc-url <RPC_URL> --broadcast
```

## Project Structure

```
beacon-proxy-playground/
├── src/
│   ├── TokenVaultV1.sol
│   ├── TokenVaultV2.sol
│   ├── BeaconProxyFactory.sol
│   └── interfaces/
│       └── ITokenVault.sol
├── test/
│   ├── Base.t.sol
│   ├── TokenVault.t.sol
│   ├── BeaconProxy.t.sol
│   └── mocks/
│       └── MockERC20.sol
├── script/
│   └── Deploy.s.sol
├── docs/
│   └── plans/
├── lib/
├── foundry.toml
├── CLAUDE.md
└── README.md
```

## Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) v5.5.0
- [Forge Std](https://github.com/foundry-rs/forge-std) v1.14.0

## License

MIT

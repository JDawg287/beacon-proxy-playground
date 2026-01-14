# Beacon Proxy Playground

## Project Overview

An OpenZeppelin Beacon Proxy playground built with Foundry. Demonstrates upgradeable proxy patterns with EIP-7201 namespaced storage.

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

## Key Design Decisions

### Separation of Concerns
- **Beacon**: OZ `UpgradeableBeacon`, owned by external multisig/timelock, controls implementation address
- **Factory**: Immutable, no owner, only deploys proxies referencing the beacon
- **Implementation**: Stateless logic, all state via EIP-7201 namespaced storage

### EIP-7201 Storage
All implementation state lives in a namespaced storage slot:
- Namespace: `beacon-proxy-playground.storage.TokenVault`
- Contains: `owner`, `allowedToken`, `balances` mapping, `_lock` (reentrancy)

### Re-entrancy Protection
Custom re-entrancy guard using EIP-7201 namespaced `_lock` field. Applied to `deposit()` and `withdraw()`.

### Immutability
- Factory has no owner or admin functions
- Beacon ownership is external (multisig/timelock)
- Promotes decentralized trust

## Contracts

| Contract | Purpose |
|----------|---------|
| `ITokenVault.sol` | Shared interface for vault implementations |
| `TokenVaultV1.sol` | Initial implementation with deposit/withdraw |
| `TokenVaultV2.sol` | Upgrade example adding `withdrawTo()` |
| `BeaconProxyFactory.sol` | Deploys beacon proxies with initialization |

## TokenVault Functionality

- `initialize(owner, allowedToken)` - One-time setup per proxy
- `deposit(amount)` - Anyone deposits allowed token
- `withdraw(amount)` - Users withdraw their own balance
- `balanceOf(user)` - View user balance
- Per-user balance tracking
- Single allowed ERC20 token per vault instance

## Testing

```bash
forge test
```

### Test Structure
- `Base.t.sol` - Shared deployments and helpers
- `TokenVault.t.sol` - Implementation unit tests (deposit, withdraw, reentrancy)
- `BeaconProxy.t.sol` - Proxy deployment and upgrade tests

## Commands

```bash
# Build
forge build

# Test
forge test

# Test with verbosity
forge test -vvv

# Gas report
forge test --gas-report

# Deploy (example)
forge script script/Deploy.s.sol --rpc-url <RPC_URL> --broadcast
```

## Dependencies

- OpenZeppelin Contracts (UpgradeableBeacon, BeaconProxy, Initializable)

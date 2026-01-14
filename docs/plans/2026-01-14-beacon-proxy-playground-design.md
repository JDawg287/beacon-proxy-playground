# Beacon Proxy Playground Design

**Date:** 2026-01-14
**Status:** Validated

## Overview

A Foundry-based playground demonstrating OpenZeppelin Beacon Proxy patterns with EIP-7201 namespaced storage. The sample implementation is a Token Vault with per-user balance tracking.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        OWNERSHIP                                 │
│  External Multisig/Timelock ──owns──► UpgradeableBeacon         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        CONTRACTS                                 │
│                                                                  │
│  ┌──────────────────┐     ┌──────────────────┐                  │
│  │ UpgradeableBeacon│     │ BeaconProxyFactory│                  │
│  │ (OZ standard)    │◄────│ (immutable)       │                  │
│  │                  │refs │                   │                  │
│  │ - implementation │     │ - beacon (immut.) │                  │
│  │ - owner          │     │ - deployProxy()   │                  │
│  └────────┬─────────┘     └──────────────────┘                  │
│           │                        │                             │
│           │ points to              │ deploys                     │
│           ▼                        ▼                             │
│  ┌──────────────────┐     ┌──────────────────┐                  │
│  │ TokenVaultV1     │     │ BeaconProxy      │                  │
│  │ (implementation) │◄────│ (per deployment) │                  │
│  │                  │delegatecall            │                  │
│  │ - EIP-7201 slot  │     │                  │                  │
│  │ - deposit()      │     └──────────────────┘                  │
│  │ - withdraw()     │                                           │
│  └──────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

### Key Decisions

1. **Factory is immutable** - No owner, no admin functions. Promotes decentralized trust.
2. **Beacon is OZ standard** - `UpgradeableBeacon` owned by external multisig/timelock.
3. **Separation of concerns** - Factory deploys proxies, Beacon controls implementation.
4. **EIP-7201 storage** - Namespaced storage prevents collisions, upgrade-safe.

## EIP-7201 Storage Layout

```solidity
// Namespace: beacon-proxy-playground.storage.TokenVault
// Slot: keccak256(abi.encode(uint256(keccak256("beacon-proxy-playground.storage.TokenVault")) - 1)) & ~bytes32(uint256(0xff))

struct TokenVaultStorage {
    address owner;
    address allowedToken;
    mapping(address user => uint256 balance) balances;
    uint256 _lock; // Re-entrancy guard
}
```

### Storage Access Pattern

```solidity
bytes32 private constant STORAGE_SLOT = 0x...;

function _getStorage() private pure returns (TokenVaultStorage storage $) {
    assembly {
        $.slot := STORAGE_SLOT
    }
}
```

### Initialization

- `initialize(address owner, address allowedToken)` called once per proxy
- Uses OpenZeppelin's `Initializable` to prevent re-initialization
- Factory calls `initialize()` atomically during proxy deployment

## TokenVault Implementation

### Functions

| Function | Access | Re-entrancy Protected |
|----------|--------|----------------------|
| `initialize(owner, token)` | Once only | No (initializer guard) |
| `deposit(amount)` | Anyone | Yes |
| `withdraw(amount)` | Anyone (own balance) | Yes |
| `balanceOf(user)` | View | N/A |
| `owner()` | View | N/A |
| `allowedToken()` | View | N/A |

### Re-entrancy Protection

Custom modifier using EIP-7201 namespaced `_lock` field:

```solidity
uint256 private constant NOT_ENTERED = 1;
uint256 private constant ENTERED = 2;

modifier nonReentrant() {
    TokenVaultStorage storage $ = _getStorage();
    if ($._lock == ENTERED) revert ReentrancyGuard();
    $._lock = ENTERED;
    _;
    $._lock = NOT_ENTERED;
}
```

### Events & Errors

```solidity
event Deposited(address indexed user, uint256 amount);
event Withdrawn(address indexed user, uint256 amount);

error NotOwner();
error InvalidToken();
error InsufficientBalance();
error ReentrancyGuard();
error ZeroAmount();
```

## V2 Upgrade

`TokenVaultV2` extends functionality for testing upgrades:

- Adds `withdrawTo(amount, recipient)` - withdraw to different address
- Same storage layout (EIP-7201 compatible)
- Demonstrates seamless beacon upgrade

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
├── lib/
├── docs/
│   └── plans/
├── foundry.toml
├── CLAUDE.md
└── README.md
```

## Test Plan

### Base.t.sol (Shared)

```solidity
abstract contract BaseTest is Test {
    UpgradeableBeacon public beacon;
    BeaconProxyFactory public factory;
    TokenVaultV1 public implementation;
    MockERC20 public token;

    address public owner;
    address public user;

    function setUp() public virtual;
    function _deployProxy(address _owner, address _token) internal returns (address);
    function _depositAs(address proxy, address depositor, uint256 amount) internal;
}
```

### TokenVault.t.sol

| Test | Description |
|------|-------------|
| `test_Deposit` | Users can deposit allowed token |
| `test_Withdraw` | Users withdraw own balance |
| `test_WithdrawInsufficientBalance` | Reverts on insufficient balance |
| `test_ReentrancyBlock` | Reentrant calls revert |
| `test_WrongToken` | Reverts on wrong token |

### BeaconProxy.t.sol

| Test | Description |
|------|-------------|
| `test_DeployProxy` | Factory deploys proxy correctly |
| `test_Initialize` | Proxy initializes with owner + token |
| `test_CannotReinitialize` | Re-initialization reverts |
| `test_Upgrade` | Beacon upgrade succeeds |
| `test_V2Functions` | New V2 functions work post-upgrade |
| `test_StoragePersistence` | Balances survive upgrade |

## Dependencies

- `openzeppelin-contracts` - UpgradeableBeacon, BeaconProxy, Initializable

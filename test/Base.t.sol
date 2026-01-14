// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TokenVaultV1} from "../src/TokenVaultV1.sol";
import {TokenVaultV2} from "../src/TokenVaultV2.sol";
import {BeaconProxyFactory} from "../src/BeaconProxyFactory.sol";
import {ITokenVault} from "../src/interfaces/ITokenVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @title BaseTest
/// @notice Shared test setup and helpers for all tests
abstract contract BaseTest is Test {
    // Contracts
    UpgradeableBeacon public beacon;
    BeaconProxyFactory public factory;
    TokenVaultV1 public implementationV1;
    TokenVaultV2 public implementationV2;
    MockERC20 public token;

    // Actors
    address public beaconOwner;
    address public vaultOwner;
    address public user1;
    address public user2;

    // Constants
    uint256 public constant INITIAL_BALANCE = 1000 ether;

    function setUp() public virtual {
        // Setup actors
        beaconOwner = makeAddr("beaconOwner");
        vaultOwner = makeAddr("vaultOwner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mock token
        token = new MockERC20("Test Token", "TEST", 18);

        // Mint tokens to users
        token.mint(user1, INITIAL_BALANCE);
        token.mint(user2, INITIAL_BALANCE);

        // Deploy implementations
        implementationV1 = new TokenVaultV1();
        implementationV2 = new TokenVaultV2();

        // Deploy beacon with beaconOwner as owner
        vm.prank(beaconOwner);
        beacon = new UpgradeableBeacon(address(implementationV1), beaconOwner);

        // Deploy factory
        factory = new BeaconProxyFactory(address(beacon));

        // Label addresses for better trace output
        vm.label(address(beacon), "Beacon");
        vm.label(address(factory), "Factory");
        vm.label(address(implementationV1), "ImplementationV1");
        vm.label(address(implementationV2), "ImplementationV2");
        vm.label(address(token), "Token");
    }

    /// @notice Deploy a new proxy via factory
    /// @param owner_ The owner of the vault
    /// @param token_ The allowed token
    /// @return proxy The deployed proxy address
    function _deployProxy(address owner_, address token_) internal returns (address proxy) {
        proxy = factory.deployProxy(owner_, token_);
        vm.label(proxy, "VaultProxy");
    }

    /// @notice Deploy a deterministic proxy via factory
    /// @param owner_ The owner of the vault
    /// @param token_ The allowed token
    /// @param salt The salt for CREATE2
    /// @return proxy The deployed proxy address
    function _deployProxyDeterministic(address owner_, address token_, bytes32 salt) internal returns (address proxy) {
        proxy = factory.deployProxyDeterministic(owner_, token_, salt);
        vm.label(proxy, "VaultProxy");
    }

    /// @notice Deposit tokens as a specific user
    /// @param proxy The proxy address
    /// @param depositor The depositor address
    /// @param amount The amount to deposit
    function _depositAs(address proxy, address depositor, uint256 amount) internal {
        vm.startPrank(depositor);
        token.approve(proxy, amount);
        ITokenVault(proxy).deposit(amount);
        vm.stopPrank();
    }

    /// @notice Withdraw tokens as a specific user
    /// @param proxy The proxy address
    /// @param withdrawer The withdrawer address
    /// @param amount The amount to withdraw
    function _withdrawAs(address proxy, address withdrawer, uint256 amount) internal {
        vm.prank(withdrawer);
        ITokenVault(proxy).withdraw(amount);
    }

    /// @notice Upgrade the beacon to V2
    function _upgradeToV2() internal {
        vm.prank(beaconOwner);
        beacon.upgradeTo(address(implementationV2));
    }
}

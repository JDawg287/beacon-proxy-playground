// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TokenVaultV1} from "../src/TokenVaultV1.sol";
import {BeaconProxyFactory} from "../src/BeaconProxyFactory.sol";

/// @title DeployScript
/// @notice Deploys the beacon proxy infrastructure
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address beaconOwner = vm.envAddress("BEACON_OWNER");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        TokenVaultV1 implementation = new TokenVaultV1();
        console.log("TokenVaultV1 deployed at:", address(implementation));

        // Deploy beacon with specified owner
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(implementation), beaconOwner);
        console.log("UpgradeableBeacon deployed at:", address(beacon));
        console.log("Beacon owner:", beaconOwner);

        // Deploy factory
        BeaconProxyFactory factory = new BeaconProxyFactory(address(beacon));
        console.log("BeaconProxyFactory deployed at:", address(factory));

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("Implementation: ", address(implementation));
        console.log("Beacon:         ", address(beacon));
        console.log("Factory:        ", address(factory));
    }
}

/// @title DeployProxyScript
/// @notice Deploys a new proxy via the factory
contract DeployProxyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factory = vm.envAddress("FACTORY");
        address owner = vm.envAddress("VAULT_OWNER");
        address token = vm.envAddress("ALLOWED_TOKEN");

        vm.startBroadcast(deployerPrivateKey);

        address proxy = BeaconProxyFactory(factory).deployProxy(owner, token);
        console.log("Proxy deployed at:", proxy);

        vm.stopBroadcast();
    }
}

/// @title UpgradeScript
/// @notice Upgrades the beacon to a new implementation
contract UpgradeScript is Script {
    function run() external {
        uint256 beaconOwnerPrivateKey = vm.envUint("BEACON_OWNER_PRIVATE_KEY");
        address beaconAddress = vm.envAddress("BEACON");
        address newImplementation = vm.envAddress("NEW_IMPLEMENTATION");

        vm.startBroadcast(beaconOwnerPrivateKey);

        UpgradeableBeacon beacon = UpgradeableBeacon(beaconAddress);
        beacon.upgradeTo(newImplementation);

        console.log("Beacon upgraded to:", newImplementation);

        vm.stopBroadcast();
    }
}

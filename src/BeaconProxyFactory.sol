// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ITokenVault} from "./interfaces/ITokenVault.sol";

/// @title BeaconProxyFactory
/// @notice Immutable factory for deploying beacon proxies
/// @dev No admin functions - promotes decentralized trust
contract BeaconProxyFactory {
    /// @notice The beacon contract address
    address public immutable beacon;

    /// @notice Emitted when a new proxy is deployed
    /// @param proxy The address of the deployed proxy
    /// @param owner The owner of the vault
    /// @param allowedToken The allowed token for the vault
    event ProxyDeployed(address indexed proxy, address indexed owner, address indexed allowedToken);

    /// @notice Thrown when beacon address is zero
    error ZeroBeaconAddress();

    /// @notice Thrown when owner address is zero
    error ZeroOwnerAddress();

    /// @notice Thrown when token address is zero
    error ZeroTokenAddress();

    /// @param beacon_ The beacon contract address
    constructor(address beacon_) {
        if (beacon_ == address(0)) revert ZeroBeaconAddress();
        beacon = beacon_;
    }

    /// @notice Deploy a new beacon proxy with initialization
    /// @param owner_ The owner of the vault
    /// @param allowedToken_ The allowed token for the vault
    /// @return proxy The address of the deployed proxy
    function deployProxy(address owner_, address allowedToken_) external returns (address proxy) {
        if (owner_ == address(0)) revert ZeroOwnerAddress();
        if (allowedToken_ == address(0)) revert ZeroTokenAddress();

        bytes memory initData = abi.encodeCall(ITokenVault.initialize, (owner_, allowedToken_));

        proxy = address(new BeaconProxy(beacon, initData));

        emit ProxyDeployed(proxy, owner_, allowedToken_);
    }

    /// @notice Deploy a new beacon proxy with initialization using CREATE2
    /// @param owner_ The owner of the vault
    /// @param allowedToken_ The allowed token for the vault
    /// @param salt The salt for deterministic deployment
    /// @return proxy The address of the deployed proxy
    function deployProxyDeterministic(address owner_, address allowedToken_, bytes32 salt)
        external
        returns (address proxy)
    {
        if (owner_ == address(0)) revert ZeroOwnerAddress();
        if (allowedToken_ == address(0)) revert ZeroTokenAddress();

        bytes memory initData = abi.encodeCall(ITokenVault.initialize, (owner_, allowedToken_));

        proxy = address(new BeaconProxy{salt: salt}(beacon, initData));

        emit ProxyDeployed(proxy, owner_, allowedToken_);
    }

    /// @notice Compute the address of a proxy deployed with CREATE2
    /// @param owner_ The owner of the vault
    /// @param allowedToken_ The allowed token for the vault
    /// @param salt The salt for deterministic deployment
    /// @return The computed proxy address
    function computeProxyAddress(address owner_, address allowedToken_, bytes32 salt) external view returns (address) {
        bytes memory initData = abi.encodeCall(ITokenVault.initialize, (owner_, allowedToken_));

        bytes memory bytecode = abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(beacon, initData));

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        return address(uint160(uint256(hash)));
    }
}

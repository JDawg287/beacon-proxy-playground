// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseTest} from "./Base.t.sol";
import {ITokenVault} from "../src/interfaces/ITokenVault.sol";
import {TokenVaultV2} from "../src/TokenVaultV2.sol";
import {BeaconProxyFactory} from "../src/BeaconProxyFactory.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @title BeaconProxyTest
/// @notice Tests for proxy deployment and beacon upgrades
contract BeaconProxyTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                        FACTORY DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DeployProxy() public {
        address proxy = _deployProxy(vaultOwner, address(token));

        assertTrue(proxy != address(0));
        assertEq(ITokenVault(proxy).owner(), vaultOwner);
        assertEq(ITokenVault(proxy).allowedToken(), address(token));
    }

    function test_DeployProxy_EmitsEvent() public {
        // Don't check topic1 (proxy address) since we can't predict it
        vm.expectEmit(false, true, true, false);
        emit BeaconProxyFactory.ProxyDeployed(address(0), vaultOwner, address(token));

        factory.deployProxy(vaultOwner, address(token));
    }

    function test_DeployProxy_MultipleProxies() public {
        address proxy1 = _deployProxy(vaultOwner, address(token));
        address proxy2 = _deployProxy(user1, address(token));
        address proxy3 = _deployProxy(user2, address(token));

        assertTrue(proxy1 != proxy2);
        assertTrue(proxy2 != proxy3);
        assertTrue(proxy1 != proxy3);

        assertEq(ITokenVault(proxy1).owner(), vaultOwner);
        assertEq(ITokenVault(proxy2).owner(), user1);
        assertEq(ITokenVault(proxy3).owner(), user2);
    }

    function test_DeployProxy_RevertZeroOwner() public {
        vm.expectRevert(BeaconProxyFactory.ZeroOwnerAddress.selector);
        factory.deployProxy(address(0), address(token));
    }

    function test_DeployProxy_RevertZeroToken() public {
        vm.expectRevert(BeaconProxyFactory.ZeroTokenAddress.selector);
        factory.deployProxy(vaultOwner, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    DETERMINISTIC DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DeployProxyDeterministic() public {
        bytes32 salt = keccak256("test-salt");

        address predictedAddress = factory.computeProxyAddress(vaultOwner, address(token), salt);
        address proxy = _deployProxyDeterministic(vaultOwner, address(token), salt);

        assertEq(proxy, predictedAddress);
    }

    function test_DeployProxyDeterministic_DifferentSalts() public {
        bytes32 salt1 = keccak256("salt-1");
        bytes32 salt2 = keccak256("salt-2");

        address proxy1 = _deployProxyDeterministic(vaultOwner, address(token), salt1);
        address proxy2 = _deployProxyDeterministic(vaultOwner, address(token), salt2);

        assertTrue(proxy1 != proxy2);
    }

    function test_ComputeProxyAddress() public view {
        bytes32 salt = keccak256("test-salt");

        address computed = factory.computeProxyAddress(vaultOwner, address(token), salt);

        assertTrue(computed != address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialize_OnlyOnce() public {
        address proxy = _deployProxy(vaultOwner, address(token));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        ITokenVault(proxy).initialize(user1, address(token));
    }

    function test_Initialize_SetsCorrectValues() public {
        address proxy = _deployProxy(vaultOwner, address(token));

        assertEq(ITokenVault(proxy).owner(), vaultOwner);
        assertEq(ITokenVault(proxy).allowedToken(), address(token));
        assertEq(ITokenVault(proxy).balanceOf(vaultOwner), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Upgrade_BeaconOwnerOnly() public {
        vm.prank(user1);
        vm.expectRevert();
        beacon.upgradeTo(address(implementationV2));
    }

    function test_Upgrade_Success() public {
        address proxy = _deployProxy(vaultOwner, address(token));

        // Deposit before upgrade
        _depositAs(proxy, user1, 100 ether);

        // Upgrade
        _upgradeToV2();

        // Verify beacon points to V2
        assertEq(beacon.implementation(), address(implementationV2));
    }

    function test_Upgrade_StoragePersistence() public {
        address proxy = _deployProxy(vaultOwner, address(token));

        // Deposit before upgrade
        uint256 depositAmount = 100 ether;
        _depositAs(proxy, user1, depositAmount);

        // Upgrade
        _upgradeToV2();

        // Verify storage persists
        assertEq(ITokenVault(proxy).balanceOf(user1), depositAmount);
        assertEq(ITokenVault(proxy).owner(), vaultOwner);
        assertEq(ITokenVault(proxy).allowedToken(), address(token));
    }

    function test_Upgrade_V2FunctionsAvailable() public {
        address proxy = _deployProxy(vaultOwner, address(token));

        // Deposit before upgrade
        _depositAs(proxy, user1, 100 ether);

        // Upgrade
        _upgradeToV2();

        // Use V2 function
        TokenVaultV2 vaultV2 = TokenVaultV2(proxy);

        vm.prank(user1);
        vaultV2.withdrawTo(50 ether, user2);

        assertEq(ITokenVault(proxy).balanceOf(user1), 50 ether);
        assertEq(token.balanceOf(user2), INITIAL_BALANCE + 50 ether);
    }

    function test_Upgrade_Version() public {
        address proxy = _deployProxy(vaultOwner, address(token));

        // Before upgrade - V1 doesn't have version()
        // After upgrade - V2 has version()
        _upgradeToV2();

        TokenVaultV2 vaultV2 = TokenVaultV2(proxy);
        assertEq(vaultV2.version(), "2.0.0");
    }

    function test_Upgrade_MultipleProxiesUpdated() public {
        // Deploy multiple proxies
        address proxy1 = _deployProxy(vaultOwner, address(token));
        address proxy2 = _deployProxy(user1, address(token));

        // Deposit to both
        _depositAs(proxy1, user1, 100 ether);
        _depositAs(proxy2, user2, 200 ether);

        // Single beacon upgrade updates all proxies
        _upgradeToV2();

        // Both proxies now have V2 functionality
        TokenVaultV2 vault1 = TokenVaultV2(proxy1);
        TokenVaultV2 vault2 = TokenVaultV2(proxy2);

        assertEq(vault1.version(), "2.0.0");
        assertEq(vault2.version(), "2.0.0");

        // Storage persists in both
        assertEq(ITokenVault(proxy1).balanceOf(user1), 100 ether);
        assertEq(ITokenVault(proxy2).balanceOf(user2), 200 ether);
    }

    function test_Upgrade_V2WithdrawTo() public {
        address proxy = _deployProxy(vaultOwner, address(token));

        _depositAs(proxy, user1, 100 ether);
        _upgradeToV2();

        TokenVaultV2 vaultV2 = TokenVaultV2(proxy);

        // Withdraw to self
        vm.prank(user1);
        vaultV2.withdrawTo(30 ether, user1);

        assertEq(ITokenVault(proxy).balanceOf(user1), 70 ether);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - 100 ether + 30 ether);

        // Withdraw to another address
        vm.prank(user1);
        vaultV2.withdrawTo(20 ether, user2);

        assertEq(ITokenVault(proxy).balanceOf(user1), 50 ether);
        assertEq(token.balanceOf(user2), INITIAL_BALANCE + 20 ether);
    }

    function test_Upgrade_V2WithdrawTo_RevertZeroAddress() public {
        address proxy = _deployProxy(vaultOwner, address(token));

        _depositAs(proxy, user1, 100 ether);
        _upgradeToV2();

        TokenVaultV2 vaultV2 = TokenVaultV2(proxy);

        vm.prank(user1);
        vm.expectRevert(TokenVaultV2.ZeroAddress.selector);
        vaultV2.withdrawTo(50 ether, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        FACTORY IMMUTABILITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Factory_BeaconImmutable() public view {
        assertEq(factory.beacon(), address(beacon));
    }

    /*//////////////////////////////////////////////////////////////
                            BEACON TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Beacon_Implementation() public view {
        assertEq(beacon.implementation(), address(implementationV1));
    }

    function test_Beacon_Owner() public view {
        assertEq(beacon.owner(), beaconOwner);
    }
}

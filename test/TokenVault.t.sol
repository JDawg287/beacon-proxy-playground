// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseTest} from "./Base.t.sol";
import {ITokenVault} from "../src/interfaces/ITokenVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title TokenVaultTest
/// @notice Unit tests for TokenVault implementation logic
contract TokenVaultTest is BaseTest {
    address public proxy;

    function setUp() public override {
        super.setUp();
        proxy = _deployProxy(vaultOwner, address(token));
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deposit() public {
        uint256 depositAmount = 100 ether;

        _depositAs(proxy, user1, depositAmount);

        assertEq(ITokenVault(proxy).balanceOf(user1), depositAmount);
        assertEq(token.balanceOf(proxy), depositAmount);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - depositAmount);
    }

    function test_Deposit_MultipleUsers() public {
        uint256 amount1 = 100 ether;
        uint256 amount2 = 200 ether;

        _depositAs(proxy, user1, amount1);
        _depositAs(proxy, user2, amount2);

        assertEq(ITokenVault(proxy).balanceOf(user1), amount1);
        assertEq(ITokenVault(proxy).balanceOf(user2), amount2);
        assertEq(token.balanceOf(proxy), amount1 + amount2);
    }

    function test_Deposit_EmitsEvent() public {
        uint256 depositAmount = 100 ether;

        vm.startPrank(user1);
        token.approve(proxy, depositAmount);

        vm.expectEmit(true, false, false, true);
        emit ITokenVault.Deposited(user1, depositAmount);

        ITokenVault(proxy).deposit(depositAmount);
        vm.stopPrank();
    }

    function test_Deposit_RevertZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(ITokenVault.ZeroAmount.selector);
        ITokenVault(proxy).deposit(0);
    }

    function testFuzz_Deposit(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_BALANCE);

        _depositAs(proxy, user1, amount);

        assertEq(ITokenVault(proxy).balanceOf(user1), amount);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Withdraw() public {
        uint256 depositAmount = 100 ether;
        uint256 withdrawAmount = 50 ether;

        _depositAs(proxy, user1, depositAmount);
        _withdrawAs(proxy, user1, withdrawAmount);

        assertEq(ITokenVault(proxy).balanceOf(user1), depositAmount - withdrawAmount);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - depositAmount + withdrawAmount);
    }

    function test_Withdraw_Full() public {
        uint256 depositAmount = 100 ether;

        _depositAs(proxy, user1, depositAmount);
        _withdrawAs(proxy, user1, depositAmount);

        assertEq(ITokenVault(proxy).balanceOf(user1), 0);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_Withdraw_EmitsEvent() public {
        uint256 depositAmount = 100 ether;
        uint256 withdrawAmount = 50 ether;

        _depositAs(proxy, user1, depositAmount);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit ITokenVault.Withdrawn(user1, withdrawAmount);

        ITokenVault(proxy).withdraw(withdrawAmount);
    }

    function test_Withdraw_RevertZeroAmount() public {
        _depositAs(proxy, user1, 100 ether);

        vm.prank(user1);
        vm.expectRevert(ITokenVault.ZeroAmount.selector);
        ITokenVault(proxy).withdraw(0);
    }

    function test_Withdraw_RevertInsufficientBalance() public {
        uint256 depositAmount = 100 ether;
        _depositAs(proxy, user1, depositAmount);

        vm.prank(user1);
        vm.expectRevert(ITokenVault.InsufficientBalance.selector);
        ITokenVault(proxy).withdraw(depositAmount + 1);
    }

    function test_Withdraw_RevertNoBalance() public {
        vm.prank(user1);
        vm.expectRevert(ITokenVault.InsufficientBalance.selector);
        ITokenVault(proxy).withdraw(1);
    }

    function testFuzz_Withdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        depositAmount = bound(depositAmount, 1, INITIAL_BALANCE);
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        _depositAs(proxy, user1, depositAmount);
        _withdrawAs(proxy, user1, withdrawAmount);

        assertEq(ITokenVault(proxy).balanceOf(user1), depositAmount - withdrawAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BalanceOf_Initial() public view {
        assertEq(ITokenVault(proxy).balanceOf(user1), 0);
    }

    function test_Owner() public view {
        assertEq(ITokenVault(proxy).owner(), vaultOwner);
    }

    function test_AllowedToken() public view {
        assertEq(ITokenVault(proxy).allowedToken(), address(token));
    }

    /*//////////////////////////////////////////////////////////////
                        REENTRANCY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deposit_ReentrancyProtection() public {
        ReentrantToken maliciousToken = new ReentrantToken(proxy);
        address maliciousProxy = _deployProxy(vaultOwner, address(maliciousToken));

        maliciousToken.mint(user1, INITIAL_BALANCE);

        vm.startPrank(user1);
        maliciousToken.approve(maliciousProxy, type(uint256).max);

        // The malicious token will try to re-enter on transfer
        // This should revert with ReentrancyGuard
        vm.expectRevert(ITokenVault.ReentrancyGuard.selector);
        ITokenVault(maliciousProxy).deposit(100 ether);
        vm.stopPrank();
    }

    function test_Withdraw_ReentrancyProtection() public {
        ReentrantToken maliciousToken = new ReentrantToken(proxy);
        address maliciousProxy = _deployProxy(vaultOwner, address(maliciousToken));

        // First deposit normally (disable attack)
        maliciousToken.mint(user1, INITIAL_BALANCE);
        maliciousToken.setAttackEnabled(false);

        vm.startPrank(user1);
        maliciousToken.approve(maliciousProxy, type(uint256).max);
        ITokenVault(maliciousProxy).deposit(100 ether);
        vm.stopPrank();

        // Now enable attack and try to withdraw
        maliciousToken.setAttackEnabled(true);
        maliciousToken.setAttackOnTransfer(true);

        vm.prank(user1);
        vm.expectRevert(ITokenVault.ReentrancyGuard.selector);
        ITokenVault(maliciousProxy).withdraw(50 ether);
    }
}

/// @notice Malicious token that attempts re-entrancy
contract ReentrantToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    address public target;
    bool public attackEnabled = true;
    bool public attackOnTransfer = false;

    constructor(address target_) {
        target = target_;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setAttackEnabled(bool enabled) external {
        attackEnabled = enabled;
    }

    function setAttackOnTransfer(bool enabled) external {
        attackOnTransfer = enabled;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        // Attempt re-entrancy on deposit
        if (attackEnabled && !attackOnTransfer) {
            ITokenVault(msg.sender).deposit(1);
        }

        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        // Attempt re-entrancy on withdraw
        if (attackEnabled && attackOnTransfer) {
            ITokenVault(msg.sender).withdraw(1);
        }

        return true;
    }
}

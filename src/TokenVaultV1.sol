// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITokenVault} from "./interfaces/ITokenVault.sol";

/// @title TokenVaultV1
/// @notice A token vault implementation using EIP-7201 namespaced storage
/// @dev Designed to work with beacon proxies
contract TokenVaultV1 is ITokenVault, Initializable {
    /// @custom:storage-location erc7201:beacon-proxy-playground.storage.TokenVault
    struct TokenVaultStorage {
        address owner;
        address allowedToken;
        mapping(address user => uint256 balance) balances;
        uint256 lock;
    }

    // keccak256(abi.encode(uint256(keccak256("beacon-proxy-playground.storage.TokenVault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant STORAGE_SLOT = 0x0e7e0e1b5e5a4f6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b00;

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /// @dev Returns the storage pointer for EIP-7201 namespaced storage
    function _getStorage() private pure returns (TokenVaultStorage storage $) {
        assembly {
            $.slot := STORAGE_SLOT
        }
    }

    /// @dev Prevents re-entrant calls
    modifier nonReentrant() {
        TokenVaultStorage storage $ = _getStorage();
        if ($.lock == ENTERED) revert ReentrancyGuard();
        $.lock = ENTERED;
        _;
        $.lock = NOT_ENTERED;
    }

    /// @inheritdoc ITokenVault
    function initialize(address owner_, address allowedToken_) external initializer {
        TokenVaultStorage storage $ = _getStorage();
        $.owner = owner_;
        $.allowedToken = allowedToken_;
        $.lock = NOT_ENTERED;
    }

    /// @inheritdoc ITokenVault
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        TokenVaultStorage storage $ = _getStorage();

        $.balances[msg.sender] += amount;

        bool success = IERC20($.allowedToken).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit Deposited(msg.sender, amount);
    }

    /// @inheritdoc ITokenVault
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        TokenVaultStorage storage $ = _getStorage();

        uint256 userBalance = $.balances[msg.sender];
        if (userBalance < amount) revert InsufficientBalance();

        $.balances[msg.sender] = userBalance - amount;

        bool success = IERC20($.allowedToken).transfer(msg.sender, amount);
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    /// @inheritdoc ITokenVault
    function balanceOf(address user) external view returns (uint256) {
        return _getStorage().balances[user];
    }

    /// @inheritdoc ITokenVault
    function owner() external view returns (address) {
        return _getStorage().owner;
    }

    /// @inheritdoc ITokenVault
    function allowedToken() external view returns (address) {
        return _getStorage().allowedToken;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITokenVault} from "./interfaces/ITokenVault.sol";

/// @title TokenVaultV2
/// @notice An upgraded token vault with withdrawTo functionality
/// @dev Same storage layout as V1, adds withdrawTo function
contract TokenVaultV2 is ITokenVault, Initializable {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:beacon-proxy-playground.storage.TokenVault
    struct TokenVaultStorage {
        address owner;
        address allowedToken;
        mapping(address user => uint256 balance) balances;
        uint256 lock;
    }

    // keccak256(abi.encode(uint256(keccak256("beacon-proxy-playground.storage.TokenVault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant STORAGE_SLOT = 0x959368ecea02bc7b87790d5b8379d8a43433d71d5f964d6cfa14aa7c6deca500;

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Emitted when a user withdraws tokens to a different recipient
    /// @param user The address of the withdrawer
    /// @param recipient The address receiving the tokens
    /// @param amount The amount of tokens withdrawn
    event WithdrawnTo(address indexed user, address indexed recipient, uint256 amount);

    /// @notice Thrown when recipient address is zero
    error ZeroAddress();

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

        // CEI: Interaction first for deposits (transfer tokens in)
        IERC20($.allowedToken).safeTransferFrom(msg.sender, address(this), amount);

        // CEI: Effect after successful transfer
        $.balances[msg.sender] += amount;

        emit Deposited(msg.sender, amount);
    }

    /// @inheritdoc ITokenVault
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        TokenVaultStorage storage $ = _getStorage();

        uint256 userBalance = $.balances[msg.sender];
        if (userBalance < amount) revert InsufficientBalance();

        // CEI: Effect before interaction for withdrawals
        $.balances[msg.sender] = userBalance - amount;

        // CEI: Interaction last
        IERC20($.allowedToken).safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Withdraw tokens to a different recipient (V2 feature)
    /// @param amount The amount of tokens to withdraw
    /// @param recipient The address to receive the tokens
    function withdrawTo(uint256 amount, address recipient) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        TokenVaultStorage storage $ = _getStorage();

        uint256 userBalance = $.balances[msg.sender];
        if (userBalance < amount) revert InsufficientBalance();

        // CEI: Effect before interaction for withdrawals
        $.balances[msg.sender] = userBalance - amount;

        // CEI: Interaction last
        IERC20($.allowedToken).safeTransfer(recipient, amount);

        emit WithdrawnTo(msg.sender, recipient, amount);
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

    /// @notice Returns the version of the implementation
    /// @return The version string
    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ITokenVault
/// @notice Interface for TokenVault implementations
interface ITokenVault {
    /// @notice Emitted when a user deposits tokens
    /// @param user The address of the depositor
    /// @param amount The amount of tokens deposited
    event Deposited(address indexed user, uint256 amount);

    /// @notice Emitted when a user withdraws tokens
    /// @param user The address of the withdrawer
    /// @param amount The amount of tokens withdrawn
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice Thrown when caller is not the owner
    error NotOwner();

    /// @notice Thrown when attempting to deposit/withdraw zero amount
    error ZeroAmount();

    /// @notice Thrown when user has insufficient balance
    error InsufficientBalance();

    /// @notice Thrown when re-entrancy is detected
    error ReentrancyGuard();

    /// @notice Thrown when token transfer fails
    error TransferFailed();

    /// @notice Initialize the vault with owner and allowed token
    /// @param owner_ The owner address
    /// @param allowedToken_ The ERC20 token address that this vault accepts
    function initialize(address owner_, address allowedToken_) external;

    /// @notice Deposit tokens into the vault
    /// @param amount The amount of tokens to deposit
    function deposit(uint256 amount) external;

    /// @notice Withdraw tokens from the vault
    /// @param amount The amount of tokens to withdraw
    function withdraw(uint256 amount) external;

    /// @notice Get the balance of a user
    /// @param user The user address
    /// @return The user's balance
    function balanceOf(address user) external view returns (uint256);

    /// @notice Get the owner of the vault
    /// @return The owner address
    function owner() external view returns (address);

    /// @notice Get the allowed token address
    /// @return The allowed token address
    function allowedToken() external view returns (address);
}

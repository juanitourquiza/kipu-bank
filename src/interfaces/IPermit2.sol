// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title IPermit2
 * @notice Interface for Uniswap Permit2 contract
 * @dev Handles token approvals and permits
 */
interface IPermit2 {
    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    /**
     * @notice Approves a token for spending
     * @param token Token address to approve
     * @param spender Address to approve
     * @param amount Amount to approve
     */
    function approve(
        address token,
        address spender,
        uint160 amount,
        uint48 expiration
    ) external;

    /**
     * @notice Transfers tokens using a permit signature
     */
    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    /**
     * @notice Transfers tokens from owner to recipient
     */
    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external;
}

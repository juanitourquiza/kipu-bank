// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title IUniversalRouter
 * @notice Interface for Uniswap V4 UniversalRouter
 * @dev Simplified interface focusing on swap functionality
 */
interface IUniversalRouter {
    /**
     * @notice Executes encoded commands along with provided inputs
     * @param commands Encoded commands to execute
     * @param inputs Encoded inputs for each command
     * @param deadline Deadline for the transaction
     */
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external payable;

    /**
     * @notice Executes encoded commands along with provided inputs with permit
     * @param commands Encoded commands to execute
     * @param inputs Encoded inputs for each command
     */
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs
    ) external payable;
}

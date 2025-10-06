// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title UniswapV4Types
 * @notice Core types and structs for Uniswap V4 integration
 */

/// @notice Currency type - address(0) for native ETH, otherwise ERC20 address
type Currency is address;

/**
 * @notice Pool key for Uniswap V4 pools
 * @param currency0 First currency in the pool
 * @param currency1 Second currency in the pool
 * @param fee Fee tier of the pool
 * @param tickSpacing Tick spacing of the pool
 * @param hooks Address of the hooks contract
 */
struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

/**
 * @notice Swap parameters
 * @param zeroForOne Direction of swap (token0 -> token1 or vice versa)
 * @param amountSpecified Amount to swap (negative for exact input)
 * @param sqrtPriceLimitX96 Price limit for the swap
 */
struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}

/**
 * @title Commands
 * @notice Command types for UniversalRouter
 */
library Commands {
    // Command types
    uint256 constant V4_SWAP = 0x00;
    uint256 constant V3_SWAP_EXACT_IN = 0x00;
    uint256 constant V3_SWAP_EXACT_OUT = 0x01;
    uint256 constant PERMIT2_TRANSFER_FROM = 0x02;
    uint256 constant PERMIT2_PERMIT_BATCH = 0x03;
    uint256 constant SWEEP = 0x04;
    uint256 constant TRANSFER = 0x05;
    uint256 constant PAY_PORTION = 0x06;
    
    // V4 specific
    uint256 constant V4_SWAP_EXACT_IN = 0x10;
    uint256 constant V4_SWAP_EXACT_OUT = 0x11;
}

/**
 * @title Actions
 * @notice Action types for V4 operations
 */
library Actions {
    uint256 constant SWAP_EXACT_IN_SINGLE = 0x00;
    uint256 constant SWAP_EXACT_IN = 0x01;
    uint256 constant SWAP_EXACT_OUT_SINGLE = 0x02;
    uint256 constant SWAP_EXACT_OUT = 0x03;
}

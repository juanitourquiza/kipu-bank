// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DeployKipuBankV3
 * @notice Script para desplegar KipuBankV3 en Sepolia
 * @dev Configura USDC, UniversalRouter y Permit2
 */
contract DeployKipuBankV3 is Script {
    // Parámetros por defecto para Sepolia
    uint256 public constant DEFAULT_BANK_CAP_USDC = 1_000_000_000; // 1,000 USDC (6 decimales)
    uint256 public constant DEFAULT_WITHDRAWAL_LIMIT_USDC = 100_000_000; // 100 USDC
    
    // Addresses de Sepolia
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant SEPOLIA_UNIVERSAL_ROUTER = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
    address public constant SEPOLIA_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    
    // Chainlink Price Feeds en Sepolia
    address public constant SEPOLIA_ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant SEPOLIA_USDC_USD_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;

    function run() external returns (KipuBankV3) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying KipuBankV3 ===");
        console.log("Deployer:", deployer);
        console.log("Bank Cap USDC:", DEFAULT_BANK_CAP_USDC);
        console.log("Withdrawal Limit USDC:", DEFAULT_WITHDRAWAL_LIMIT_USDC);
        console.log("");
        console.log("USDC Address:", SEPOLIA_USDC);
        console.log("UniversalRouter:", SEPOLIA_UNIVERSAL_ROUTER);
        console.log("Permit2:", SEPOLIA_PERMIT2);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy el contrato
        KipuBankV3 kipuBank = new KipuBankV3(
            DEFAULT_BANK_CAP_USDC,
            DEFAULT_WITHDRAWAL_LIMIT_USDC,
            SEPOLIA_USDC,
            SEPOLIA_UNIVERSAL_ROUTER,
            SEPOLIA_PERMIT2,
            deployer
        );

        console.log("");
        console.log("KipuBankV3 deployed at:", address(kipuBank));

        // Configurar soporte para ETH
        kipuBank.addETHSupport(SEPOLIA_ETH_USD_FEED);
        console.log("ETH support added");

        // Configurar soporte para USDC
        kipuBank.addSupportedToken(
            SEPOLIA_USDC,
            SEPOLIA_USDC_USD_FEED,
            6,
            true // isUSDC
        );
        console.log("USDC support added");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("Contract:", address(kipuBank));
        console.log("Owner:", deployer);
        console.log("Bank Cap USDC:", kipuBank.i_bankCapUSDC());
        console.log("Withdrawal Limit USDC:", kipuBank.i_withdrawalLimitUSDC());
        console.log("USDC Address:", kipuBank.i_usdc());
        console.log("ETH Supported:", kipuBank.isTokenSupported(address(0)));
        console.log("USDC Supported:", kipuBank.isTokenSupported(SEPOLIA_USDC));

        return kipuBank;
    }
}

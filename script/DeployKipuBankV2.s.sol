// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {KipuBankV2} from "../src/KipuBankV2.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DeployKipuBankV2
 * @notice Script para desplegar KipuBankV2 en cualquier red
 * @dev Uso: forge script script/DeployKipuBankV2.s.sol:DeployKipuBankV2 --rpc-url <RPC> --broadcast --verify
 */
contract DeployKipuBankV2 is Script {
    // Parámetros por defecto para Sepolia
    uint256 public constant DEFAULT_BANK_CAP_USD = 1_000_000_000; // 1,000 USD (6 decimales)
    uint256 public constant DEFAULT_WITHDRAWAL_LIMIT_USD = 100_000_000; // 100 USD (6 decimales)
    
    // Chainlink Price Feeds en Sepolia
    address public constant SEPOLIA_ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant SEPOLIA_BTC_USD_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address public constant SEPOLIA_USDC_USD_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;

    function run() external returns (KipuBankV2) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying KipuBankV2 with account:", deployer);
        console.log("Bank Cap USD:", DEFAULT_BANK_CAP_USD);
        console.log("Withdrawal Limit USD:", DEFAULT_WITHDRAWAL_LIMIT_USD);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy el contrato
        KipuBankV2 kipuBank = new KipuBankV2(
            DEFAULT_BANK_CAP_USD,
            DEFAULT_WITHDRAWAL_LIMIT_USD,
            deployer
        );

        console.log("KipuBankV2 deployed at:", address(kipuBank));

        // Configurar soporte para ETH
        kipuBank.addETHSupport(SEPOLIA_ETH_USD_FEED);
        console.log("ETH support added with price feed:", SEPOLIA_ETH_USD_FEED);

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Contract:", address(kipuBank));
        console.log("Owner:", deployer);
        console.log("Bank Cap USD:", kipuBank.i_bankCapUSD());
        console.log("Withdrawal Limit USD:", kipuBank.i_withdrawalLimitUSD());
        console.log("ETH Supported:", kipuBank.isTokenSupported(address(0)));

        return kipuBank;
    }
}

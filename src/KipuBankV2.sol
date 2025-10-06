// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title KipuBankV2
 * @author Juan Urquiza
 * @notice Un banco descentralizado avanzado que soporta múltiples tokens (ETH y ERC-20)
 * @dev Implementa control de acceso, oráculos Chainlink, contabilidad multi-token y conversión de decimales
 * 
 * Mejoras principales sobre V1:
 * - Soporte multi-token (ETH usando address(0) y tokens ERC-20)
 * - Control de acceso basado en roles con OpenZeppelin Ownable
 * - Integración con Chainlink Price Feeds para límites en USD
 * - Contabilidad interna normalizada a 6 decimales (USDC standard)
 * - Errores personalizados para mejor debugging
 * - Eventos detallados para observabilidad
 * - Optimizaciones de gas y mejores prácticas de seguridad
 */
contract KipuBankV2 is Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Estructura para almacenar información de un token soportado
     * @param isSupported Si el token está activo para depósitos/retiros
     * @param decimals Número de decimales del token
     * @param priceFeed Dirección del Chainlink Price Feed para el token
     */
    struct TokenInfo {
        bool isSupported;
        uint8 decimals;
        address priceFeed;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decimales utilizados para la contabilidad interna (USDC standard)
    uint8 public constant ACCOUNTING_DECIMALS = 6;

    /// @notice Dirección que representa ETH en el sistema
    address public constant ETH_ADDRESS = address(0);

    /// @notice Número de decimales de ETH
    uint8 private constant ETH_DECIMALS = 18;

    /// @notice Timeout para verificar que el precio del oráculo sea reciente (1 hora)
    uint256 private constant PRICE_FEED_TIMEOUT = 3600;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Límite máximo del banco en USD (con ACCOUNTING_DECIMALS)
    uint256 public immutable i_bankCapUSD;

    /// @notice Límite máximo de retiro por transacción en USD (con ACCOUNTING_DECIMALS)
    uint256 public immutable i_withdrawalLimitUSD;

    /// @notice Información de tokens soportados (token address => TokenInfo)
    mapping(address => TokenInfo) private s_tokenInfo;

    /// @notice Contabilidad interna: usuario => token => balance (normalizado a ACCOUNTING_DECIMALS)
    mapping(address => mapping(address => uint256)) private s_userBalances;

    /// @notice Balance total del banco por token (normalizado a ACCOUNTING_DECIMALS)
    mapping(address => uint256) private s_totalBalancesByToken;

    /// @notice Contador de depósitos por usuario
    mapping(address => uint256) public s_depositCountByUser;

    /// @notice Contador de retiros por usuario
    mapping(address => uint256) public s_withdrawalCountByUser;

    /// @notice Total de depósitos en el sistema
    uint256 public s_totalDeposits;

    /// @notice Total de retiros en el sistema
    uint256 public s_totalWithdrawals;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Se emite cuando un usuario deposita tokens
     * @param user Dirección del usuario
     * @param token Dirección del token depositado
     * @param amount Cantidad depositada (en unidades del token)
     * @param amountUSD Valor en USD del depósito (con ACCOUNTING_DECIMALS)
     */
    event Deposit(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 amountUSD
    );

    /**
     * @notice Se emite cuando un usuario retira tokens
     * @param user Dirección del usuario
     * @param token Dirección del token retirado
     * @param amount Cantidad retirada (en unidades del token)
     * @param amountUSD Valor en USD del retiro (con ACCOUNTING_DECIMALS)
     */
    event Withdrawal(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 amountUSD
    );

    /**
     * @notice Se emite cuando se agrega un nuevo token soportado
     * @param token Dirección del token
     * @param priceFeed Dirección del price feed de Chainlink
     * @param decimals Decimales del token
     */
    event TokenAdded(
        address indexed token,
        address indexed priceFeed,
        uint8 decimals
    );

    /**
     * @notice Se emite cuando se remueve un token del sistema
     * @param token Dirección del token removido
     */
    event TokenRemoved(address indexed token);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error cuando se intenta depositar/retirar un monto de 0
    error KipuBankV2__AmountMustBeGreaterThanZero();

    /// @notice Error cuando el token no está soportado
    error KipuBankV2__TokenNotSupported();

    /// @notice Error cuando el depósito excedería el límite del banco en USD
    error KipuBankV2__BankCapExceeded();

    /// @notice Error cuando el retiro excede el límite por transacción
    error KipuBankV2__WithdrawalLimitExceeded();

    /// @notice Error cuando el usuario no tiene saldo suficiente
    error KipuBankV2__InsufficientBalance();

    /// @notice Error cuando la transferencia de ETH falla
    error KipuBankV2__ETHTransferFailed();

    /// @notice Error cuando el precio del oráculo es inválido o desactualizado
    error KipuBankV2__InvalidPriceData();

    /// @notice Error cuando se intenta agregar un token ya soportado
    error KipuBankV2__TokenAlreadySupported();

    /// @notice Error cuando la dirección del price feed es inválida
    error KipuBankV2__InvalidPriceFeed();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor que inicializa el banco con límites en USD
     * @param _bankCapUSD Límite máximo del banco en USD (con ACCOUNTING_DECIMALS)
     * @param _withdrawalLimitUSD Límite por retiro en USD (con ACCOUNTING_DECIMALS)
     * @param _initialOwner Dirección del propietario inicial del contrato
     */
    constructor(
        uint256 _bankCapUSD,
        uint256 _withdrawalLimitUSD,
        address _initialOwner
    ) Ownable(_initialOwner) {
        i_bankCapUSD = _bankCapUSD;
        i_withdrawalLimitUSD = _withdrawalLimitUSD;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposita ETH en el banco
     * @dev ETH se representa con address(0)
     */
    function depositETH() external payable {
        if (msg.value == 0) revert KipuBankV2__AmountMustBeGreaterThanZero();
        _deposit(ETH_ADDRESS, msg.value);
    }

    /**
     * @notice Deposita tokens ERC-20 en el banco
     * @param token Dirección del token a depositar
     * @param amount Cantidad de tokens a depositar
     */
    function depositToken(address token, uint256 amount) external {
        if (amount == 0) revert KipuBankV2__AmountMustBeGreaterThanZero();
        if (token == ETH_ADDRESS) revert KipuBankV2__TokenNotSupported();
        
        _deposit(token, amount);
        
        // Transferir tokens del usuario al contrato
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Retira ETH del banco
     * @param amount Cantidad de ETH a retirar (en wei)
     */
    function withdrawETH(uint256 amount) external {
        if (amount == 0) revert KipuBankV2__AmountMustBeGreaterThanZero();
        
        _withdraw(ETH_ADDRESS, amount);
        
        // Transferir ETH al usuario
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert KipuBankV2__ETHTransferFailed();
    }

    /**
     * @notice Retira tokens ERC-20 del banco
     * @param token Dirección del token a retirar
     * @param amount Cantidad de tokens a retirar
     */
    function withdrawToken(address token, uint256 amount) external {
        if (amount == 0) revert KipuBankV2__AmountMustBeGreaterThanZero();
        if (token == ETH_ADDRESS) revert KipuBankV2__TokenNotSupported();
        
        _withdraw(token, amount);
        
        // Transferir tokens al usuario
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Agrega un nuevo token soportado (solo owner)
     * @param token Dirección del token
     * @param priceFeed Dirección del Chainlink Price Feed
     * @param decimals Número de decimales del token
     */
    function addSupportedToken(
        address token,
        address priceFeed,
        uint8 decimals
    ) external onlyOwner {
        if (token == ETH_ADDRESS) revert KipuBankV2__TokenNotSupported();
        if (s_tokenInfo[token].isSupported) revert KipuBankV2__TokenAlreadySupported();
        if (priceFeed == address(0)) revert KipuBankV2__InvalidPriceFeed();

        s_tokenInfo[token] = TokenInfo({
            isSupported: true,
            decimals: decimals,
            priceFeed: priceFeed
        });

        emit TokenAdded(token, priceFeed, decimals);
    }

    /**
     * @notice Agrega ETH como token soportado con su price feed (solo owner)
     * @param priceFeed Dirección del Chainlink Price Feed ETH/USD
     */
    function addETHSupport(address priceFeed) external onlyOwner {
        if (priceFeed == address(0)) revert KipuBankV2__InvalidPriceFeed();
        if (s_tokenInfo[ETH_ADDRESS].isSupported) revert KipuBankV2__TokenAlreadySupported();

        s_tokenInfo[ETH_ADDRESS] = TokenInfo({
            isSupported: true,
            decimals: ETH_DECIMALS,
            priceFeed: priceFeed
        });

        emit TokenAdded(ETH_ADDRESS, priceFeed, ETH_DECIMALS);
    }

    /**
     * @notice Remueve un token del sistema (solo owner)
     * @param token Dirección del token a remover
     */
    function removeSupportedToken(address token) external onlyOwner {
        s_tokenInfo[token].isSupported = false;
        emit TokenRemoved(token);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Obtiene el balance de un usuario para un token específico
     * @param user Dirección del usuario
     * @param token Dirección del token
     * @return Balance normalizado a ACCOUNTING_DECIMALS
     */
    function getUserBalance(address user, address token) external view returns (uint256) {
        return s_userBalances[user][token];
    }

    /**
     * @notice Obtiene el balance total del banco en USD
     * @return Balance total en USD (con ACCOUNTING_DECIMALS)
     */
    function getTotalBankBalanceUSD() external view returns (uint256) {
        // Esta función requeriría iterar sobre todos los tokens
        // En producción, se mantendría un balance total actualizado
        return 0; // Placeholder
    }

    /**
     * @notice Verifica si un token está soportado
     * @param token Dirección del token
     * @return True si el token está soportado
     */
    function isTokenSupported(address token) external view returns (bool) {
        return s_tokenInfo[token].isSupported;
    }

    /**
     * @notice Obtiene información de un token
     * @param token Dirección del token
     * @return tokenInfo Estructura con información del token
     */
    function getTokenInfo(address token) external view returns (TokenInfo memory) {
        return s_tokenInfo[token];
    }

    /**
     * @notice Obtiene el precio actual de un token en USD
     * @param token Dirección del token
     * @return Precio en USD (con ACCOUNTING_DECIMALS)
     */
    function getTokenPriceUSD(address token) public view returns (uint256) {
        TokenInfo memory tokenInfo = s_tokenInfo[token];
        if (!tokenInfo.isSupported) revert KipuBankV2__TokenNotSupported();

        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenInfo.priceFeed);
        
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        
        // Verificar que el precio sea válido y reciente
        if (price <= 0 || updatedAt == 0 || block.timestamp - updatedAt > PRICE_FEED_TIMEOUT) {
            revert KipuBankV2__InvalidPriceData();
        }

        // Chainlink price feeds para USD típicamente tienen 8 decimales
        uint8 priceFeedDecimals = priceFeed.decimals();
        
        // Convertir a ACCOUNTING_DECIMALS
        return _convertDecimals(uint256(price), priceFeedDecimals, ACCOUNTING_DECIMALS);
    }

    /**
     * @notice Convierte una cantidad de token a su valor en USD
     * @param token Dirección del token
     * @param amount Cantidad del token (en sus unidades nativas)
     * @return Valor en USD (con ACCOUNTING_DECIMALS)
     */
    function convertToUSD(address token, uint256 amount) public view returns (uint256) {
        if (amount == 0) return 0;
        
        TokenInfo memory tokenInfo = s_tokenInfo[token];
        uint256 priceUSD = getTokenPriceUSD(token);
        
        // Convertir amount a ACCOUNTING_DECIMALS
        uint256 amountNormalized = _convertDecimals(
            amount,
            tokenInfo.decimals,
            ACCOUNTING_DECIMALS
        );
        
        // Multiplicar por el precio (ambos en ACCOUNTING_DECIMALS)
        // Resultado tendrá ACCOUNTING_DECIMALS * 2, así que dividimos por 10^ACCOUNTING_DECIMALS
        return (amountNormalized * priceUSD) / (10 ** ACCOUNTING_DECIMALS);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Función interna para manejar depósitos
     * @param token Dirección del token
     * @param amount Cantidad a depositar
     */
    function _deposit(address token, uint256 amount) private {
        TokenInfo memory tokenInfo = s_tokenInfo[token];
        if (!tokenInfo.isSupported) revert KipuBankV2__TokenNotSupported();

        // Convertir a USD para verificar límites
        uint256 amountUSD = convertToUSD(token, amount);
        
        // Verificar que no se exceda el límite del banco
        uint256 totalBankUSD = _calculateTotalBankUSD();
        if (totalBankUSD + amountUSD > i_bankCapUSD) {
            revert KipuBankV2__BankCapExceeded();
        }

        // Normalizar el monto a ACCOUNTING_DECIMALS para contabilidad interna
        uint256 amountNormalized = _convertDecimals(
            amount,
            tokenInfo.decimals,
            ACCOUNTING_DECIMALS
        );

        // Effects: actualizar estado antes de interacciones externas
        s_userBalances[msg.sender][token] += amountNormalized;
        s_totalBalancesByToken[token] += amountNormalized;
        s_depositCountByUser[msg.sender]++;
        s_totalDeposits++;

        emit Deposit(msg.sender, token, amount, amountUSD);
    }

    /**
     * @notice Función interna para manejar retiros
     * @param token Dirección del token
     * @param amount Cantidad a retirar
     */
    function _withdraw(address token, uint256 amount) private {
        TokenInfo memory tokenInfo = s_tokenInfo[token];
        if (!tokenInfo.isSupported) revert KipuBankV2__TokenNotSupported();

        // Convertir a USD para verificar límites
        uint256 amountUSD = convertToUSD(token, amount);
        
        // Verificar límite de retiro por transacción
        if (amountUSD > i_withdrawalLimitUSD) {
            revert KipuBankV2__WithdrawalLimitExceeded();
        }

        // Normalizar el monto para verificar balance
        uint256 amountNormalized = _convertDecimals(
            amount,
            tokenInfo.decimals,
            ACCOUNTING_DECIMALS
        );

        // Verificar saldo suficiente
        if (s_userBalances[msg.sender][token] < amountNormalized) {
            revert KipuBankV2__InsufficientBalance();
        }

        // Effects: actualizar estado antes de interacciones externas
        s_userBalances[msg.sender][token] -= amountNormalized;
        s_totalBalancesByToken[token] -= amountNormalized;
        s_withdrawalCountByUser[msg.sender]++;
        s_totalWithdrawals++;

        emit Withdrawal(msg.sender, token, amount, amountUSD);
    }

    /**
     * @notice Calcula el valor total del banco en USD
     * @dev En una implementación real, esto se optimizaría manteniendo un total actualizado
     * @return Total en USD (con ACCOUNTING_DECIMALS)
     */
    function _calculateTotalBankUSD() private view returns (uint256) {
        // Por simplicidad, solo calculamos ETH
        // En producción, iteraríamos sobre todos los tokens soportados
        if (!s_tokenInfo[ETH_ADDRESS].isSupported) return 0;
        
        uint256 ethBalance = s_totalBalancesByToken[ETH_ADDRESS];
        if (ethBalance == 0) return 0;
        
        uint256 ethPriceUSD = getTokenPriceUSD(ETH_ADDRESS);
        return (ethBalance * ethPriceUSD) / (10 ** ACCOUNTING_DECIMALS);
    }

    /**
     * @notice Convierte un monto de un número de decimales a otro
     * @param amount Monto a convertir
     * @param fromDecimals Decimales originales
     * @param toDecimals Decimales destino
     * @return Monto convertido
     */
    function _convertDecimals(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) private pure returns (uint256) {
        if (fromDecimals == toDecimals) {
            return amount;
        } else if (fromDecimals > toDecimals) {
            // Reducir decimales
            return amount / (10 ** (fromDecimals - toDecimals));
        } else {
            // Aumentar decimales
            return amount * (10 ** (toDecimals - fromDecimals));
        }
    }

    /**
     * @notice Permite que el contrato reciba ETH directamente
     */
    receive() external payable {
        revert("Use depositETH() function");
    }
}

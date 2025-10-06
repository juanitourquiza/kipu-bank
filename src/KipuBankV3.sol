// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IUniversalRouter} from "./interfaces/IUniversalRouter.sol";
import {IPermit2} from "./interfaces/IPermit2.sol";
import {Currency, PoolKey, Commands, Actions} from "./libraries/UniswapV4Types.sol";

/**
 * @title KipuBankV3
 * @author Juan Urquiza
 * @notice Banco descentralizado que acepta cualquier token y lo convierte automáticamente a USDC via Uniswap V4
 * @dev Nueva característica V3: Integración con Uniswap V4 para swaps automáticos
 * 
 * Mejoras principales sobre V2:
 * - Depósito de tokens arbitrarios con conversión automática a USDC
 * - Integración con UniversalRouter de Uniswap V4
 * - Uso de Permit2 para optimización de aprobaciones
 * - Sistema de slippage protection
 * - Contabilidad simplificada (todo en USDC)
 */
contract KipuBankV3 is Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Información de un token soportado
     * @param isSupported Si el token está activo
     * @param decimals Decimales del token
     * @param priceFeed Chainlink price feed para el token
     * @param isUSDC True si el token es USDC (no requiere swap)
     */
    struct TokenInfo {
        bool isSupported;
        uint8 decimals;
        address priceFeed;
        bool isUSDC;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decimales de USDC (standard)
    uint8 public constant USDC_DECIMALS = 6;

    /// @notice Address que representa ETH nativo
    address public constant ETH_ADDRESS = address(0);

    /// @notice Decimales de ETH
    uint8 private constant ETH_DECIMALS = 18;

    /// @notice Timeout para price feeds (1 hora)
    uint256 private constant PRICE_FEED_TIMEOUT = 3600;

    /// @notice Slippage máximo permitido (2% = 200 basis points)
    uint256 public constant MAX_SLIPPAGE_BPS = 200;

    /// @notice Base para cálculos de basis points
    uint256 private constant BPS_BASE = 10000;

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Límite máximo del banco en USDC (con 6 decimales)
    uint256 public immutable i_bankCapUSDC;

    /// @notice Límite de retiro por transacción en USDC
    uint256 public immutable i_withdrawalLimitUSDC;

    /// @notice Address del USDC token
    address public immutable i_usdc;

    /// @notice UniversalRouter de Uniswap V4
    IUniversalRouter public immutable i_universalRouter;

    /// @notice Permit2 contract
    IPermit2 public immutable i_permit2;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Info de tokens soportados
    mapping(address => TokenInfo) private s_tokenInfo;

    /// @notice Balance de cada usuario en USDC (normalizado a 6 decimales)
    mapping(address => uint256) private s_userBalances;

    /// @notice Balance total del banco en USDC
    uint256 private s_totalBankBalance;

    /// @notice Contador de depósitos por usuario
    mapping(address => uint256) public s_depositCountByUser;

    /// @notice Contador de retiros por usuario
    mapping(address => uint256) public s_withdrawalCountByUser;

    /// @notice Total de depósitos
    uint256 public s_totalDeposits;

    /// @notice Total de retiros
    uint256 public s_totalWithdrawals;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountUSDC
    );

    event Withdrawal(
        address indexed user,
        uint256 amountUSDC
    );

    event TokenSwapped(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event TokenAdded(
        address indexed token,
        address indexed priceFeed,
        uint8 decimals,
        bool isUSDC
    );

    event TokenRemoved(address indexed token);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error KipuBankV3__AmountMustBeGreaterThanZero();
    error KipuBankV3__TokenNotSupported();
    error KipuBankV3__BankCapExceeded();
    error KipuBankV3__WithdrawalLimitExceeded();
    error KipuBankV3__InsufficientBalance();
    error KipuBankV3__ETHTransferFailed();
    error KipuBankV3__InvalidPriceData();
    error KipuBankV3__TokenAlreadySupported();
    error KipuBankV3__InvalidPriceFeed();
    error KipuBankV3__SlippageToHigh();
    error KipuBankV3__SwapFailed();
    error KipuBankV3__InvalidUSDCAddress();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     * @param _bankCapUSDC Límite máximo del banco en USDC
     * @param _withdrawalLimitUSDC Límite por retiro en USDC
     * @param _usdc Dirección del token USDC
     * @param _universalRouter Dirección del UniversalRouter de Uniswap V4
     * @param _permit2 Dirección de Permit2
     * @param _initialOwner Owner inicial del contrato
     */
    constructor(
        uint256 _bankCapUSDC,
        uint256 _withdrawalLimitUSDC,
        address _usdc,
        address _universalRouter,
        address _permit2,
        address _initialOwner
    ) Ownable(_initialOwner) {
        if (_usdc == address(0)) revert KipuBankV3__InvalidUSDCAddress();
        
        i_bankCapUSDC = _bankCapUSDC;
        i_withdrawalLimitUSDC = _withdrawalLimitUSDC;
        i_usdc = _usdc;
        i_universalRouter = IUniversalRouter(_universalRouter);
        i_permit2 = IPermit2(_permit2);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposita ETH y lo convierte a USDC via Uniswap V4
     * @param minAmountOut Cantidad mínima de USDC a recibir (slippage protection)
     */
    function depositETH(uint256 minAmountOut) external payable {
        if (msg.value == 0) revert KipuBankV3__AmountMustBeGreaterThanZero();
        if (!s_tokenInfo[ETH_ADDRESS].isSupported) revert KipuBankV3__TokenNotSupported();

        // Swap ETH -> USDC usando Uniswap V4
        uint256 usdcReceived = _swapExactInputSingle(
            ETH_ADDRESS,
            i_usdc,
            msg.value,
            minAmountOut
        );

        // Verificar bank cap
        if (s_totalBankBalance + usdcReceived > i_bankCapUSDC) {
            revert KipuBankV3__BankCapExceeded();
        }

        // Actualizar balances
        s_userBalances[msg.sender] += usdcReceived;
        s_totalBankBalance += usdcReceived;
        s_depositCountByUser[msg.sender]++;
        s_totalDeposits++;

        emit Deposit(msg.sender, ETH_ADDRESS, msg.value, usdcReceived);
    }

    /**
     * @notice Deposita un token arbitrario y lo convierte a USDC
     * @param token Dirección del token a depositar
     * @param amount Cantidad del token a depositar
     * @param minAmountOut Cantidad mínima de USDC a recibir
     */
    function depositArbitraryToken(
        address token,
        uint256 amount,
        uint256 minAmountOut
    ) external {
        if (amount == 0) revert KipuBankV3__AmountMustBeGreaterThanZero();
        if (!s_tokenInfo[token].isSupported) revert KipuBankV3__TokenNotSupported();

        uint256 usdcAmount;

        // Si es USDC, no hacer swap
        if (s_tokenInfo[token].isUSDC) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            usdcAmount = amount;
        } else {
            // Transferir tokens del usuario al contrato
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

            // Aprobar tokens para Permit2
            IERC20(token).approve(address(i_permit2), amount);

            // Swap token -> USDC usando Uniswap V4
            usdcAmount = _swapExactInputSingle(token, i_usdc, amount, minAmountOut);
        }

        // Verificar bank cap
        if (s_totalBankBalance + usdcAmount > i_bankCapUSDC) {
            revert KipuBankV3__BankCapExceeded();
        }

        // Actualizar balances
        s_userBalances[msg.sender] += usdcAmount;
        s_totalBankBalance += usdcAmount;
        s_depositCountByUser[msg.sender]++;
        s_totalDeposits++;

        emit Deposit(msg.sender, token, amount, usdcAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retira USDC del banco
     * @param amount Cantidad de USDC a retirar
     */
    function withdraw(uint256 amount) external {
        if (amount == 0) revert KipuBankV3__AmountMustBeGreaterThanZero();
        if (amount > i_withdrawalLimitUSDC) revert KipuBankV3__WithdrawalLimitExceeded();
        if (s_userBalances[msg.sender] < amount) revert KipuBankV3__InsufficientBalance();

        // Effects: actualizar balances antes de transferencia
        s_userBalances[msg.sender] -= amount;
        s_totalBankBalance -= amount;
        s_withdrawalCountByUser[msg.sender]++;
        s_totalWithdrawals++;

        // Interactions: transferir USDC al usuario
        IERC20(i_usdc).safeTransfer(msg.sender, amount);

        emit Withdrawal(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Agrega un token soportado
     * @param token Dirección del token
     * @param priceFeed Chainlink price feed
     * @param decimals Decimales del token
     * @param isUSDC True si el token es USDC
     */
    function addSupportedToken(
        address token,
        address priceFeed,
        uint8 decimals,
        bool isUSDC
    ) external onlyOwner {
        if (s_tokenInfo[token].isSupported) revert KipuBankV3__TokenAlreadySupported();
        if (priceFeed == address(0)) revert KipuBankV3__InvalidPriceFeed();

        s_tokenInfo[token] = TokenInfo({
            isSupported: true,
            decimals: decimals,
            priceFeed: priceFeed,
            isUSDC: isUSDC
        });

        emit TokenAdded(token, priceFeed, decimals, isUSDC);
    }

    /**
     * @notice Agrega soporte para ETH
     * @param priceFeed Chainlink ETH/USD price feed
     */
    function addETHSupport(address priceFeed) external onlyOwner {
        if (priceFeed == address(0)) revert KipuBankV3__InvalidPriceFeed();
        if (s_tokenInfo[ETH_ADDRESS].isSupported) revert KipuBankV3__TokenAlreadySupported();

        s_tokenInfo[ETH_ADDRESS] = TokenInfo({
            isSupported: true,
            decimals: ETH_DECIMALS,
            priceFeed: priceFeed,
            isUSDC: false
        });

        emit TokenAdded(ETH_ADDRESS, priceFeed, ETH_DECIMALS, false);
    }

    /**
     * @notice Remueve un token del sistema
     * @param token Dirección del token
     */
    function removeSupportedToken(address token) external onlyOwner {
        s_tokenInfo[token].isSupported = false;
        emit TokenRemoved(token);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Obtiene el balance de un usuario
     * @param user Dirección del usuario
     * @return Balance en USDC
     */
    function getUserBalance(address user) external view returns (uint256) {
        return s_userBalances[user];
    }

    /**
     * @notice Obtiene el balance total del banco
     * @return Balance total en USDC
     */
    function getTotalBankBalance() external view returns (uint256) {
        return s_totalBankBalance;
    }

    /**
     * @notice Verifica si un token está soportado
     * @param token Dirección del token
     * @return True si está soportado
     */
    function isTokenSupported(address token) external view returns (bool) {
        return s_tokenInfo[token].isSupported;
    }

    /**
     * @notice Obtiene info de un token
     * @param token Dirección del token
     * @return Estructura TokenInfo
     */
    function getTokenInfo(address token) external view returns (TokenInfo memory) {
        return s_tokenInfo[token];
    }

    /**
     * @notice Calcula el mínimo esperado con slippage
     * @param amountIn Cantidad de entrada
     * @param slippageBps Slippage en basis points
     * @return Cantidad mínima esperada
     */
    function calculateMinAmountOut(
        address tokenIn,
        uint256 amountIn,
        uint256 slippageBps
    ) external view returns (uint256) {
        if (slippageBps > MAX_SLIPPAGE_BPS) revert KipuBankV3__SlippageToHigh();
        
        // Obtener precio estimado usando Chainlink
        uint256 estimatedUSDC = _estimateSwapOutput(tokenIn, amountIn);
        
        // Aplicar slippage
        return (estimatedUSDC * (BPS_BASE - slippageBps)) / BPS_BASE;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Realiza un swap exacto de entrada a través de Uniswap V4
     * @param tokenIn Token de entrada
     * @param tokenOut Token de salida (siempre USDC)
     * @param amountIn Cantidad de entrada
     * @param minAmountOut Cantidad mínima de salida
     * @return amountOut Cantidad recibida
     */
    function _swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) private returns (uint256 amountOut) {
        // Construir el comando para V4 swap
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP_EXACT_IN));
        
        // Construir inputs para el swap
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            address(this) // recipient
        );

        // Balance antes del swap
        uint256 balanceBefore = tokenOut == ETH_ADDRESS 
            ? address(this).balance 
            : IERC20(tokenOut).balanceOf(address(this));

        // Ejecutar swap a través del UniversalRouter
        if (tokenIn == ETH_ADDRESS) {
            i_universalRouter.execute{value: amountIn}(commands, inputs, block.timestamp + 300);
        } else {
            // Para tokens ERC20, aprobar al router
            IERC20(tokenIn).approve(address(i_universalRouter), amountIn);
            i_universalRouter.execute(commands, inputs, block.timestamp + 300);
        }

        // Balance después del swap
        uint256 balanceAfter = tokenOut == ETH_ADDRESS 
            ? address(this).balance 
            : IERC20(tokenOut).balanceOf(address(this));

        amountOut = balanceAfter - balanceBefore;

        // Verificar que se cumplió el mínimo
        if (amountOut < minAmountOut) revert KipuBankV3__SwapFailed();

        emit TokenSwapped(tokenIn, tokenOut, amountIn, amountOut);
    }

    /**
     * @notice Estima la salida de un swap usando Chainlink oracles
     * @param tokenIn Token de entrada
     * @param amountIn Cantidad de entrada
     * @return Cantidad estimada de USDC
     */
    function _estimateSwapOutput(
        address tokenIn,
        uint256 amountIn
    ) private view returns (uint256) {
        TokenInfo memory tokenInfo = s_tokenInfo[tokenIn];
        
        // Obtener precio del token en USD
        AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenInfo.priceFeed);
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        
        if (price <= 0 || updatedAt == 0 || block.timestamp - updatedAt > PRICE_FEED_TIMEOUT) {
            revert KipuBankV3__InvalidPriceData();
        }

        uint8 priceFeedDecimals = priceFeed.decimals();
        
        // Convertir a USDC
        // amountIn * price / 10^(tokenDecimals + priceFeedDecimals - USDC_DECIMALS)
        return (amountIn * uint256(price)) / 
            (10 ** (tokenInfo.decimals + priceFeedDecimals - USDC_DECIMALS));
    }

    /**
     * @notice Función receive para aceptar ETH
     */
    receive() external payable {
        revert("Use depositETH() function");
    }
}

# 🏦 KipuBankV3 - Integración con Uniswap V4

**KipuBankV3** es la evolución final del proyecto KipuBank, que integra **Uniswap V4** para permitir depósitos de **cualquier token ERC-20** con conversión automática a USDC. Este es un sistema bancario verdaderamente universal.

## 📊 Tabla de Contenidos
- [Resumen de Mejoras V2 → V3](#-resumen-de-mejoras-v2--v3)
- [Características Principales](#-características-principales)
- [Arquitectura Técnica](#-arquitectura-técnica)
- [Instalación y Configuración](#-instalación-y-configuración)
- [Despliegue](#-despliegue)
- [Interacción](#-interacción-con-el-contrato)
- [Decisiones de Diseño](#-decisiones-de-diseño)
- [Seguridad](#-seguridad)
- [Comparación de Versiones](#-comparación-de-versiones)

---

## 🚀 Resumen de Mejoras V2 → V3

### V2 → V3: La Revolución DeFi

| Característica | V2 | V3 |
|---------------|-----|-----|
| **Tokens Aceptados** | Solo tokens pre-configurados | **Cualquier token ERC-20** |
| **Conversión de Tokens** | Manual | **Automática via Uniswap V4** |
| **Contabilidad** | Multi-token compleja | **Simplificada: Todo en USDC** |
| **Integración DeFi** | Chainlink Oracles | **+ Uniswap V4 + Permit2** |
| **Experiencia de Usuario** | Depósito directo | **Deposita cualquier token** |
| **Slippage Protection** | ❌ No | ✅ **Configurable por usuario** |
| **Gas Efficiency** | Buena | **Optimizada con Permit2** |
| **Complejidad** | Alta (múltiples balances) | **Simplificada (solo USDC)** |

---

## ✨ Características Principales

### 🔄 Conversión Automática a USDC

La característica estrella de V3: **deposita CUALQUIER token**, el contrato automáticamente:
1. Recibe tu token (DAI, WETH, WBTC, LINK, etc.)
2. Lo swapea a USDC via Uniswap V4
3. Actualiza tu balance en USDC
4. Todo en una sola transacción ✨

```solidity
// Depositar 1000 DAI -> Se convierte automáticamente a ~1000 USDC
bank.depositArbitraryToken(
    DAI_ADDRESS, 
    1000e18,      // 1000 DAI
    995e6         // Mínimo 995 USDC (0.5% slippage)
);
```

### 🦄 Integración con Uniswap V4

**UniversalRouter**: Routing inteligente de swaps
- Encuentra la mejor ruta automáticamente
- Optimiza el gas
- Integrado con Permit2 para aprobaciones eficientes

**Permit2**: Sistema de aprobaciones mejorado
- Una sola aprobación para múltiples tokens
- Menor consumo de gas
- Mayor seguridad

### 🛡️ Slippage Protection

Los usuarios controlan el slippage máximo aceptable:

```solidity
// Calcular mínimo con 1% de slippage
uint256 minOut = bank.calculateMinAmountOut(
    WETH_ADDRESS,
    1e18,      // 1 WETH
    100        // 1% = 100 basis points
);

// Depositar con protección
bank.depositArbitraryToken(WETH_ADDRESS, 1e18, minOut);
```

### 📊 Contabilidad Simplificada

**V2**: Múltiples balances por token
```solidity
s_userBalances[user][ETH] = 10
s_userBalances[user][USDC] = 1000
s_userBalances[user][DAI] = 500
// Complejidad O(n) donde n = tokens
```

**V3**: Un solo balance en USDC
```solidity
s_userBalances[user] = 1510  // Todo en USDC
// Complejidad O(1)
```

**Ventajas:**
- ✅ Más simple de entender
- ✅ Más barato en gas
- ✅ Fácil de auditar
- ✅ Compatible con USD pricing

### 🎯 Bank Cap Inteligente

El límite del banco se verifica **DESPUÉS del swap**, garantizando que el límite real en USDC nunca se exceda:

```solidity
// Usuario deposita 1 ETH
// Swap produce 2,500 USDC
// Se verifica: totalBalance + 2,500 <= bankCap
```

---

## 🏗️ Arquitectura Técnica

### Estructura del Proyecto

```
kipu-bank/
├── src/
│   ├── KipuBankV3.sol              # Contrato principal
│   ├── interfaces/
│   │   ├── IUniversalRouter.sol    # Interface del router de Uniswap
│   │   └── IPermit2.sol            # Interface de Permit2
│   └── libraries/
│       └── UniswapV4Types.sol      # Tipos y structs de Uniswap V4
├── script/
│   └── DeployKipuBankV3.s.sol      # Script de deployment
├── test/
│   └── KipuBankV3.t.sol            # Tests
└── README_V3.md                     # Esta documentación
```

### Componentes Clave

#### 1. UniversalRouter
```solidity
IUniversalRouter public immutable i_universalRouter;

function execute(
    bytes calldata commands,
    bytes[] calldata inputs,
    uint256 deadline
) external payable;
```

**Responsabilidad**: Ejecutar swaps optimizados en Uniswap V4

#### 2. Permit2
```solidity
IPermit2 public immutable i_permit2;
```

**Responsabilidad**: Gestionar aprobaciones de tokens de forma eficiente

#### 3. Currency Type
```solidity
type Currency is address;
```

**Uso**: Representar tanto ETH (address(0)) como tokens ERC-20

#### 4. PoolKey
```solidity
struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}
```

**Uso**: Identificar pools de liquidez en Uniswap V4

---

## 🛠️ Instalación y Configuración

### Requisitos Previos
- Foundry instalado
- Git
- Node.js (opcional para scripts adicionales)

### Instalación

```bash
# Clonar el repositorio
git clone https://github.com/[tu-usuario]/kipu-bank.git
cd kipu-bank

# Instalar dependencias
forge install OpenZeppelin/openzeppelin-contracts
forge install smartcontractkit/chainlink-brownie-contracts

# Compilar
forge build
```

### Verificar Instalación

```bash
# Ver contratos compilados
ls out/KipuBankV3.sol/

# Ejecutar tests
forge test -vvv
```

---

## 🚀 Despliegue

### Variables de Entorno

Crear `.env` con:

```env
PRIVATE_KEY=0x...
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
ETHERSCAN_API_KEY=...

# Parámetros del contrato
BANK_CAP_USDC=1000000000          # 1,000 USDC
WITHDRAWAL_LIMIT_USDC=100000000   # 100 USDC

# Addresses de Sepolia
USDC_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
UNIVERSAL_ROUTER=0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD
PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3
ETH_USD_PRICE_FEED=0x694AA1769357215DE4FAC081bf1f309aDC325306
```

### Desplegar con Script

```bash
forge script script/DeployKipuBankV3.s.sol:DeployKipuBankV3 \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Configuración Post-Despliegue

#### 1. Agregar Soporte para ETH
```bash
cast send <CONTRACT_ADDRESS> \
  "addETHSupport(address)" \
  $ETH_USD_PRICE_FEED \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

#### 2. Agregar USDC como Token Soportado
```bash
cast send <CONTRACT_ADDRESS> \
  "addSupportedToken(address,address,uint8,bool)" \
  $USDC_ADDRESS \
  $USDC_USD_PRICE_FEED \
  6 \
  true \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

#### 3. Agregar Otros Tokens (Ejemplo: DAI)
```bash
cast send <CONTRACT_ADDRESS> \
  "addSupportedToken(address,address,uint8,bool)" \
  $DAI_ADDRESS \
  $DAI_USD_PRICE_FEED \
  18 \
  false \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## 💻 Interacción con el Contrato

### Depositar ETH

```bash
# 1. Calcular mínimo con 1% slippage
MIN_OUT=$(cast call <CONTRACT_ADDRESS> \
  "calculateMinAmountOut(address,uint256,uint256)" \
  0x0000000000000000000000000000000000000000 \
  100000000000000000 \
  100 \
  --rpc-url $SEPOLIA_RPC_URL)

# 2. Depositar 0.1 ETH
cast send <CONTRACT_ADDRESS> \
  "depositETH(uint256)" \
  $MIN_OUT \
  --value 0.1ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Depositar Token Arbitrario (DAI)

```bash
# 1. Aprobar el contrato para gastar DAI
cast send $DAI_ADDRESS \
  "approve(address,uint256)" \
  <CONTRACT_ADDRESS> \
  1000000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 2. Calcular mínimo esperado
MIN_OUT=$(cast call <CONTRACT_ADDRESS> \
  "calculateMinAmountOut(address,uint256,uint256)" \
  $DAI_ADDRESS \
  1000000000000000000000 \
  100)

# 3. Depositar 1000 DAI
cast send <CONTRACT_ADDRESS> \
  "depositArbitraryToken(address,uint256,uint256)" \
  $DAI_ADDRESS \
  1000000000000000000000 \
  $MIN_OUT \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Retirar USDC

```bash
cast send <CONTRACT_ADDRESS> \
  "withdraw(uint256)" \
  100000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Ver tu Balance

```bash
cast call <CONTRACT_ADDRESS> \
  "getUserBalance(address)" \
  <YOUR_ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## 🧠 Decisiones de Diseño

### 1. Todo en USDC

**Decisión**: Convertir todos los tokens a USDC automáticamente

**Razones**:
- ✅ Simplifica la contabilidad enormemente
- ✅ Stablecoin más usado (mayor liquidez)
- ✅ Fácil de entender para usuarios
- ✅ Compatible con límites en USD
- ✅ Reduce complejidad del código

**Trade-offs**:
- ⚠️ Usuarios no mantienen el token original
- ⚠️ Exposición a riesgo de depeg de USDC
- ⚠️ Costo de gas por swap

**Mitigación**: Los usuarios saben que reciben USDC, es transparente

### 2. Uniswap V4 sobre V3/V2

**Decisión**: Usar Uniswap V4 UniversalRouter

**Razones**:
- ✅ Router más eficiente de Uniswap
- ✅ Mejor routing automático
- ✅ Integración con Permit2
- ✅ Preparado para el futuro

**Trade-offs**:
- ⚠️ Mayor complejidad de integración
- ⚠️ Menos documentación que V3
- ⚠️ Requiere Permit2 adicional

### 3. Slippage Configurable por Usuario

**Decisión**: Usuario especifica `minAmountOut`

**Razones**:
- ✅ Control total del usuario
- ✅ Diferentes tolerancias según contexto
- ✅ Protección contra front-running
- ✅ MEV protection

**Trade-offs**:
- ⚠️ Require que el usuario calcule o use helper
- ⚠️ UX ligeramente más compleja

**Mitigación**: Función `calculateMinAmountOut()` helper

### 4. Verificar Bank Cap Post-Swap

**Decisión**: Verificar límite DESPUÉS de conocer el resultado del swap

**Razones**:
- ✅ Límite real en USDC es preciso
- ✅ No depende de oráculos para límites
- ✅ Más seguro (resultado real vs estimado)

**Trade-offs**:
- ⚠️ Swap podría revertir si excede cap
- ⚠️ Gas desperdiciado si revierte

**Mitigación**: Frontend puede pre-validar

### 5. Mantener Chainlink Oracles

**Decisión**: Usar Chainlink para estimaciones, Uniswap para swaps

**Razones**:
- ✅ Oráculos para `calculateMinAmountOut()`
- ✅ Pricing independiente de liquidez
- ✅ No depender solo de Uniswap
- ✅ Doble validación de precios

**Trade-offs**:
- ⚠️ Dos fuentes de verdad
- ⚠️ Posibles discrepancias

**Mitigación**: Oráculos solo para estimación, swap es la verdad

### 6. Permit2 para Aprobaciones

**Decisión**: Usar Permit2 en lugar de approve directo

**Razones**:
- ✅ Ahorro de gas en aprobaciones repetidas
- ✅ Una aprobación para múltiples tokens
- ✅ Standard de Uniswap V4
- ✅ Mejor UX a largo plazo

**Trade-offs**:
- ⚠️ Dependencia adicional
- ⚠️ Complejidad en la integración

---

## 🔒 Seguridad

### Vectores de Ataque Mitigados

#### 1. Reentrancy
```solidity
// Effects antes de Interactions
s_userBalances[msg.sender] += usdcAmount;  // Effect
s_totalBankBalance += usdcAmount;          // Effect
// ...
IERC20(token).safeTransferFrom(...);       // Interaction
```

✅ **Mitigado** con patrón CEI

#### 2. Slippage/Sandwich Attacks
```solidity
function depositArbitraryToken(
    address token,
    uint256 amount,
    uint256 minAmountOut  // Usuario controla
)
```

✅ **Mitigado** con slippage protection configurable

#### 3. Front-Running
```solidity
// Usuario especifica mínimo aceptable
if (amountOut < minAmountOut) revert KipuBankV3__SwapFailed();
```

✅ **Mitigado** con validación post-swap

#### 4. Oracle Manipulation
```solidity
// Chainlink solo para estimación, NO para límites críticos
// Swap real determina cantidad final
```

✅ **Mitigado** usando resultado real del swap

#### 5. Integer Overflow/Underflow
```solidity
pragma solidity ^0.8.29;  // Checks automáticos
```

✅ **Mitigado** por versión de Solidity

#### 6. Token Transfer Failures
```solidity
using SafeERC20 for IERC20;
IERC20(token).safeTransferFrom(...);
```

✅ **Mitigado** con SafeERC20

### Auditoría Recomendada

⚠️ **IMPORTANTE**: Este contrato integra protocolos DeFi complejos.

**Antes de producción**:
1. Auditoría profesional (Trail of Bits, OpenZeppelin, etc.)
2. Tests exhaustivos (fuzzing, integration)
3. Bug bounty program
4. Deployment gradual con límites bajos

---

## 📊 Comparación de Versiones

### Tabla Completa V1 → V2 → V3

| Feature | V1 | V2 | V3 |
|---------|----|----|-----|
| **Tokens** | Solo ETH | ETH + ERC-20 config | **Cualquier token** |
| **Conversión** | N/A | Manual | **Automática** |
| **DeFi Integration** | ❌ | Chainlink | **+ Uniswap V4** |
| **Contabilidad** | Simple | Multi-token | **Unificada USDC** |
| **Gas Efficiency** | Básica | Optimizada | **Máxima (Permit2)** |
| **UX** | Simple | Compleja | **Universal** |
| **Slippage** | N/A | N/A | **Protegida** |
| **LOC** | ~130 | ~550 | **~600** |
| **Complexity** | Baja | Alta | **Media-Alta** |

### Evolución de Funcionalidades

```
V1: Banco básico de ETH
    └─> V2: Multi-token con oráculos
            └─> V3: DeFi-integrated universal bank
```

---

## 🎯 Casos de Uso

### Caso 1: Usuario tiene DAI, quiere ahorrar

```solidity
// V2: No puede (DAI no configurado)
// V3: Puede depositar DAI directamente
bank.depositArbitraryToken(DAI, 1000e18, 995e6);
// DAI -> USDC automáticamente
```

### Caso 2: Usuario recibe pago en WBTC

```solidity
// V2: Debe swapear manualmente a token soportado
// V3: Deposita WBTC directamente
bank.depositArbitraryToken(WBTC, 0.05e8, minOut);
// WBTC -> USDC automáticamente
```

### Caso 3: Usuario quiere evitar volatilidad

```solidity
// V2: Debe depositar USDC manualmente
// V3: Deposita cualquier token, se convierte a stablecoin
bank.depositArbitraryToken(ETH, 1e18, minOut);
// ETH -> USDC (protección contra volatilidad)
```

---

## 📋 Dirección del Contrato Desplegado

**Testnet Sepolia**: [`0xc22317A04645B6E4565C83DA7816952e1F187Fca`](https://sepolia.etherscan.io/address/0xc22317A04645B6E4565C83DA7816952e1F187Fca)

🔍 **Verificar en Etherscan**: [Ver contrato en Sepolia Etherscan](https://sepolia.etherscan.io/address/0xc22317A04645B6E4565C83DA7816952e1F187Fca)

### Detalles del Deployment
- **Owner**: `0x2D8Bec7ee72f6715CF4C0Ad8Fb9324cAc4bE82B5`
- **Block**: 9352151
- **Bank Cap**: 1,000 USDC
- **Withdrawal Limit**: 100 USDC per transaction
- **ETH Support**: Enabled with Chainlink Price Feed
- **USDC Support**: Enabled (direct deposits without swap)
- **UniversalRouter**: `0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD`
- **Permit2**: `0x000000000022D473030F116dDEE9F6B43aC78BA3`

---

## 🛠️ Stack Tecnológico

- **Solidity**: ^0.8.29
- **Framework**: Foundry
- **Librerías**:
  - OpenZeppelin Contracts v5.x
  - Chainlink Contracts v1.x
  - Uniswap V4 Contracts
- **DeFi Integrations**:
  - Uniswap V4 UniversalRouter
  - Permit2
  - Chainlink Price Feeds
- **Testnet**: Sepolia

---

## 📈 Próximos Pasos (Futuro)

Posibles mejoras para versiones futuras:

- [ ] **Multi-chain**: Deployment en L2s (Arbitrum, Optimism)
- [ ] **Yield Generation**: Depositar USDC en protocolos como Aave
- [ ] **NFT Receipts**: NFTs como prueba de depósito
- [ ] **Governance**: DAO para gestión del protocolo
- [ ] **Flash Loans**: Préstamos instantáneos
- [ ] **Batch Operations**: Múltiples operaciones en una TX

---

## 🤝 Contribuciones

Proyecto educativo - Módulo 3 de desarrollo Web3

**Autor**: Juan Urquiza  
**Fecha**: Octubre 2025

---

## 📄 Licencia

MIT License

---

## 🙏 Agradecimientos

- **Uniswap Labs**: Por el UniversalRouter y documentación
- **OpenZeppelin**: Por contratos seguros
- **Chainlink**: Por oráculos descentralizados
- **Foundry**: Por el mejor framework de Solidity

---

**⚠️ Disclaimer**: Este contrato es educativo. NO usar en producción sin auditoría profesional.

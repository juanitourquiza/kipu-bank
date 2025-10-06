# 🏦 KipuBankV2 - Advanced Multi-Token Banking Smart Contract

**KipuBankV2** es la evolución del contrato KipuBank original, transformado en un sistema bancario descentralizado de nivel producción que soporta múltiples tokens, integración con oráculos de Chainlink, y control de acceso avanzado.

## 📊 Tabla de Contenidos
- [Resumen de Mejoras](#-resumen-de-mejoras)
- [Características Principales](#-características-principales)
- [Arquitectura](#-arquitectura)
- [Instalación y Configuración](#-instalación-y-configuración)
- [Despliegue](#-despliegue)
- [Interacción con el Contrato](#-interacción-con-el-contrato)
- [Decisiones de Diseño](#-decisiones-de-diseño)
- [Seguridad](#-seguridad)
- [Dirección del Contrato Desplegado](#-dirección-del-contrato-desplegado)

---

## 🚀 Resumen de Mejoras

### V1 → V2: Transformación Completa

| Característica | V1 | V2 |
|---------------|-----|-----|
| **Tokens Soportados** | Solo ETH | ETH + múltiples ERC-20 |
| **Control de Acceso** | ❌ Sin roles | ✅ OpenZeppelin Ownable |
| **Límites** | En ETH | En USD (Chainlink Oracles) |
| **Contabilidad** | Simple (ETH) | Multi-token normalizada (6 decimales) |
| **Conversión de Decimales** | ❌ No aplica | ✅ Sistema completo |
| **Errores** | `require` strings | Errores personalizados |
| **Eventos** | Básicos | Detallados con valores USD |
| **Oráculos** | ❌ No usa | ✅ Chainlink Price Feeds |
| **Optimización Gas** | Básica | Avanzada (immutable, constants) |

---

## ✨ Características Principales

### 🔐 Control de Acceso Basado en Roles
- **OpenZeppelin Ownable**: Solo el propietario puede agregar/remover tokens
- **Funciones administrativas protegidas**: `addSupportedToken()`, `removeSupportedToken()`, `addETHSupport()`
- **Transferencia de ownership**: Permite cambiar el administrador del banco

### 💰 Soporte Multi-Token
- **ETH nativo**: Representado con `address(0)` en el sistema
- **Tokens ERC-20**: Soporte para USDC, DAI, USDT, WBTC, y cualquier ERC-20
- **SafeERC20**: Transferencias seguras que manejan tokens no estándar
- **Gestión independiente**: Cada token tiene su propio balance y configuración

### 🌐 Integración con Chainlink Oráculos
- **Price Feeds en tiempo real**: Obtiene precios actualizados de tokens en USD
- **Validación de datos**: Verifica que los precios sean recientes y válidos
- **Timeout configurable**: Rechaza datos con más de 1 hora de antigüedad
- **Límites en USD**: Los límites del banco se calculan en dólares, no en tokens

### 📐 Sistema de Conversión de Decimales
- **Normalización a 6 decimales**: Toda la contabilidad interna usa el estándar USDC
- **Conversión automática**: Maneja tokens con diferentes decimales (ETH: 18, USDC: 6, WBTC: 8)
- **Precisión preservada**: Conversiones matemáticamente correctas sin pérdida de valor

### 📊 Contabilidad Interna Avanzada
```solidity
mapping(address => mapping(address => uint256)) private s_userBalances;
```
- **Mappings anidados**: Usuario → Token → Balance
- **Balance por token**: Cada usuario tiene balances separados por activo
- **Totales por token**: El banco rastrea el total depositado de cada activo
- **Contadores por usuario**: Depósitos y retiros individualizados

### 🎯 Errores Personalizados
```solidity
error KipuBankV2__TokenNotSupported();
error KipuBankV2__BankCapExceeded();
error KipuBankV2__WithdrawalLimitExceeded();
error KipuBankV2__InsufficientBalance();
error KipuBankV2__ETHTransferFailed();
error KipuBankV2__InvalidPriceData();
```
- **Gas eficiente**: Ahorra ~50% de gas vs `require` strings
- **Debugging mejorado**: Errores específicos y descriptivos
- **Mejor UX**: Los frontends pueden mostrar mensajes personalizados

### 📢 Eventos Mejorados
```solidity
event Deposit(address indexed user, address indexed token, uint256 amount, uint256 amountUSD);
event Withdrawal(address indexed user, address indexed token, uint256 amount, uint256 amountUSD);
event TokenAdded(address indexed token, address indexed priceFeed, uint8 decimals);
```
- **Valores en USD**: Cada transacción incluye su valor en dólares
- **Indexados**: Permite filtrar eventos por usuario y token
- **Observabilidad completa**: Facilita auditoría y analytics

---

## 🏗️ Arquitectura

### Estructura del Proyecto
```
kipu-bank/
├── src/
│   └── KipuBankV2.sol          # Contrato principal
├── contracts/
│   └── kipuBank.sol             # Versión V1 original
├── lib/                         # Dependencias (Foundry)
│   ├── openzeppelin-contracts/
│   └── chainlink-brownie-contracts/
├── foundry.toml                 # Configuración de Foundry
├── remappings.txt               # Remappings de imports
├── README_V2.md                 # Esta documentación
└── README.md                    # Documentación V1

```

### Tipos de Datos

#### TokenInfo Struct
```solidity
struct TokenInfo {
    bool isSupported;      // ¿Está activo?
    uint8 decimals;        // Decimales del token
    address priceFeed;     // Chainlink Price Feed
}
```

### Constants
- `ACCOUNTING_DECIMALS = 6`: Standard USDC para contabilidad interna
- `ETH_ADDRESS = address(0)`: Representación de ETH en el sistema
- `ETH_DECIMALS = 18`: Decimales nativos de Ethereum
- `PRICE_FEED_TIMEOUT = 3600`: 1 hora máxima para precios del oráculo

### State Variables
```solidity
// Immutable (establecidas en el constructor)
uint256 public immutable i_bankCapUSD;
uint256 public immutable i_withdrawalLimitUSD;

// Mappings
mapping(address => TokenInfo) private s_tokenInfo;
mapping(address => mapping(address => uint256)) private s_userBalances;
mapping(address => uint256) private s_totalBalancesByToken;
mapping(address => uint256) public s_depositCountByUser;
mapping(address => uint256) public s_withdrawalCountByUser;

// Contadores globales
uint256 public s_totalDeposits;
uint256 public s_totalWithdrawals;
```

---

## 🛠️ Instalación y Configuración

### Requisitos Previos
- **Foundry**: Framework de desarrollo Solidity
- **Git**: Para clonar dependencias
- **Node.js** (opcional): Para scripts adicionales

### Instalación

1. **Clonar el repositorio**
```bash
git clone https://github.com/[tu-usuario]/kipu-bank.git
cd kipu-bank
```

2. **Instalar Foundry** (si no lo tienes)
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

3. **Instalar dependencias**
```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install smartcontractkit/chainlink-brownie-contracts
```

4. **Compilar el contrato**
```bash
forge build
```

5. **Ejecutar tests** (cuando estén disponibles)
```bash
forge test
```

---

## 🚀 Despliegue

### Variables de Entorno
Crea un archivo `.env`:
```env
PRIVATE_KEY=tu_private_key_aqui
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/tu_api_key
ETHERSCAN_API_KEY=tu_etherscan_api_key
```

### Parámetros del Constructor

El contrato requiere 3 parámetros:

1. **`_bankCapUSD`**: Límite máximo del banco en USD (con 6 decimales)
   - Ejemplo: `1000000000` = 1,000 USD

2. **`_withdrawalLimitUSD`**: Límite por retiro en USD (con 6 decimales)
   - Ejemplo: `100000000` = 100 USD

3. **`_initialOwner`**: Dirección del administrador inicial
   - Ejemplo: `0xYourAddress`

### Desplegar en Sepolia

```bash
forge create src/KipuBankV2.sol:KipuBankV2 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args 1000000000 100000000 0xYourAddress \
  --verify
```

### Configuración Post-Despliegue

1. **Agregar soporte para ETH**
```bash
cast send <CONTRACT_ADDRESS> \
  "addETHSupport(address)" \
  0x694AA1769357215DE4FAC081bf1f309aDC325306 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```
*Nota: `0x694AA1769357215DE4FAC081bf1f309aDC325306` es el ETH/USD Price Feed en Sepolia*

2. **Agregar tokens ERC-20** (ejemplo: USDC en Sepolia)
```bash
cast send <CONTRACT_ADDRESS> \
  "addSupportedToken(address,address,uint8)" \
  0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8 \
  0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E \
  6 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Price Feeds de Chainlink en Sepolia

| Par | Dirección |
|-----|-----------|
| ETH/USD | `0x694AA1769357215DE4FAC081bf1f309aDC325306` |
| BTC/USD | `0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43` |
| USDC/USD | `0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E` |

---

## 💻 Interacción con el Contrato

### Funciones Principales

#### 1. Depositar ETH
```solidity
function depositETH() external payable
```

**Uso con Cast:**
```bash
cast send <CONTRACT_ADDRESS> \
  "depositETH()" \
  --value 0.1ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

#### 2. Depositar Tokens ERC-20
```solidity
function depositToken(address token, uint256 amount) external
```

**Pasos:**
1. Aprobar el contrato para gastar tus tokens
```bash
cast send <TOKEN_ADDRESS> \
  "approve(address,uint256)" \
  <CONTRACT_ADDRESS> \
  1000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

2. Depositar
```bash
cast send <CONTRACT_ADDRESS> \
  "depositToken(address,uint256)" \
  <TOKEN_ADDRESS> \
  1000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

#### 3. Retirar ETH
```solidity
function withdrawETH(uint256 amount) external
```

**Uso:**
```bash
cast send <CONTRACT_ADDRESS> \
  "withdrawETH(uint256)" \
  100000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

#### 4. Retirar Tokens
```solidity
function withdrawToken(address token, uint256 amount) external
```

### Funciones de Vista (No consumen gas)

#### Consultar tu balance
```bash
cast call <CONTRACT_ADDRESS> \
  "getUserBalance(address,address)" \
  <YOUR_ADDRESS> \
  <TOKEN_ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL
```

#### Verificar si un token está soportado
```bash
cast call <CONTRACT_ADDRESS> \
  "isTokenSupported(address)" \
  <TOKEN_ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL
```

#### Obtener precio de un token en USD
```bash
cast call <CONTRACT_ADDRESS> \
  "getTokenPriceUSD(address)" \
  <TOKEN_ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL
```

#### Convertir cantidad a USD
```bash
cast call <CONTRACT_ADDRESS> \
  "convertToUSD(address,uint256)" \
  <TOKEN_ADDRESS> \
  <AMOUNT> \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## 🧠 Decisiones de Diseño

### 1. **address(0) para ETH**
**Decisión:** Usar `address(0)` para representar ETH nativo.

**Razones:**
- ✅ Patrón común en la industria (usado por Uniswap, Aave)
- ✅ Permite usar la misma estructura de datos para ETH y ERC-20
- ✅ Simplifica la lógica de contabilidad interna

**Trade-off:** Requiere funciones separadas (`depositETH` vs `depositToken`)

### 2. **Normalización a 6 Decimales (USDC Standard)**
**Decisión:** Toda la contabilidad interna usa 6 decimales.

**Razones:**
- ✅ USDC es el stablecoin más usado (6 decimales)
- ✅ Evita overflow en multiplicaciones (menos gas)
- ✅ Precisión suficiente para valores USD
- ✅ Simplifica cálculos entre diferentes tokens

**Trade-off:** Pérdida mínima de precisión en tokens con >6 decimales

### 3. **Límites en USD (no en tokens)**
**Decisión:** Usar Chainlink para expresar límites en dólares.

**Razones:**
- ✅ Protección contra volatilidad de precios
- ✅ Límites consistentes independientemente del token
- ✅ Más intuitivo para usuarios finales
- ✅ Permite comparar valores de diferentes activos

**Trade-off:** Dependencia de oráculos externos (riesgo de centralización)

### 4. **OpenZeppelin Ownable (no AccessControl)**
**Decisión:** Usar `Ownable` en lugar de `AccessControl`.

**Razones:**
- ✅ Más simple para este caso de uso
- ✅ Menos gas en deployment y operaciones
- ✅ Suficiente para las necesidades actuales
- ✅ Fácil de actualizar a AccessControl en el futuro

**Trade-off:** Solo un rol administrativo (puede escalar con AccessControl)

### 5. **Patrón Checks-Effects-Interactions Estricto**
**Decisión:** Actualizar estado SIEMPRE antes de transferencias.

**Razones:**
- ✅ Protección contra reentrancy
- ✅ Standard de la industria post-DAO hack
- ✅ Recomendado por OpenZeppelin
- ✅ Compatible con futuros upgrades

**Trade-off:** Ninguno significativo

### 6. **SafeERC20 para Tokens**
**Decisión:** Usar `SafeERC20` de OpenZeppelin.

**Razones:**
- ✅ Maneja tokens que no retornan bool (ej: USDT)
- ✅ Previene problemas con transferencias fallidas silenciosas
- ✅ Standard de seguridad
- ✅ Usado por protocolos principales (Aave, Compound)

**Trade-off:** Ligero incremento en gas (~1-2%)

### 7. **Inmutabilidad de Límites**
**Decisión:** Los límites USD son `immutable`.

**Razones:**
- ✅ Ahorro significativo de gas en lecturas
- ✅ Transparencia: los usuarios conocen límites desde inicio
- ✅ Reduce superficie de ataque (no se pueden cambiar)

**Trade-off:** Menos flexibilidad (requiere nuevo deployment para cambiar)

---

## 🔒 Seguridad

### Patrones Implementados

✅ **Checks-Effects-Interactions**: Estado actualizado antes de transferencias  
✅ **Pull over Push**: Los usuarios "jalan" sus fondos (no se envían automáticamente)  
✅ **Fail Early**: Validaciones al inicio de funciones  
✅ **Input Validation**: Todos los parámetros verificados  
✅ **SafeERC20**: Transferencias seguras de tokens  
✅ **Reentrancy Protection**: Por diseño (CEI pattern)  
✅ **Oracle Validation**: Verificación de datos recientes y válidos  

### Vectores de Ataque Mitigados

| Vector | Mitigación |
|--------|------------|
| **Reentrancy** | CEI pattern + estado actualizado primero |
| **Integer Overflow/Underflow** | Solidity ^0.8.0 (checks automáticos) |
| **Token Transfer Failures** | SafeERC20 con reverts explícitos |
| **Oracle Manipulation** | Timeout + validación de datos |
| **Access Control** | Modificador `onlyOwner` |
| **DoS por Gas** | Sin loops sobre arrays de usuarios |
| **Front-running** | Límites y validaciones estrictas |

### Auditoría y Testing

⚠️ **Este contrato es educativo y no ha sido auditado profesionalmente.**

Para producción real se recomienda:
1. **Auditoría profesional** (OpenZeppelin, Trail of Bits, etc.)
2. **Tests exhaustivos** (unit, integration, fuzzing)
3. **Bug bounty program**
4. **Deployment gradual** (testnet → mainnet con límites bajos)

---

## 🎓 Aprendizajes Clave

### Conceptos Aplicados del Módulo 2

1. **Control de Acceso**: OpenZeppelin Ownable
2. **Multi-token**: ERC-20 + ETH con address(0)
3. **Oráculos**: Chainlink Price Feeds
4. **Conversión de Decimales**: Sistema robusto y flexible
5. **Errores Personalizados**: Gas-efficient error handling
6. **Eventos Indexados**: Para analytics y UIs
7. **Mappings Anidados**: Contabilidad compleja
8. **Immutable/Constant**: Optimización de gas
9. **SafeERC20**: Transferencias seguras
10. **NatSpec**: Documentación completa

---

## 📋 Dirección del Contrato Desplegado

**Testnet Sepolia**: [`0x94833234260A95D7C2649787a74188B8Cfc371b2`](https://sepolia.etherscan.io/address/0x94833234260A95D7C2649787a74188B8Cfc371b2)

🔍 **Verificar en Etherscan**: [Ver contrato en Sepolia Etherscan](https://sepolia.etherscan.io/address/0x94833234260A95D7C2649787a74188B8Cfc371b2)

### Detalles del Deployment
- **Owner**: `0x2D8Bec7ee72f6715CF4C0Ad8Fb9324cAc4bE82B5`
- **Block**: 9351992
- **Bank Cap**: 1,000 USD
- **Withdrawal Limit**: 100 USD per transaction
- **ETH Support**: Enabled with Chainlink Price Feed

---

## 🛠️ Stack Tecnológico

- **Solidity**: ^0.8.29
- **Framework**: Foundry
- **Librerías**: 
  - OpenZeppelin Contracts v5.x
  - Chainlink Contracts v1.x
- **Oráculos**: Chainlink Price Feeds
- **Testnet**: Sepolia
- **Explorador**: Etherscan

---

## 📈 Próximos Pasos (V3)

Posibles mejoras para futuras versiones:

- [ ] **Yield Generation**: Integración con protocolos DeFi (Aave, Compound)
- [ ] **NFT Receipts**: NFTs como prueba de depósito
- [ ] **Governance**: DAO para decisiones del protocolo
- [ ] **Upgradability**: Patrón de proxy para upgrades
- [ ] **Multi-chain**: Deployment en L2s (Arbitrum, Optimism)
- [ ] **Flash Loans**: Préstamos instantáneos sin colateral
- [ ] **Liquidation**: Sistema de liquidación para préstamos
- [ ] **Staking**: Rewards por depositar y holdear

---

## 🤝 Contribuciones

Este es un proyecto educativo parte del curso de desarrollo Web3. 

**Autor**: Juan Urquiza  
**Módulo**: 2 - Smart Contract Development  
**Fecha**: 2025

---

## 📄 Licencia

MIT License - Ver archivo `LICENSE` para más detalles.

---

## 🙏 Agradecimientos

- **OpenZeppelin**: Por sus contratos seguros y bien testeados
- **Chainlink**: Por la infraestructura de oráculos
- **Foundry**: Por el mejor framework de desarrollo Solidity
- **Comunidad Ethereum**: Por las mejores prácticas y patrones

---

## 📞 Contacto

- GitHub: [github.com/juanitourquiza]
- LinkedIn: [Tu perfil]

---

**⚠️ Disclaimer**: Este contrato es parte de un proyecto educativo. No usar en producción sin una auditoría profesional completa.

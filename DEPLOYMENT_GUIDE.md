# 🚀 Guía Rápida de Despliegue - KipuBankV2

## Preparación

### 1. Instalar Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Instalar Dependencias
```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install smartcontractkit/chainlink-brownie-contracts
```

### 3. Configurar Variables de Entorno
```bash
cp .env.example .env
```

Edita `.env` con tus datos:
```env
PRIVATE_KEY=0x...
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
ETHERSCAN_API_KEY=YOUR_KEY
```

### 4. Compilar
```bash
forge build
```

---

## Despliegue en Sepolia

### Opción 1: Usando el Script (Recomendado)
```bash
forge script script/DeployKipuBankV2.s.sol:DeployKipuBankV2 \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Opción 2: Deployment Manual
```bash
forge create src/KipuBankV2.sol:KipuBankV2 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args 1000000000 100000000 $(cast wallet address $PRIVATE_KEY) \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

**Parámetros:**
- `1000000000` = Bank Cap de 1,000 USD
- `100000000` = Límite de retiro de 100 USD
- Tercer parámetro = tu dirección (owner)

---

## Configuración Post-Despliegue

### 1. Agregar Soporte para ETH
```bash
cast send <CONTRACT_ADDRESS> \
  "addETHSupport(address)" \
  0x694AA1769357215DE4FAC081bf1f309aDC325306 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 2. Agregar Token ERC-20 (Ejemplo: USDC)
```bash
cast send <CONTRACT_ADDRESS> \
  "addSupportedToken(address,address,uint8)" \
  0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8 \
  0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E \
  6 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 3. Verificar Configuración
```bash
# Verificar que ETH esté soportado
cast call <CONTRACT_ADDRESS> \
  "isTokenSupported(address)" \
  0x0000000000000000000000000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL

# Ver límites
cast call <CONTRACT_ADDRESS> \
  "i_bankCapUSD()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL

cast call <CONTRACT_ADDRESS> \
  "i_withdrawalLimitUSD()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## Verificación Manual en Etherscan

Si la verificación automática falla:

```bash
forge verify-contract \
  <CONTRACT_ADDRESS> \
  src/KipuBankV2.sol:KipuBankV2 \
  --chain-id 11155111 \
  --constructor-args $(cast abi-encode "constructor(uint256,uint256,address)" 1000000000 100000000 <YOUR_ADDRESS>) \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Pruebas Rápidas

### Depositar 0.01 ETH
```bash
cast send <CONTRACT_ADDRESS> \
  "depositETH()" \
  --value 0.01ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Ver tu Balance
```bash
cast call <CONTRACT_ADDRESS> \
  "getUserBalance(address,address)" \
  $(cast wallet address $PRIVATE_KEY) \
  0x0000000000000000000000000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL
```

### Obtener Precio de ETH en USD
```bash
cast call <CONTRACT_ADDRESS> \
  "getTokenPriceUSD(address)" \
  0x0000000000000000000000000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## Addresses Útiles en Sepolia

### Chainlink Price Feeds
| Asset | Address |
|-------|---------|
| ETH/USD | `0x694AA1769357215DE4FAC081bf1f309aDC325306` |
| BTC/USD | `0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43` |
| USDC/USD | `0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E` |

### Tokens de Prueba
| Token | Address |
|-------|---------|
| USDC | `0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` |
| DAI | `0x68194a729C2450ad26072b3D33ADaCbcef39D574` |

Para obtener tokens de prueba:
- ETH: https://sepoliafaucet.com/
- USDC/DAI: https://faucet.circle.com/

---

## Troubleshooting

### Error: "Insufficient funds"
- Obtén ETH de prueba: https://sepoliafaucet.com/

### Error: "Token not supported"
- Verifica que hayas ejecutado `addETHSupport` o `addSupportedToken`

### Error: "Bank cap exceeded"
- Los límites en USD pueden ser alcanzados. Considera redesplegar con límites más altos

### Verificación falla
- Espera 1-2 minutos después del deployment
- Usa `forge verify-contract` manualmente

---

## Comandos Útiles de Foundry

```bash
# Ver ABI del contrato
forge inspect KipuBankV2 abi

# Estimar gas de deployment
forge script script/DeployKipuBankV2.s.sol:DeployKipuBankV2 --rpc-url $SEPOLIA_RPC_URL

# Ver storage layout
forge inspect KipuBankV2 storage-layout

# Formatear código
forge fmt

# Linter
forge fmt --check
```

---

## Siguientes Pasos

1. ✅ Desplegado
2. ✅ Verificado en Etherscan
3. ✅ Configurado con tokens
4. ✅ Probado con depósito
5. 📝 Actualizar README_V2.md con la dirección del contrato
6. 📝 Documentar en GitHub

---

## Links de Referencia

- **Foundry Book**: https://book.getfoundry.sh/
- **Chainlink Docs**: https://docs.chain.link/data-feeds/price-feeds/addresses
- **OpenZeppelin**: https://docs.openzeppelin.com/contracts/
- **Sepolia Faucet**: https://sepoliafaucet.com/

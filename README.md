# 🏦 KipuBank - Smart Contract

**KipuBank** es un contrato inteligente descentralizado que funciona como una bóveda de ahorros personal en la blockchain de Ethereum. Permite a los usuarios depositar y retirar ETH de forma segura, aplicando reglas claras y patrones de seguridad avanzados.

## ✨ Características principales

- **🔒 Bóveda Personal**: Cada usuario tiene un saldo individual asociado a su dirección
- **💰 Depósitos Seguros**: Permite depositar ETH con verificación de límites
- **🚫 Retiros Controlados**: Límite máximo por transacción para prevenir retiros masivos
- **🏛️ Límite Global**: Tope de capital total del banco (`limiteDeposito`)
- **🛡️ Seguridad Avanzada**: Implementa patrón checks-effects-interactions anti-reentrancy
- **📊 Registro Completo**: Emite eventos para depósitos y retiros exitosos
- **📈 Estadísticas**: Contadores públicos de depósitos y retiros realizados
- **📝 Documentación NatSpec**: Código completamente documentado
    
## 🚀 Instrucciones de despliegue
A modo de prueba, siguiendo la cronología del curso, lo ideal es desplegar el contrato utilizando Remix IDE, en la testnet Sepolia.

## 💻 Cómo interactuar con el contrato

**Importante:** las unidades de medida son en Wei. Se pueden hacer las conversiones con [esta herramienta](https://eth-converter.com/).

### Constructor
El contrato **KipuBank** requiere dos parámetros en su constructor:

- `_limiteDeposito`: Límite máximo total de ETH que puede tener el banco (en Wei)
- `_limiteRetiroPorTransaccion`: Límite máximo de ETH que se puede retirar por transacción (en Wei)

## 🔧 Funciones principales

### `depositar()` - Función payable
- **Descripción**: Permite depositar ETH en tu bóveda personal
- **Cómo usar**: Envía ETH a través del campo `value` al llamar la función
- **Validaciones**: 
  - Monto > 0
  - No exceder el límite total del banco
- **Evento**: Emite `DepositoExitoso`

### `retirar(uint256 _monto)` - Función external  
- **Descripción**: Retira ETH de tu bóveda personal
- **Parámetro**: `_monto` - cantidad a retirar en Wei
- **Validaciones**:
  - Monto > 0
  - No exceder límite por transacción
  - Saldo suficiente
- **Seguridad**: Usa patrón checks-effects-interactions
- **Evento**: Emite `RetiroExitoso`

### Funciones de consulta (view - sin gas)
- `obtenerMiSaldo()`: Devuelve tu saldo actual
- `obtenerSaldoTotalBanco()`: Devuelve el saldo total del contrato
- `depositosRealizadosGlobales`: Contador total de depósitos
- `retirosRealizadosGlobales`: Contador total de retiros

## 🔐 Características de seguridad

- **Anti-reentrancy**: Implementa patrón checks-effects-interactions
- **Validación de límites**: Múltiples modificadores para verificar condiciones
- **Transferencias seguras**: Usa `call()` para enviar ETH
- **Estado consistente**: Actualiza balances antes de interacciones externas

## 📋 Dirección del contrato desplegado

**Testnet Sepolia**: [`0x3aCA094C70D5198541BE52C828703A84D66deE94`](https://sepolia.etherscan.io/address/0x3aCA094C70D5198541BE52C828703A84D66deE94)

🔍 **Verificar en Etherscan**: [Ver contrato en Sepolia Etherscan](https://sepolia.etherscan.io/address/0x3aCA094C70D5198541BE52C828703A84D66deE94)

## 🛠️ Stack tecnológico
- **Solidity**: ^0.8.29
- **Documentación**: NatSpec completa
- **Testnet**: Sepolia (recomendado)
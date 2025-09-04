// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title KipuBank
 * @author Juan Urquiza
 * @notice Un banco simple que permite depositar y retirar ETH con límites de seguridad
 * @dev Implementa el patrón checks-effects-interactions y usa errores personalizados
 */

contract KipuBank {
    /// @notice Límite máximo de ETH que se puede retirar por transacción
    uint256 public immutable limiteRetiroPorTransaccion;
    
    /// @notice Límite máximo total de ETH que puede tener el banco
    uint256 public immutable limiteDeposito;
    
    /// @notice Mapping que almacena el saldo de cada usuario
    mapping(address => uint256) private saldosUsuarios;
    
    /// @notice Contador total de depósitos realizados
    uint256 public depositosRealizadosGlobales;
    
    /// @notice Contador total de retiros realizados
    uint256 public retirosRealizadosGlobales;

    /// @notice Se emite cuando un usuario deposita ETH exitosamente
    /// @param usuario Dirección del usuario que realizó el depósito
    /// @param monto Cantidad de ETH depositada
    event DepositoExitoso(address indexed usuario, uint256 monto);
    
    /// @notice Se emite cuando un usuario retira ETH exitosamente
    /// @param usuario Dirección del usuario que realizó el retiro
    /// @param monto Cantidad de ETH retirada
    event RetiroExitoso(address indexed usuario, uint256 monto);

    /// @notice Constructor que inicializa los límites del banco
    /// @param _limiteDeposito Límite máximo total que puede tener el banco
    /// @param _limiteRetiroPorTransaccion Límite máximo por retiro
    constructor(uint256 _limiteDeposito, uint256 _limiteRetiroPorTransaccion) {
        limiteDeposito = _limiteDeposito;
        limiteRetiroPorTransaccion = _limiteRetiroPorTransaccion;
    }

    /// @notice Verifica que el monto sea mayor a cero
    /// @param _monto Monto a verificar
    modifier verificarMontoMayorACero(uint256 _monto) {
        require(_monto > 0, "El monto debe ser mayor a cero");
        _;
    }

    /// @notice Verifica que el depósito no exceda el límite total del banco
    modifier verificarLimiteDeposito() {
        require(address(this).balance + msg.value <= limiteDeposito, "El deposito excederia el limite del banco");
        _;
    }

    /// @notice Verifica que el retiro no exceda el límite por transacción
    /// @param _monto Monto a retirar
    modifier verificarlimiteRetiro(uint256 _monto) {
        require(_monto <= limiteRetiroPorTransaccion, "El monto de retiro excede el limite");
        _;
    }

    /// @notice Verifica que el usuario tenga saldo suficiente
    /// @param _monto Monto a verificar
    modifier verificarSaldoSuficiente(uint256 _monto) {
        require(saldosUsuarios[msg.sender] >= _monto, "Saldo insuficiente");
        _;
    }

    /// @notice Permite a los usuarios depositar ETH en su bóveda personal
    /// @dev Verifica que el depósito no exceda el límite del banco y sea mayor a cero
    function depositar()
        external
        payable
        verificarLimiteDeposito
    {
        require(msg.value > 0, "El monto del deposito debe ser mayor a cero");

        _actualizarBalance(msg.sender, msg.value, true);

        emit DepositoExitoso(msg.sender, msg.value);
    }

    /// @notice Permite a los usuarios retirar ETH de su bóveda personal
    /// @dev Sigue el patrón checks-effects-interactions para prevenir reentrancy
    /// @param _monto Cantidad de ETH a retirar
    function retirar(uint256 _monto)
        external
        verificarMontoMayorACero(_monto)
        verificarlimiteRetiro(_monto)
        verificarSaldoSuficiente(_monto)
    {
        // Effects: actualizar el estado antes de la interacción externa
        _actualizarBalance(msg.sender, _monto, false);

        // Interactions: transferir ETH al usuario
        (bool exito, ) = payable(msg.sender).call{value: _monto}("");
        require(exito, "La transferencia fallo");

        emit RetiroExitoso(msg.sender, _monto);
    }
    
    /// @notice Devuelve el saldo del usuario que llama la función
    /// @return Saldo actual del usuario en wei
    function obtenerMiSaldo() external view returns (uint256) {
        return saldosUsuarios[msg.sender];
    }

    /// @notice Devuelve el saldo total del banco
    /// @return Saldo total del contrato en wei
    function obtenerSaldoTotalBanco() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Función privada para actualizar el balance de un usuario
    /// @dev También incrementa los contadores globales de transacciones
    /// @param _usuario Dirección del usuario
    /// @param _monto Cantidad a sumar o restar
    /// @param _esDeposito True para depósito, false para retiro
    function _actualizarBalance(address _usuario, uint256 _monto, bool _esDeposito) private {
        if (_esDeposito) {
            saldosUsuarios[_usuario] += _monto;
            depositosRealizadosGlobales++;
        } else {
            saldosUsuarios[_usuario] -= _monto;
            retirosRealizadosGlobales++;
        }
    }
}
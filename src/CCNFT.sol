// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/* import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; */

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";


contract CCNFT is ERC721Enumerable, Ownable, ReentrancyGuard {

    //EVENTOS
    // indexed: Permiten realizar búsquedas en los registros de eventos.

    // Compra de NFTs
    event Buy(address indexed buyer, uint256 indexed tokenId, uint256 value); 

    // Reclamo de NFTs
    event Claim(address indexed claimer, uint256 indexed tokenId); 

    // Intercambio de NFTs entre usuarios
    event Trade(
        address indexed buyer, 
        address indexed seller, 
        uint256 indexed tokenId, 
        uint256 value
    );

    // Venta: poner un NFT en venta
    event PutOnSale(
        uint256 indexed tokenId, 
        uint256 price
    );


    // Estructura del estado de venta de un NFT.
    struct TokenSale {
        bool onSale;      // true si el token está en venta
        uint256 price;    // precio en tokens ERC20
    }


    // Biblioteca Counters de OpenZeppelin para manejar contadores de manera segura.
    using Counters for Counters.Counter; 

    // Contador para asignar IDs únicos a cada NFT que se crea.
    Counters.Counter private tokenIdTracker;

    // Mapeo del ID de un token (NFT) a un valor específico.
    mapping(uint256 => uint256) public values;

    // Mapeo de un valor a un booleano para indicar si el valor es válido o no.
    mapping(uint256 => bool) public validValues;

    // Mapeo del ID de un token (NFT) a su estado de venta (TokenSale).
    mapping(uint256 => TokenSale) public tokensOnSale;

    // Lista que contiene los IDs de los NFTs que están actualmente en venta.
    uint256[] public listTokensOnSale;
    
    address public fundsCollector; // Dirección de los fondos de las ventas de los NFTs
    address public feesCollector; // Dirección de las tarifas de transacción (compra y venta de los NFTs)

    bool public canBuy; // Booleano que indica si las compras de NFTs están permitidas.
    bool public canClaim; // Booleano que indica si la reclamación (quitar) de NFTs está permitida.
    bool public canTrade; // Booleano que indica si la transferencia de NFTs está permitida.

    uint256 public totalValue; // Valor total acumulado de todos los NFTs en circulación.
    uint256 public maxValueToRaise; // Valor máximo permitido para recaudar a través de compras de NFTs.

    uint16 public buyFee; // Tarifa aplicada a las compras de NFTs.
    uint16 public tradeFee; // Tarifa aplicada a las transferencias de NFTs.
    
    uint16 public maxBatchCount; // Límite en la cantidad de NFTs por operación (evitar exceder el límite de gas en una transacción).

    uint32 public profitToPay; // Porcentaje adicional a pagar en las reclamaciones.


    // Referencia al contrato ERC20 manejador de fondos. 
    IERC20 public fundsToken;

    // Constructor (nombre y símbolo del NFT).    
    constructor() ERC721("CollectibleClaimNFT", "CCNFT") {
    }



    // PUBLIC FUNCTIONS

    // Funcion de compra de NFTs. 

    // Parametro value: El valor de cada NFT que se está comprando.
    // Parametro amount: La cantidad de NFTs que se quieren comprar.
    // Función de compra de NFTs. 
    function buy(uint256 value, uint256 amount) external nonReentrant {
        
        // Verificación de permisos de la compra con "canBuy". Incluir un mensaje de falla.
        require(canBuy, "NFT buying is currently disabled");

        // Verificacón de la cantidad de NFTs a comprar sea mayor que 0 y menor o igual al máximo permitido (maxBatchCount). Incluir un mensaje de falla.
        require(amount > 0 && amount <= maxBatchCount, "Invalid amount");

        // Verificación del valor especificado para los NFTs según los valores permitidos en validValues. Incluir un mensaje de falla.
        require(validValues[value], "Value not allowed");

        // Verificacón del valor total después de la compra (no debe exeder el valor máximo permitido "maxValueToRaise"). Incluir un mensaje de falla.
        require(totalValue + (value * amount) <= maxValueToRaise, "Exceeds fundraising cap");

        totalValue += value * amount; // Incremento del valor total acumulado por el valor de los NFTs comprados.

        for (uint256 i = 0; i < amount; i++) { // Bucle desde 1 hasta amount (inclusive) para mintear la cantidad especificada de NFTs.

            uint256 newTokenId = tokenIdTracker.current(); // Obtener el ID actual del token

            values[newTokenId] = value; // Asignar el valor del NFT al tokenId actual "current()" en el mapeo values.

            _safeMint(msg.sender, newTokenId); // Minteo de NFT y asignación al msg.sender.

            emit Buy(msg.sender, newTokenId, value); // Evento Buy con el comprador, el tokenId y el valor del NFT.

            tokenIdTracker.increment(); // Incremento del contador tokenIdTracker (NFT deben tener un tokenId único).        
        }

        // Transfencia de fondos desde el comprador (_msgSender()) al recolector de fondos (fundsCollector) por el valor total de los NFTs comprados. 
        if (!fundsToken.transferFrom(_msgSender(), fundsCollector, value * amount)) {
            revert("Cannot send funds tokens"); // Incluir un mensaje de falla.
        }

        // Transferencia de tarifas de compra desde el comprador (_msgSender()) al recolector de tarifas (feesCollector).
        // Tarifa = fracción del valor total de la compra (value * amount * buyFee / 10000).
        uint256 fee = value * amount * buyFee / 10000;
        if (!fundsToken.transferFrom(_msgSender(), feesCollector, fee)) {
            revert("Cannot send fees tokens"); // Incluir un mensaje de falla.
        }
    }



    // Funcion de "reclamo" de NFTs

    // Parámetros: Lista de IDs de tokens de reclamo (utilizar calldata).
    function claim(uint256[] calldata listTokenId) external nonReentrant {

        // Verificacón habilitación de "reclamo" (canClaim). Incluir un mensaje de falla.
        require(canClaim, "Claiming is disabled");

        // Verificacón de la cantidad de tokens a reclamar (mayor que 0 y menor o igual a maxBatchCount). Incluir un mensaje de falla.
        require(listTokenId.length > 0 && listTokenId.length <= maxBatchCount, "Invalid amount");

        uint256 claimValue = 0; // Inicializacion de claimValue a 0.
        TokenSale storage tokenSale; // Variable tokenSale.

        for (uint256 i = 0; i < listTokenId.length; i++) { // Bucle para iterar a través de cada token ID en listTokenId.

            uint256 tokenId = listTokenId[i];

            // Verificacón listTokenId[i] exista. Incluir un mensaje de falla.
            require(_exists(tokenId), "Token does not exist");

            // Verificacón que _msgSender() sea el propietario del token. Incluir un mensaje de falla.
            require(ownerOf(tokenId) == _msgSender(), "Only owner can claim");

            claimValue += values[tokenId]; // Suma de el valor del token al claimValue acumulado.
            values[tokenId] = 0;           // Reseteo del valor del token a 0.

            tokenSale = tokensOnSale[tokenId]; // Acceso a la información de venta del token
            tokenSale.onSale = false;         // Desactivacion del estado de venta.
            tokenSale.price = 0;              // Desactivacion del estado de venta.

            removeFromArray(listTokensOnSale, tokenId); // Remover el token de la lista de tokens en venta.           
            _burn(tokenId); // Quemar el token, eliminándolo permanentemente de la circulación.
            emit Claim(_msgSender(), tokenId); // Registrar el ID y propietario del token reclamado.
        }

        totalValue -= claimValue; // Reducir el totalValue acumulado.

        // Calculo del monto total a transferir (claimValue + (claimValue * profitToPay / 10000)).
        uint256 totalPayout = claimValue + (claimValue * profitToPay / 10000);

        // Transferir los fondos desde fundsCollector al (_msgSender()).
        if (!fundsToken.transferFrom(fundsCollector, _msgSender(), totalPayout)) {
            revert("Cannot send claim funds");
        }
    }


    // Función de compra de NFT que está en venta.
    function trade(uint256 tokenId) external nonReentrant {

        // Verificación del comercio de NFTs (canTrade). Incluir un mensaje de falla.
        require(canTrade, "Trading is disabled");

        // Verificación de existencia del tokenId (_exists). Incluir un mensaje de falla.
        require(_exists(tokenId), "Token does not exist");

        // Verificación de propietario actual del NFT no sea el comprador. Incluir un mensaje de falla.
        address seller = ownerOf(tokenId);
        require(seller != msg.sender, "Buyer is the Seller");

        TokenSale storage tokenSale = tokensOnSale[tokenId]; // Estado de venta del NFT.

        // Verifica que el NFT esté actualmente en venta (onSale es true). Si no lo está, la transacción falla con el mensaje "Token not On Sale".
        require(tokenSale.onSale, "Token not On Sale");

        uint256 price = tokenSale.price;

        // Transferencia del precio de venta del comprador al propietario actual del NFT usando fundsToken.
        if (!fundsToken.transferFrom(msg.sender, seller, price)) {
            revert("Cannot send payment to seller");
        }

        // Transferencia de tarifa de comercio (calculada como un porcentaje del valor del NFT) del comprador al feesCollector.
        uint256 fee = (price * tradeFee) / 10000;
        if (!fundsToken.transferFrom(msg.sender, feesCollector, fee)) {
            revert("Cannot send trade fee");
        }

        // Registro de dirección del comprador, dirección del vendedor, tokenId, y precio de venta.  
        emit Trade(msg.sender, seller, tokenId, price);

        // Transferencia del NFT del propietario actual al comprador.
        _safeTransfer(seller, msg.sender, tokenId, "");

        tokenSale.onSale = false; // NFT no disponible para la venta.
        tokenSale.price = 0;      // Reseteo del precio de venta del NFT.

        removeFromArray(listTokensOnSale, tokenId); // Remover el tokenId de la lista listTokensOnSale de NFTs.
    }



    // Función para poner en venta un NFT.
    function putOnSale(uint256 tokenId, uint256 price) external {
        
        // Verificación de operaciones de comercio (canTrade). Incluir un mensaje de falla.
        require(canTrade, "Trading is disabled");

        // Verificación de existencia del tokenId mediante "_exists". Incluir un mensaje de falla.
        require(_exists(tokenId), "Token does not exist");

        // Verificación remitente de la transacción es propietario del token. Incluir un mensaje de falla.
        require(ownerOf(tokenId) == msg.sender, "Only owner can put token on sale");

        TokenSale storage tokenSale = tokensOnSale[tokenId]; // Variable de almacenamiento de datos para el token.

        tokenSale.onSale = true; // Indicar que el token está en venta.
        tokenSale.price = price; // Indicar precio de venta del token.

        addToArray(listTokensOnSale, tokenId); // Añadir token a la lista.

        emit PutOnSale(tokenId, price); // Notificar que el token ha sido puesto a la venta (token y precio).
    }


    // SETTERS

    // Utilización del token ERC20 para transacciones.
    function setFundsToken(address token) external onlyOwner { // Parámetro, dirección del contrato del token ERC20.                                                      
        require(token != address(0), "Invalid token address"); // La dirección no puede ser cero.
        fundsToken = IERC20(token); // Asignación del contrato ERC20.
    }

    // Dirección para colectar los fondos de las ventas de NFTs.
    function setFundsCollector(address _address) external onlyOwner { // Parámetro, dirección de colector de fondos.
        require(_address != address(0), "Invalid address");
        fundsCollector = _address;
    }

    // Dirección para colectar las tarifas de transacción.
    function setFeesCollector(address _address) external onlyOwner { // Parámetro, dirección del colector de tarifas.
        require(_address != address(0), "Invalid address");
        feesCollector = _address;
    }

    // Porcentaje de beneficio a pagar en las reclamaciones.
    function setProfitToPay(uint32 _profitToPay) external onlyOwner { // Parámetro, porcentaje de beneficio a pagar.
        profitToPay = _profitToPay;
    }

    // Función que habilita o deshabilita la compra de NFTs.
    function setCanBuy(bool _canBuy) external onlyOwner { // Parámetro, booleano que indica si la compra está permitida.
        canBuy = _canBuy;
    }

    // Función que habilita o deshabilita la reclamación de NFTs.
    function setCanClaim(bool _canClaim) external onlyOwner { // Parámetro, booleano que indica si la reclamación está permitida.
        canClaim = _canClaim;
    }

    // Función que habilita o deshabilita el intercambio de NFTs.
    function setCanTrade(bool _canTrade) external onlyOwner { // Parámetro, booleano que indica si el intercambio está permitido.
        canTrade = _canTrade;
    }

    // Valor máximo que se puede recaudar de venta de NFTs.
    function setMaxValueToRaise(uint256 _maxValueToRaise) external onlyOwner {
        maxValueToRaise = _maxValueToRaise;
    }

    // Función para agregar un valor válido para NFTs.
    function addValidValues(uint256 value) external onlyOwner {
        validValues[value] = true;
    }

    // Función para establecer la cantidad máxima de NFTs por operación.
    function setMaxBatchCount(uint16 _maxBatchCount) external onlyOwner {
        maxBatchCount = _maxBatchCount;
    }

    // Tarifa aplicada a las compras de NFTs.
    function setBuyFee(uint16 _buyFee) external onlyOwner {
        buyFee = _buyFee;
    }

    // Tarifa aplicada a las transacciones de NFTs.
    function setTradeFee(uint16 _tradeFee) external onlyOwner {
        tradeFee = _tradeFee;
    }


    // ARRAYS

    // Verificar duplicados en el array antes de agregar un nuevo valor.
    function addToArray(uint256[] storage array, uint256 value) private {
        uint256 index = find(array, value);
        if (index == array.length) {
            array.push(value); // Si no está en el array, lo agregamos
        }
    }


    // Eliminar un valor del array.
    function removeFromArray(uint256[] storage array, uint256 value) private {
        uint256 index = find(array, value);
        if (index < array.length) {
            array[index] = array[array.length - 1]; // Reemplaza con el último
            array.pop();                            // Elimina el último
        }
    }

    // Buscar un valor en un array y retornar su índice o la longitud del array si no se encuentra.
    function find(uint256[] storage array, uint256 value) private view returns (uint256) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return i;
            }
        }
        return array.length; // Si no se encuentra, retornar longitud (fuera de rango).
    }



    // NOT SUPPORTED FUNCTIONS

    // Funciones para deshabilitar las transferencias de NFTs,

    function transferFrom(address, address, uint256) 
        public 
        pure
        override(ERC721, IERC721) 
    {
        revert("Not Allowed");
    }

    function safeTransferFrom(address, address, uint256) 
        public pure override(ERC721, IERC721) 
    {
        revert("Not Allowed");
    }

    function safeTransferFrom(address, address, uint256,  bytes memory) 
        public 
        pure
        override(ERC721, IERC721) 
    {
        revert("Not Allowed");
    }


    // Compliance required by Solidity

    // Funciones para asegurar que el contrato cumple con los estándares requeridos por ERC721 y ERC721Enumerable.

        function _beforeTokenTransfer(address from, address to, uint256 tokenId)
            internal 
            override(ERC721Enumerable)
        {
            super._beforeTokenTransfer(from, to, tokenId);
        }
   
}


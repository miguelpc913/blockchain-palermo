// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BUSD.sol";
import "../src/CCNFT.sol";

// Definición del contrato de prueba CCNFTTest que hereda de Test. 
// Declaración de direcciones y dos instancias de contratos (BUSD y CCNFT).
contract CCNFTTest is Test {
    address deployer;
    address c1;
    address c2;
    address funds;
    address fees;
    BUSD busd;
    CCNFT ccnft;

// Ejecución antes de cada prueba. 
// Inicializar las direcciones y desplgar las instancias de BUSD y CCNFT.
    function setUp() public {
        deployer = address(this);
        c1 = vm.addr(1);
        c2 = vm.addr(2);
        funds = vm.addr(3);
        fees = vm.addr(4);

        busd = new BUSD();
        ccnft = new CCNFT();

        ccnft.setFundsToken(address(busd));
        ccnft.setFundsCollector(funds);
        ccnft.setFeesCollector(fees);
    }

// Prueba de "setFundsCollector" del contrato CCNFT. 
// Llamar al método y despues verificar que el valor se haya establecido correctamente.
    function testSetFundsCollector() public {
        address newFunds = vm.addr(10);
        ccnft.setFundsCollector(newFunds);
        assertEq(ccnft.fundsCollector(), newFunds);
    }

// Prueba de "setFeesCollector" del contrato CCNFT
// Verificar que el valor se haya establecido correctamente.
    function testSetFeesCollector() public {
        address newFees = vm.addr(11);
        ccnft.setFeesCollector(newFees);
        assertEq(ccnft.feesCollector(), newFees);
    }

// Prueba de "setProfitToPay" del contrato CCNFT
// Verificar que el valor se haya establecido correctamente.
    function testSetProfitToPay() public {
        ccnft.setProfitToPay(1000);
        assertEq(ccnft.profitToPay(), 1000);
    }

// Prueba de "setCanBuy" primero estableciéndolo en true y verificando que se establezca correctamente.
// Despues establecerlo en false verificando nuevamente.
    function testSetCanBuy() public {
        ccnft.setCanBuy(true);
        assertTrue(ccnft.canBuy());
        ccnft.setCanBuy(false);
        assertFalse(ccnft.canBuy());
    }

// Prueba de método "setCanTrade". Similar a "testSetCanBuy".
    function testSetCanTrade() public {
        ccnft.setCanTrade(true);
        assertTrue(ccnft.canTrade());
        ccnft.setCanTrade(false);
        assertFalse(ccnft.canTrade());
    }

// Prueba de método "setCanClaim". Similar a "testSetCanBuy".
    function testSetCanClaim() public {
        ccnft.setCanClaim(true);
        assertTrue(ccnft.canClaim());
        ccnft.setCanClaim(false);
        assertFalse(ccnft.canClaim());
    }

// Prueba de "setMaxValueToRaise" con diferentes valores.
// Verifica que se establezcan correctamente.
    function testSetMaxValueToRaise() public {
        ccnft.setMaxValueToRaise(100 ether);
        assertEq(ccnft.maxValueToRaise(), 100 ether);
    }

// Prueba de "addValidValues" añadiendo diferentes valores.
// Verificar que se hayan añadido correctamente.
    function testAddValidValues() public {
        ccnft.addValidValues(1000);
        ccnft.addValidValues(2000);
        assertTrue(ccnft.validValues(1000));
        assertTrue(ccnft.validValues(2000));
    }

// Prueba de "setMaxBatchCount".
// Verifica que el valor se haya establecido correctamente.
    function testSetMaxBatchCount() public {
        ccnft.setMaxBatchCount(25);
        assertEq(ccnft.maxBatchCount(), 25);
    }

// Prueba de "setBuyFee".
// Verificar que el valor se haya establecido correctamente.
    function testSetBuyFee() public {
        ccnft.setBuyFee(150);
        assertEq(ccnft.buyFee(), 150);
    }

// Prueba de "setTradeFee".
// Verificar que el valor se haya establecido correctamente.
    function testSetTradeFee() public {
        ccnft.setTradeFee(300);
        assertEq(ccnft.tradeFee(), 300);
    }

// Prueba de que no se pueda comerciar cuando canTrade es false.
// Verificar que se lance un error esperado.
    function testCannotTradeWhenCanTradeIsFalse() public {
        vm.expectRevert("Trading is disabled");
        ccnft.trade(1);
    }

// Prueba que no se pueda comerciar con un token que no existe, incluso si canTrade es true. 
// Verificar que se lance un error esperado.
    function testCannotTradeWhenTokenDoesNotExist() public {
        ccnft.setCanTrade(true);
        vm.expectRevert("Token does not exist");
        ccnft.trade(9999);
    }
}

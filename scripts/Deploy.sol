// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BUSD.sol";
import "../src/CCNFT.sol";

contract Deploy is Script {
    function run() external {
        // Inicia la transmisión (transacción firmada)
        vm.startBroadcast();

        // 1. Deploy del contrato BUSD (token ERC20)
        BUSD busd = new BUSD();

        // 2. Deploy del contrato de NFT
        CCNFT ccnft = new CCNFT();

        // 3. Seteo de token como fundsToken
        ccnft.setFundsToken(address(busd));


        // 5. Valores de configuración iniciales
        ccnft.setCanBuy(true);
        ccnft.setCanClaim(true);
        ccnft.setCanTrade(true);
        ccnft.setMaxBatchCount(10);
        ccnft.setMaxValueToRaise(1_000_000 * 1e18);
        ccnft.setBuyFee(100);      // 1% (100 / 10000)
        ccnft.setTradeFee(200);    // 2% (200 / 10000)
        ccnft.setProfitToPay(500); // 5% de ganancia al hacer claim

        // 6. Registrar algunos valores válidos
        ccnft.addValidValues(1 ether);
        ccnft.addValidValues(5 ether);
        ccnft.addValidValues(10 ether);

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import "../src/UltraVerifier.sol";
import "../src/Chatsystem.sol";

contract DeployAnonChat is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);

        // 1. Libraries are deployed and linked automatically by Forge here
        HonkVerifier verifier = new HonkVerifier();

        // 2. Deploy Chatsystem with the verifier address
        Chatsystem system = new Chatsystem("GlobalChat", "PrivacyVault", address(verifier));

        vm.stopBroadcast();

        console.log("Verifier deployed to:", address(verifier));
        console.log("Chatsystem deployed to:", address(system));
    }
}

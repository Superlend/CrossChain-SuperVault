// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";

import {lz_send} from "../src/lz_test/lz_send.sol";
import {Script} from "forge-std/Script.sol";

contract DeployLzContractsScript is Script {
    function run() external {
        vm.createSelectFork("arbitrum_sepolia");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        lz_send lz_send_contract = new lz_send();

        console.log("lz_send_contract deployed at:", address(lz_send_contract));

        vm.stopBroadcast();
    }
}

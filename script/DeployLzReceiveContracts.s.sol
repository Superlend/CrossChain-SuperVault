// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";

import {lz_receive} from "../src/lz_test/lz_receive.sol";
import {Script} from "forge-std/Script.sol";

contract DeployLzContractsScript is Script {
    function run() external {
        vm.createSelectFork("optimism_sepolia");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address stargate = 0x543BdA7c6cA4384FE90B1F5929bb851F52888983;
        address endpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;

        vm.startBroadcast(deployerPrivateKey);

        lz_receive lz_receive_contract = new lz_receive(endpoint, stargate);

        console.log("lz_receive_contract deployed at:", address(lz_receive_contract));

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SpokeReceiver} from "../src/SpokeReceiver.sol";

contract SetProtocolOnSpoke is Script {
    function run() external {
        vm.createSelectFork("optimism_sepolia");
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address spokeReceiver = 0x7FE5c09e4cb2B8439e17576E2710419005db7Bf3;
        SpokeReceiver(payable(spokeReceiver)).setProtocolInfo("AaveV3Arbitrum", 40231, 0x08Cce8cA38CE8256f7E072362c55c459320e4B0c);
        vm.stopBroadcast();
    }
}

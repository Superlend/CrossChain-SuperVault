// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Spoke} from "../src/AaveV3Spoke.sol";
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

contract DeploySpokeReceiver is Script {
    function run() external {
        vm.createSelectFork("optimism_sepolia");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address stargate_optimism = 0x314B753272a3C79646b92A87dbFDEE643237033a;
        address endpoint_optimism = 0x6EDCE65403992e310A62460808c4b910D972f10f;
        address assetAddress = 0x488327236B65C61A6c083e8d811a4E0D3d1D4268;
        address poolAddress = 0x7dCEFCDe37fAC8A0551cdd5f63f4537A790d2c5b;

        AaveV3Spoke spokeReceiver = new AaveV3Spoke(endpoint_optimism, stargate_optimism, assetAddress, poolAddress);

        console.log("SpokeReceiver deployed at:", address(spokeReceiver));

        vm.stopBroadcast();
    }
}

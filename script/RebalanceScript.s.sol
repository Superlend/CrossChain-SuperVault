// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AaveV3Wrapper} from "../src/fuses/AaveV3Wrapper.sol";
import {AaveV3Spoke} from "../src/AaveV3Spoke.sol";

contract RebalanceScript is Script {
    function run() external {
        vm.createSelectFork("optimism_sepolia");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // address Aavev3ArbitrumFuse = 0x08Cce8cA38CE8256f7E072362c55c459320e4B0c;

        // AaveV3Fuse(payable(Aavev3ArbitrumFuse)).withdrawCrossChain{value: 0.0001 ether}(100 * 1e6, "AaveV3Optimism");

        address SpokeOptimism = 0x7FE5c09e4cb2B8439e17576E2710419005db7Bf3;
        AaveV3Spoke(payable(SpokeOptimism)).withdrawCrossChain{value: 0.0008 ether}(50 * 1e6, "AaveV3Arbitrum");
        vm.stopBroadcast();
    }
}

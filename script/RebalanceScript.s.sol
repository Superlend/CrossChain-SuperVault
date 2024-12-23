// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AaveV3Fuse} from "../src/fuses/Aavev3Fuse.sol";

contract RebalanceScript is Script {
    function run() external {
        vm.createSelectFork("arbitrum_sepolia");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address Aavev3ArbitrumFuse = 0xa444B7eDd3aAA81beC6Dd88324492e69AEaD0a08;
        address token = 0x3253a335E7bFfB4790Aa4C25C4250d206E9b9773;

        IERC20(token).approve(Aavev3ArbitrumFuse, type(uint256).max);

        // // Transfer tokens to lz_send
        // IERC20(token).transfer(Aavev3ArbitrumFuse, 500 * 1e6);

        AaveV3Fuse(payable(Aavev3ArbitrumFuse)).withdrawCrossChain{value: 0.0001 ether}(500 * 1e6, "AaveV3Optimism");
        vm.stopBroadcast();
    }
}

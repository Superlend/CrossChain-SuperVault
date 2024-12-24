// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OptimismLendScript is Script {
    function run() external {
        vm.createSelectFork("optimism_sepolia");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address poolAddress = 0x7dCEFCDe37fAC8A0551cdd5f63f4537A790d2c5b;
        address assetAddress = 0x488327236B65C61A6c083e8d811a4E0D3d1D4268;

        IERC20(assetAddress).approve(address(poolAddress), 4 * 1e6);

        IPool(poolAddress).supply(assetAddress, 4 * 1e6, address(this), 0);

        vm.stopBroadcast();
    }
}

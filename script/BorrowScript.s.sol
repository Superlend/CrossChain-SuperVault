// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BorrowScript is Script {
    function run() external {
        vm.createSelectFork("optimism_sepolia");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address poolAddress = 0x7dCEFCDe37fAC8A0551cdd5f63f4537A790d2c5b;
        address assetAddress = 0x488327236B65C61A6c083e8d811a4E0D3d1D4268;

        IPool(poolAddress).borrow(assetAddress, 10000 * 1e6, 2, 0, address(0x469D7Fd0d97Bb8603B89228D79c7F037B2833859));

        vm.stopBroadcast();
    }
}

// write a script to approve the lz_send contract to spend the tokens on behalf of the user
// the script should be able to approve the lz_send contract to spend the tokens on behalf of the user

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {lz_send} from "../src/lz_test/lz_send.sol";

contract ApproveScript is Script {
    function run() public {
        console.log("ApproveScript");
        vm.createSelectFork("arbitrum_sepolia");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address lzSend = 0x3eE0830C5183ca0997Eb32A11b58aB1b4797020d;
        address token = 0x3253a335E7bFfB4790Aa4C25C4250d206E9b9773;
        address oft = 0x543BdA7c6cA4384FE90B1F5929bb851F52888983;

        address assetOnDestination = 0x488327236B65C61A6c083e8d811a4E0D3d1D4268;
        address poolAddress = 0x7dCEFCDe37fAC8A0551cdd5f63f4537A790d2c5b;
        address composer = 0x1bDE06d63B684d2E049e573Ac55b363F2c9e37E1;

        // First approve lz_send to spend our tokens
        IERC20(token).approve(lzSend, type(uint256).max);

        // Also approve OFT contract to spend tokens from lz_send
        // vm.stopBroadcast();
        // vm.startBroadcast(lzSend);
        // IERC20(token).approve(oft, type(uint256).max);
        // vm.stopBroadcast();
        // vm.startBroadcast(deployerPrivateKey);

        // Transfer tokens to lz_send
        IERC20(token).transfer(lzSend, 10 * 1e6);

        // Then call send
        lz_send(lzSend).send{value: 0.0001 ether}(
            oft, 40232, 10 * 1e6, token, assetOnDestination, poolAddress, composer
        );

        vm.stopBroadcast();
    }
}

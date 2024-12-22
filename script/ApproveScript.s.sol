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

        address lzSend = 0xD7De63Dd2fE384217e9c758E54d964696E182891;
        address token = 0x3253a335E7bFfB4790Aa4C25C4250d206E9b9773;
        address oft = 0x543BdA7c6cA4384FE90B1F5929bb851F52888983;

        // First approve lz_send to spend our tokens
        IERC20(token).approve(lzSend, type(uint256).max);

        // Also approve OFT contract to spend tokens from lz_send
        // vm.stopBroadcast();
        // vm.startBroadcast(lzSend);
        // IERC20(token).approve(oft, type(uint256).max);
        // vm.stopBroadcast();
        // vm.startBroadcast(deployerPrivateKey);

        // Transfer tokens to lz_send
        IERC20(token).transfer(lzSend, 5000000);

        // Then call send
        lz_send(lzSend).send{value: 0.0001 ether}(
            oft,
            40232,
            5000000,
            token,
            0x488327236B65C61A6c083e8d811a4E0D3d1D4268,
            0x5aacA776b680F99ea6C0Af696b53923fe97864E3
        );

        vm.stopBroadcast();
    }
}

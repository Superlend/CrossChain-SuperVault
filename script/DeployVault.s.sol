// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
// write deployment script for the vault

import {AaveV3Wrapper} from "../src/fuses/AaveV3Wrapper.sol";
import {CompoundV3Wrapper} from "../src/fuses/CompoundV3Wrapper.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";

import {SuperVault} from "../src/SuperVault.sol";
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

contract DeployVault is Script {
    address public owner = 0x469D7Fd0d97Bb8603B89228D79c7F037B2833859;
    address public feeRecipient = 0x469D7Fd0d97Bb8603B89228D79c7F037B2833859;

    address constant USDC_Arbitrum_testnet = 0x3253a335E7bFfB4790Aa4C25C4250d206E9b9773;
    address constant AAVE_ADDRESSES_PROVIDER_Arbitrum_testnet = 0xcA4BF2e653D87c18E0c53A45309c378f63b9F507;

    function run() external {
        vm.createSelectFork("arbitrum_sepolia");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IPoolAddressesProvider addressesProvider_arbitrum_testnet =
            IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER_Arbitrum_testnet);
        IPool lendingPool_arbitrum_testnet = IPool(addressesProvider_arbitrum_testnet.getPool());
        address stargate = 0x543BdA7c6cA4384FE90B1F5929bb851F52888983;
        address endpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;

        SuperVault vault = new SuperVault(
            USDC_Arbitrum_testnet, address(feeRecipient), owner, 0, 100000 * 1e6, "SuperLendUSDC", "SLUSDC"
        );
        AaveV3Wrapper aaveV3Wrapper_arbitrum_testnet = new AaveV3Wrapper(
            address(lendingPool_arbitrum_testnet),
            USDC_Arbitrum_testnet,
            address(addressesProvider_arbitrum_testnet),
            address(vault),
            endpoint,
            stargate,
            owner
        );
        console.log("Vault deployed at:", address(vault));
        console.log("AaveV3Wrapper arbitrum_testnet deployed at:", address(aaveV3Wrapper_arbitrum_testnet));
        vm.stopBroadcast();
    }
}

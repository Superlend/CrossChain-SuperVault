// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
// write deployment script for the vault

import {AaveV3Fuse} from "../src/fuses/AaveV3Fuse.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";

import {SuperVault} from "../src/Vault.sol";
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

contract DeployVault is Script {
    address public owner = 0x469D7Fd0d97Bb8603B89228D79c7F037B2833859;
    address public feeRecipient = 0x469D7Fd0d97Bb8603B89228D79c7F037B2833859;

    address constant USDC_Etherlink_testnet = 0xa7c9092A5D2C3663B7C5F714dbA806d02d62B58a;
    address constant AAVE_ADDRESSES_PROVIDER_Etherlink_testnet = 0x124834E658E37255CfB7f30206683B5C5078B0Cc;

    address constant USDC_Base_mainnet = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant AAVE_ADDRESSES_PROVIDER_Base_mainnet = 0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D;

    function run() external {
        vm.createSelectFork("etherlink_testnet");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IPoolAddressesProvider addressesProvider_etherlink_testnet =
            IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER_Etherlink_testnet);
        IPool lendingPool_etherlink_testnet = IPool(addressesProvider_etherlink_testnet.getPool());

        IPoolAddressesProvider addressesProvider_base_mainnet =
            IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER_Base_mainnet);
        IPool lendingPool_base_mainnet = IPool(0xA238Dd80C259a72e81d7e4664a9801593F98d1c5);

        SuperVault vault = new SuperVault(
            USDC_Etherlink_testnet, address(feeRecipient), owner, 0, 3000000000000000000000, "SuperLendUSDC", "SLUSDC"
        );
        AaveV3Fuse aaveV3Fuse_etherlink_testnet = new AaveV3Fuse(
            address(lendingPool_etherlink_testnet),
            USDC_Etherlink_testnet,
            address(addressesProvider_etherlink_testnet),
            address(vault),
            address(0x123),
            address(0x456)
        );
        AaveV3Fuse aaveV3Fuse_base_mainnet = new AaveV3Fuse(
            address(lendingPool_base_mainnet),
            USDC_Base_mainnet,
            address(addressesProvider_base_mainnet),
            address(vault),
            address(0x123),
            address(0x456)
        );
        console.log("Vault deployed at:", address(vault));
        console.log("AaveV3Fuse etherlink_testnet deployed at:", address(aaveV3Fuse_etherlink_testnet));
        console.log("AaveV3Fuse base_mainnet deployed at:", address(aaveV3Fuse_base_mainnet));
        vm.stopBroadcast();
    }
}

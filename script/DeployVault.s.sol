// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
// write deployment script for the vault

import {AaveV3Fuse} from "../src/fuses/AaveV3Fuse.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";

import {SuperVault} from "../src/Vault.sol";
import {console} from "forge-std/console.sol";

contract DeployVault {
    address public owner = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public feeRecipient = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant AAVE_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    
    function run() external {
        IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER);
        IPool lendingPool = IPool(addressesProvider.getPool());

        SuperVault vault = new SuperVault(USDC, address(feeRecipient), owner, 0, 3000000000, "SuperLendUSDC", "SLUSDC");
        AaveV3Fuse aaveV3Fuse = new AaveV3Fuse(address(lendingPool), USDC, address(addressesProvider), address(vault));
        console.log("Vault deployed at:", address(vault));
        console.log("AaveV3Fuse deployed at:", address(aaveV3Fuse));
    }
}
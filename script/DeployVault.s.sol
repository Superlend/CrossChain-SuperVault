// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
// write deployment script for the vault

import {AaveV3Fuse} from "../src/fuses/AaveV3Fuse.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";

import {SuperVault} from "../src/Vault.sol";
import {console} from "forge-std/console.sol";

contract DeployVault {
    address public owner = 0x469D7Fd0d97Bb8603B89228D79c7F037B2833859;
    address public feeRecipient = 0x469D7Fd0d97Bb8603B89228D79c7F037B2833859;
    address constant USDC = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9;
    address constant AAVE_ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;
    
    function run() external {
        IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER);
        IPool lendingPool = IPool(addressesProvider.getPool());

        SuperVault vault = new SuperVault(USDC, address(feeRecipient), owner, 0, 3000000000, "SuperLendUSDC", "SLUSDC");
        AaveV3Fuse aaveV3Fuse = new AaveV3Fuse(address(lendingPool), USDC, address(addressesProvider), address(vault));
        console.log("Vault deployed at:", address(vault));
        console.log("AaveV3Fuse deployed at:", address(aaveV3Fuse));
    }
}
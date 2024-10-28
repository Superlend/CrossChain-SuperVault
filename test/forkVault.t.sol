// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SuperVault} from "../src/Vault.sol";
import {AaveV3Fuse} from "../src/fuses/AaveV3Fuse.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";

contract VaultTest is Test {
    SuperVault public vault;
    AaveV3Fuse public aaveV3Fuse;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public feeRecipient = makeAddr("feeRecipient");

    // Mainnet addresses
    address constant USDC = 0x796Ea11Fa2dD751eD01b53C372fFDB4AAa8f00F9;
    address constant AAVE_ADDRESSES_PROVIDER = 0x5ccF60c7E10547c5389E9cBFf543E5D0Db9F4feC;

    IPool public lendingPool;
    IERC20 public usdcToken;

    uint256 mainnetFork;

    function setUp() public {
        // Create a fork of mainnet
        mainnetFork = vm.createFork("https://node.mainnet.etherlink.com");
        vm.selectFork(mainnetFork);

        // Use the actual USDC token
        usdcToken = IERC20(USDC);

        // Get the Aave lending pool address
        IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER);
        lendingPool = IPool(addressesProvider.getPool());

        // Deploy our contracts
        vault = new SuperVault(USDC, address(feeRecipient), 0, 1000000000, "SuperLendUSDC", "SLUSDC");
        aaveV3Fuse = new AaveV3Fuse(address(lendingPool), USDC, address(addressesProvider), address(vault));

        vault.addFuse(0, address(aaveV3Fuse), "AaveV3Fuse", 1000000000);
        vault.addToDepositQueue(0);

        // Fund our test user with USDC
        deal(USDC, user1, 1000 * 10 ** 6); // 1000 USDC
    }

    function test_deposit() public {
        vm.startPrank(user1);

        uint256 depositAmount = 100 * 10 ** 6; // 100 USDC
        usdcToken.approve(address(vault), depositAmount);

        uint256 initialBalance = usdcToken.balanceOf(user1);
        console.log("initialBalance of user1", initialBalance);
        uint256 initialVaultBalance = usdcToken.balanceOf(address(vault));
        uint256 initialFuseBalance = usdcToken.balanceOf(address(aaveV3Fuse));
        console.log("initialVaultBalance", initialVaultBalance);
        console.log("initialFuseBalance", initialFuseBalance);

        vault.deposit(depositAmount, user1);

        //check the amount of vault shares user1 has
        uint256 userVaultShares = vault.balanceOf(user1);
        console.log("userVaultShares", userVaultShares);

        uint256 finalBalance = usdcToken.balanceOf(user1);
        uint256 finalVaultBalance = usdcToken.balanceOf(address(vault));
        uint256 finalVaultTotalAssets = vault.totalAssets();
        uint256 vaultATokenBalance = aaveV3Fuse.getAssetsOf(address(vault));

        console.log("finalBalance", finalBalance);
        console.log("finalVaultBalance", finalVaultBalance);
        console.log("finalVaultTotalAssets", finalVaultTotalAssets);
        console.log("vaultATokenBalance", vaultATokenBalance);
        // assertEq(finalBalance, initialBalance - depositAmount, "User balance should decrease by deposit amount");
        // assertEq(finalVaultBalance, initialVaultBalance + depositAmount, "Vault balance should increase by deposit amount");

        // Add more assertions to check the state after deposit
        // For example, check the user's balance in the vault, check aToken balance, etc.

        vm.stopPrank();
    }

    // Add more test functions for other scenarios
}

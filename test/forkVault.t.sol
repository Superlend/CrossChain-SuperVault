// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SuperVault} from "../src/Vault.sol";
import {AaveV3Fuse} from "../src/fuses/AaveV3Fuse.sol";
import {CompoundV3Fuse} from "../src/fuses/CompoundV3Fuse.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IComet} from "../src/fuses/CompoundV3Fuse.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";

contract VaultTest is Test {
    SuperVault public vault;
    AaveV3Fuse public aaveV3Fuse;
    CompoundV3Fuse public compoundV3Fuse;
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public feeRecipient = makeAddr("feeRecipient");

    // Mainnet addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant AAVE_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address constant COMET = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address constant COMET_EXT = 0x285617313887d43256F852cAE0Ee4de4b68D45B0;
    // address constant COMET = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    // address constant COMET_EXT = 0x285617313887d43256F852cAE0Ee4de4b68D45B0;

    IPool public lendingPool;
    IERC20 public usdcToken;

    uint256 mainnetFork;

    function setUp() public {
        // Create a fork of mainnet
        // 21100000
        mainnetFork = vm.createFork("https://eth-mainnet.public.blastapi.io");
        // fork at particular block

        vm.selectFork(mainnetFork);

        // Use the actual USDC token
        usdcToken = IERC20(USDC);

        // Get the Aave lending pool address
        IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER);
        lendingPool = IPool(addressesProvider.getPool());

        // Deploy our contracts
        vault = new SuperVault(USDC, address(feeRecipient), owner, 0, 3000000000, "SuperLendUSDC", "SLUSDC");
        aaveV3Fuse = new AaveV3Fuse(address(lendingPool), USDC, address(addressesProvider), address(vault));
        compoundV3Fuse = new CompoundV3Fuse(address(COMET), USDC, address(COMET_EXT), address(vault));

        address aTokenAddress = aaveV3Fuse.getATokenAddress();

        bytes4[] memory aaveSelectors = new bytes4[](1);
        bytes[] memory aaveParams = new bytes[](1);
        address[] memory aaveTargets = new address[](1);

        // First approval: aToken -> AaveV3Fuse
        aaveSelectors[0] = IERC20.approve.selector;
        aaveParams[0] = abi.encode(address(aaveV3Fuse), type(uint256).max);
        aaveTargets[0] = aTokenAddress;

        vm.startPrank(owner);
        vault.addFuse(
            0, // fuseId
            address(aaveV3Fuse), // fuseAddress
            "AaveV3Fuse", // fuseName
            1000000000, // assetCap
            aaveSelectors, // approval selectors
            aaveParams, // approval parameters
            aaveTargets // target contracts
        );

        uint256 aTokenAllowance = IERC20(aTokenAddress).allowance(address(vault), address(aaveV3Fuse));
        console.log("aToken allowance for aave", aTokenAllowance);
        vault.addToDepositQueue(0);

        vault.addToWithdrawQueue(0);

        bytes4[] memory compoundSelectors = new bytes4[](1);
        bytes[] memory compoundParams = new bytes[](1);
        address[] memory compoundTargets = new address[](1);

        compoundSelectors[0] = IComet.approve.selector;
        compoundParams[0] = abi.encode(address(compoundV3Fuse), type(uint256).max);
        compoundTargets[0] = COMET;

        vault.addFuse(
            1, // fuseId
            address(compoundV3Fuse), // fuseAddress
            "CompoundV3Fuse", // fuseName
            1000000000, // assetCap
            compoundSelectors, // approval selectors
            compoundParams, // approval parameters
            compoundTargets // target contracts
        );

        uint256 allowance = IComet(COMET).allowance(address(vault), address(compoundV3Fuse));
        console.log("token allowance for compound", allowance);

        vault.addToDepositQueue(1);
        vault.addToWithdrawQueue(1);
        vm.stopPrank();
        // Fund our test user with USDC
        deal(USDC, user1, 3000 * 10 ** 6); // 3000 USDC
    }

    function test_deposit() public {
        vm.startPrank(user1);

        uint256 depositAmount = 1500 * 10 ** 6; // 100 USDC
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

        // rebalance
        // vault owner calls reallocate
        vm.startPrank(owner);
        SuperVault.ReallocateParams[] memory fromParams = new SuperVault.ReallocateParams[](1);
        fromParams[0] = SuperVault.ReallocateParams({fuseId: 0, assets: 100000000});
        SuperVault.ReallocateParams[] memory toParams = new SuperVault.ReallocateParams[](1);
        toParams[0] = SuperVault.ReallocateParams({fuseId: 1, assets: 100000000});
        vault.reallocate(fromParams, toParams);
        vm.stopPrank();

        uint256 shares = vault.previewWithdraw(1200 * 10 ** 6);
        console.log("shares", shares);
        vault.approve(address(vault), shares);

        vm.startPrank(user1);
        vault.withdraw(1200 * 10 ** 6, user1, user1);

        uint256 balanceAfterWithdraw = usdcToken.balanceOf(user1);
        uint256 vaultBalanceAfterWithdraw = usdcToken.balanceOf(address(vault));
        uint256 vaultTotalAssetsAfterWithdraw = vault.totalAssets();
        uint256 vaultATokenBalanceAfterWithdraw = aaveV3Fuse.getAssetsOf(address(vault));

        console.log("balanceAfterWithdraw", balanceAfterWithdraw);
        console.log("vaultBalanceAfterWithdraw", vaultBalanceAfterWithdraw);
        console.log("vaultTotalAssetsAfterWithdraw", vaultTotalAssetsAfterWithdraw);
        console.log("vaultATokenBalanceAfterWithdraw", vaultATokenBalanceAfterWithdraw);

        vm.stopPrank();
    }

    // Add more test functions for other scenarios
}

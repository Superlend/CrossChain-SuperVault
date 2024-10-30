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
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    address constant AAVE_ADDRESSES_PROVIDER = 0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A;

    IPool public lendingPool;
    IERC20 public usdcToken;

    uint256 mainnetFork;

    function setUp() public {
        // Create a fork of mainnet
        mainnetFork = vm.createFork("https://ethereum-sepolia-rpc.publicnode.com");
        vm.selectFork(mainnetFork);

        // Use the actual USDC token
        usdcToken = IERC20(USDC);

        // Get the Aave lending pool address
        IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER);
        lendingPool = IPool(addressesProvider.getPool());

        // Deploy our contracts
        vault = new SuperVault(USDC, address(feeRecipient), 0, 1000000000, "SuperLendUSDC", "SLUSDC");
        aaveV3Fuse = new AaveV3Fuse(address(lendingPool), USDC, address(addressesProvider), address(vault));

        address aTokenAddress = aaveV3Fuse.getATokenAddress();

        bytes4[] memory selectors = new bytes4[](1);
        bytes[] memory params = new bytes[](1);
        address[] memory targets = new address[](1);

        // First approval: aToken -> AaveV3Fuse
        selectors[0] = IERC20.approve.selector;
        params[0] = abi.encode(address(aaveV3Fuse), type(uint256).max);
        targets[0] = aTokenAddress;

        vault.addFuse(
            0,                    // fuseId
            address(aaveV3Fuse),  // fuseAddress
            "AaveV3Fuse",        // fuseName
            1000000000,          // assetCap
            selectors,           // approval selectors
            params,              // approval parameters
            targets             // target contracts
        );

        // Verify approvals
        uint256 aTokenAllowance = IERC20(aTokenAddress).allowance(address(vault), address(aaveV3Fuse));
        console.log("aToken allowance", aTokenAllowance);
        vault.addToDepositQueue(0);

        vault.addToWithdrawQueue(0);

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

        uint256 shares = vault.previewWithdraw(20 * 10 ** 6);
        console.log("shares", shares);
        vault.approve(address(vault), shares);

        vm.startPrank(user1);
        vault.withdraw(20 * 10 ** 6, user1, user1);

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

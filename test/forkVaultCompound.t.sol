// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {Test} from "forge-std/Test.sol";
// import {console} from "forge-std/console.sol";
// import {SuperVault} from "../src/SuperVault.sol";
// import {AaveV3Wrapper} from "../src/fuses/AaveV3Wrapper.sol";
// import {CompoundV3Wrapper} from "../src/fuses/CompoundV3Wrapper.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IComet} from "../src/fuses/CompoundV3Wrapper.sol";
// import {IPool} from "@aave/contracts/interfaces/IPool.sol";
// import {IPoolAddressesProvider} from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";

// contract VaultTest is Test {
//     SuperVault public vault;
//     CompoundV3Wrapper public compoundV3Wrapper;
//     address public owner = makeAddr("owner");
//     address public user1 = makeAddr("user1");
//     address public feeRecipient = makeAddr("feeRecipient");

//     // Mainnet addresses
//     address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
//     address constant COMET = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
//     address constant COMET_EXT = 0x285617313887d43256F852cAE0Ee4de4b68D45B0;
//     // address constant COMET_PROXY = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;

//     IERC20 public usdcToken;

//     uint256 mainnetFork;

//     function setUp() public {
//         // Create a fork of mainnet
//         mainnetFork = vm.createFork("https://ethereum.blockpi.network/v1/rpc/public");
//         vm.selectFork(mainnetFork);

//         // Use the actual USDC token
//         usdcToken = IERC20(USDC);

//         // Deploy our contracts
//         vault = new SuperVault(USDC, address(feeRecipient), owner, 0, 1000000000, "SuperLendUSDC", "SLUSDC");
//         // Add CompoundV3Fuse
//         compoundV3Wrapper = new CompoundV3Wrapper(
//             address(COMET), USDC, address(COMET_EXT), address(vault), address(0x123), address(0x456), owner
//         );

//         bytes4[] memory selectors = new bytes4[](1);
//         bytes[] memory params = new bytes[](1);
//         address[] memory targets = new address[](1);

//         // vm.startPrank(address(user1));
//         // bool permission = IComet(COMET).hasPermission(address(vault), address(compoundV3Fuse));
//         // console.log("permission", permission);

//         // implement similar approval parameter as above for CompoundV3Fuse
//         selectors[0] = IComet.approve.selector;
//         params[0] = abi.encode(address(compoundV3Wrapper), type(uint256).max);
//         targets[0] = COMET;

//         // First approval: aToken -> AaveV3Fuse
//         // selectors[0] = IComet.approve.selector;
//         // params[0] = abi.encode(address(compoundV3Fuse), type(uint256).max);
//         // targets[0] = COMET;

//         vm.startPrank(owner);
//         vault.addFuse(
//             0, // fuseId
//             address(compoundV3Wrapper), // fuseAddress
//             "CompoundV3Wrapper", // fuseName
//             1, // sourceChainId
//             1, // lzEid
//             1000000000, // assetCap
//             selectors, // approval selectors
//             params, // approval parameters
//             targets // target contracts
//         );

//         // Verify approvals
//         uint256 allowance = IComet(COMET).allowance(address(vault), address(compoundV3Wrapper));
//         console.log("token allowance", allowance);
//         vault.addToDepositQueue(0);
//         vault.addToWithdrawQueue(0);

//         vm.stopPrank();

//         // Fund our test user with USDC
//         deal(USDC, user1, 1000 * 10 ** 6); // 1000 USDC
//     }

//     function test_deposit_compound() public {
//         vm.startPrank(user1);

//         uint256 depositAmount = 100 * 10 ** 6; // 100 USDC
//         usdcToken.approve(address(vault), depositAmount);

//         uint256 initialBalance = usdcToken.balanceOf(user1);
//         console.log("initialBalance of user1", initialBalance);
//         uint256 initialVaultBalance = usdcToken.balanceOf(address(vault));
//         uint256 initialFuseBalance = usdcToken.balanceOf(address(compoundV3Wrapper));
//         console.log("initialVaultBalance", initialVaultBalance);
//         console.log("initialFuseBalance", initialFuseBalance);

//         vault.deposit(depositAmount, user1);

//         //check the amount of vault shares user1 has
//         uint256 userVaultShares = vault.balanceOf(user1);
//         console.log("userVaultShares", userVaultShares);

//         uint256 finalBalance = usdcToken.balanceOf(user1);
//         uint256 finalVaultBalance = usdcToken.balanceOf(address(vault));
//         uint256 finalVaultTotalAssets = vault.totalAssets();
//         uint256 vaultCTokenBalance = compoundV3Wrapper.getAssetsOf(address(vault));

//         console.log("finalBalance", finalBalance);
//         console.log("finalVaultBalance", finalVaultBalance);
//         console.log("finalVaultTotalAssets", finalVaultTotalAssets);
//         console.log("vaultCTokenBalance", vaultCTokenBalance);

//         // Start prank as vault and give approval to CompoundV3Fuse
//         // vm.startPrank(address(vault));
//         // IComet(COMET).approve(address(compoundV3Fuse), type(uint256).max);
//         // vm.stopPrank();

//         vm.startPrank(address(user1));
//         bool permission = IComet(COMET).hasPermission(address(vault), address(compoundV3Wrapper));
//         console.log("permission", permission);

//         uint256 shares = vault.previewWithdraw(20 * 10 ** 6);
//         console.log("shares", shares);
//         vault.approve(address(vault), shares);

//         vault.withdraw(20 * 10 ** 6, user1, user1);

//         uint256 balanceAfterWithdraw = usdcToken.balanceOf(user1);
//         uint256 vaultBalanceAfterWithdraw = usdcToken.balanceOf(address(vault));
//         uint256 vaultTotalAssetsAfterWithdraw = vault.totalAssets();
//         uint256 vaultCTokenBalanceAfterWithdraw = compoundV3Wrapper.getAssetsOf(address(vault));

//         console.log("balanceAfterWithdraw", balanceAfterWithdraw);
//         console.log("vaultBalanceAfterWithdraw", vaultBalanceAfterWithdraw);
//         console.log("vaultTotalAssetsAfterWithdraw", vaultTotalAssetsAfterWithdraw);
//         console.log("vaultCTokenBalanceAfterWithdraw", vaultCTokenBalanceAfterWithdraw);

//         vm.stopPrank();
//     }

//     // Add more test functions for other scenarios
// }

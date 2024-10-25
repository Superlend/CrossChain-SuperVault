// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
// vault test cases

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SuperVault} from "../src/Vault.sol";
import {AaveV3Fuse} from "../src/fuses/AaveV3Fuse.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract VaultTest is Test {
    SuperVault public vault;
    AaveV3Fuse public aaveV3Fuse;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public feeRecipient = makeAddr("feeRecipient");

    MockERC20 public usdc;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);

        vault = new SuperVault(address(usdc), address(feeRecipient), 0, 100000000, "SuperLendUSDC", "SLUSDC");

        // setup creation of AaveV3Fuse
        address mockLendingPool = makeAddr("mockLendingPool");
        address mockIncentivesController = makeAddr("mockIncentivesController");
        aaveV3Fuse = new AaveV3Fuse(mockLendingPool, address(usdc), mockIncentivesController);
    }

    function test_createFuse() public {
        vault.addFuse(0, address(aaveV3Fuse), "AaveV3Fuse");
    }

    function test_addToDepositQueue() public {
        vault.addFuse(0, address(aaveV3Fuse), "AaveV3Fuse");
        vault.addToDepositQueue(0);
    }

    function test_removeFromDepositQueue() public {
        vault.addFuse(0, address(aaveV3Fuse), "AaveV3Fuse");
        vault.addToDepositQueue(0);
        vault.removeFromDepositQueue(0);
    }

    function test_deposit() public {
        vault.addFuse(0, address(aaveV3Fuse), "AaveV3Fuse");
        vault.addToDepositQueue(0);

        vm.startPrank(user1);
        usdc.mint(user1, 100);
        usdc.approve(address(vault), 100);

        // Add these lines for debugging
        console.log("USDC balance of user1 before deposit:", usdc.balanceOf(user1));
        console.log("USDC allowance for vault:", usdc.allowance(user1, address(vault)));

        try vault.deposit(100, user1) {
            console.log("Deposit successful");
        } catch Error(string memory reason) {
            console.log("Deposit failed with reason:", reason);
        } catch {
            console.log("Deposit failed with low-level error");
        }

        console.log("USDC balance of user1 after deposit attempt:", usdc.balanceOf(user1));
        console.log("USDC balance of vault after deposit attempt:", usdc.balanceOf(address(vault)));

        vm.stopPrank();
    }
}

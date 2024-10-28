// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/contracts/protocol/libraries/types/DataTypes.sol";

contract AaveV3Fuse {
    using SafeERC20 for IERC20;

    IPool public lendingPool;
    address public asset;
    address public poolAddressesProvider;
    address public vault;

    constructor(address _lendingPool, address _asset, address _poolAddressesProvider, address _vault) {
        lendingPool = IPool(_lendingPool);
        asset = _asset;
        poolAddressesProvider = _poolAddressesProvider;
        vault = _vault;
    }

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault can call this function");
        _;
    }

    function getLiquidityOf() external view returns (uint256) {
        DataTypes.ReserveData memory reserveData = (lendingPool).getReserveData(asset);
        uint256 availableLiquidity = IERC20(asset).balanceOf(address(reserveData.aTokenAddress));
        return availableLiquidity;
    }

    function deposit(uint256 amount) external onlyVault {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(lendingPool), amount);
        lendingPool.supply(asset, amount, msg.sender, 0);
        console.log("deposit has been made", amount);
    }

    function withdraw(uint256 amount) external onlyVault {
        uint256 withdrawnAmount = lendingPool.withdraw(asset, amount, vault);
        require(withdrawnAmount == amount, "Withdrawn amount mismatch");
    }

    function getAssetsOf(address account) external view returns (uint256) {
        DataTypes.ReserveData memory reserveData = (lendingPool).getReserveData(asset);
        uint256 balanceOf = IERC20(reserveData.aTokenAddress).balanceOf(account);
        console.log("balanceOf was called", balanceOf);
        return balanceOf;
    }
}

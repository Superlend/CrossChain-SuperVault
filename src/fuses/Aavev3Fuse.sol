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

    function getATokenAddress() external view returns (address) {
        DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(asset);
        return reserveData.aTokenAddress;
    }

    function deposit(uint256 amount) external onlyVault {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(lendingPool), amount);
        lendingPool.supply(asset, amount, msg.sender, 0);
    }

    function withdraw(uint256 amount) external onlyVault {
    // Get the aToken address
    DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(asset);
    address aToken = reserveData.aTokenAddress;

    IERC20(aToken).approve(address(this), type(uint256).max);

    // pull the aToken from the vault
    IERC20(aToken).transferFrom(vault, address(this), amount);
    
    try lendingPool.withdraw(asset, amount, msg.sender) returns (uint256 withdrawnAmount) {
        require(withdrawnAmount == amount, "Withdrawn amount mismatch");
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("Withdraw failed");
        }
    }   

    function getAssetsOf(address account) external view returns (uint256) {
        DataTypes.ReserveData memory reserveData = (lendingPool).getReserveData(asset);
        uint256 balanceOf = IERC20(reserveData.aTokenAddress).balanceOf(account);
        return balanceOf;
    }
}

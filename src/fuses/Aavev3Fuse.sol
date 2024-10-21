// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Define the interface for Aave V3's LendingPool
interface IAaveV3LendingPool {
    struct ReserveData {
        uint256 availableLiquidity;
    }
    // other fields omitted for brevity

    function getReserveData(address asset) external view returns (ReserveData memory);
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

contract AaveV3Fuse {
    using SafeERC20 for IERC20;

    IAaveV3LendingPool public lendingPool;
    address public asset;

    constructor(address _lendingPool, address _asset) {
        lendingPool = IAaveV3LendingPool(_lendingPool);
        asset = _asset;
    }

    function getLiquidityOf() external view returns (uint256) {
        IAaveV3LendingPool.ReserveData memory reserveData = lendingPool.getReserveData(asset);
        return reserveData.availableLiquidity;
    }

    function deposit(uint256 amount) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(lendingPool), amount);
        lendingPool.supply(asset, amount, address(this), 0);
    }

    function withdraw(uint256 amount) external {
        uint256 withdrawnAmount = lendingPool.withdraw(asset, amount, msg.sender);
        require(withdrawnAmount == amount, "Withdrawn amount mismatch");
    }

    function getAssetsOf(address account) external view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Define the interface for Compound V3's Comet contract
interface IComet {
    // function supplyTo(address dst, address asset, uint amount)
    function supplyTo(address dst, address asset, uint256 amount) external;
    function withdrawFrom(address src, address to, address asset, uint256 amount) external;
    function collateralBalanceOf(address account, address asset) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allow(address manager, bool isAllowed_) external;
    function hasPermission(address owner, address manager) external view returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function getReserves() external view returns (uint256);
}

contract CompoundV3Fuse {
    using SafeERC20 for IERC20;

    IComet public comet;
    IComet public cometExt;
    address public asset;
    address public vault;

    constructor(address _comet, address _asset, address _cometExt, address _vault) {
        comet = IComet(_comet);
        asset = _asset;
        cometExt = IComet(_cometExt);
        vault = _vault;
    }

    function getLiquidityOf() external view returns (uint256) {
        return comet.getReserves();
    }

    function deposit(uint256 amount) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(comet), amount);
        comet.supplyTo(vault, asset, amount);
        console.log("Compound deposit called", amount);
    }

    function withdraw(uint256 amount) external {
        console.log("Withdrawing", amount, "from", vault);
        comet.withdrawFrom(vault, vault, asset, amount);
        console.log("Compound withdraw called", amount);
        // IERC20(asset).safeTransfer(msg.sender, amount);
    }

    function getAssetsOf(address account) external view returns (uint256) {
        return comet.balanceOf(account);
    }
}

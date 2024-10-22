// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Define the interface for Compound V3's Comet contract
interface IComet {
    function supply(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;
    function collateralBalanceOf(address account, address asset) external view returns (uint256);
    function getReserves() external view returns (uint256);
}

contract CompoundV3Fuse {
    using SafeERC20 for IERC20;

    IComet public comet;
    IComet public cometExt;
    address public asset;

    constructor(address _comet, address _asset, address _cometExt) {
        comet = IComet(_comet);
        asset = _asset;
        cometExt = IComet(_cometExt);
    }

    function getLiquidityOf() external view returns (uint256) {
        return comet.getReserves();
    }

    function deposit(uint256 amount) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(comet), amount);
        comet.supply(asset, amount);
    }

    function withdraw(uint256 amount) external {
        comet.withdraw(asset, amount);
        IERC20(asset).safeTransfer(msg.sender, amount);
    }

    function getAssetsOf(address account) external view returns (uint256) {
        return cometExt.collateralBalanceOf(account, asset);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFuse {
    // Define the function signature for getAssetsOf
    function getAssetsOf(address account) external view returns (uint256);

    // You can add other function signatures that the Fuse contract should implement
    // function anotherFunction(uint256 param) external returns (bool);

    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getLiquidityOf() external view returns (uint256);
}

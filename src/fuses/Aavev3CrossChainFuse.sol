// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IStargate } from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import { MessagingFee, OFTReceipt, SendParam } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/contracts/protocol/libraries/types/DataTypes.sol";

contract AaveV3CrossChainFuse {
    using SafeERC20 for IERC20;

    IPool public lendingPool;
    address public asset;
    address public poolAddressesProvider;
    address public vault;
    address public stargate;
    address public composer;

    constructor(address _lendingPool, address _asset, address _poolAddressesProvider, address _vault, address _stargate, address _composer) {
        lendingPool = IPool(_lendingPool);
        asset = _asset;
        poolAddressesProvider = _poolAddressesProvider;
        vault = _vault;
        stargate = _stargate;
        composer = _composer;
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
        IERC20(asset).approve(address(stargate), amount);
        (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) = prepareTakeTaxiAndAMMSwap(address(stargate), 102, amount, address(composer), "");
        IStargate(stargate).sendToken{ value: valueToSend }(sendParam, messagingFee, msg.sender);
        console.log("aave deposit called", amount);
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
            console.log("aave withdraw called", amount);
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("Withdraw failed");
        }
    }

    function prepareTakeTaxiAndAMMSwap(
        address _stargate,
        uint32 _dstEid,
        uint256 _amount,
        address _composer,
        bytes memory _composeMsg
    ) internal view returns (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) {
        bytes memory extraOptions = _composeMsg.length > 0 
            ? bytes("")
            : bytes("");

        sendParam = SendParam({
            dstEid: _dstEid,
            to: addressToBytes32(_composer),
            amountLD: _amount,
            minAmountLD: _amount,
            extraOptions: extraOptions,
            composeMsg: _composeMsg,
            oftCmd: ""
        });

        (, , OFTReceipt memory receipt) = IStargate(_stargate).quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;

        messagingFee = IStargate(_stargate).quoteSend(sendParam, false);
        valueToSend = messagingFee.nativeFee;

        if (IStargate(_stargate).token() == address(0x0)) {
            valueToSend += sendParam.amountLD;
        }
    }

    function getAssetsOf(address account) external view returns (uint256) {
        DataTypes.ReserveData memory reserveData = (lendingPool).getReserveData(asset);
        uint256 balanceOf = IERC20(reserveData.aTokenAddress).balanceOf(account);
        return balanceOf;
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

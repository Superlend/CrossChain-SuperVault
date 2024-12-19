// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStargate} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import {MessagingFee, OFTReceipt, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

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

contract CompoundV3Fuse is ILayerZeroComposer {
    using SafeERC20 for IERC20;

    IComet public comet;
    IComet public cometExt;
    address public asset;
    address public vault;
    address public immutable stargate;
    address public immutable endpoint;

    event ReceivedOnDestination(address token);

    constructor(
        address _comet,
        address _asset,
        address _cometExt,
        address _vault,
        address _endpoint,
        address _stargate
    ) {
        comet = IComet(_comet);
        asset = _asset;
        cometExt = IComet(_cometExt);
        vault = _vault;
        endpoint = _endpoint;
        stargate = _stargate;
    }

    function getLiquidityOf() external view returns (uint256) {
        return comet.getReserves();
    }

    function deposit(uint256 amount) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(comet), amount);
        comet.supplyTo(address(this), asset, amount);
        console.log("Compound deposit called", amount);
    }

    function withdraw(uint256 amount) external {
        console.log("Withdrawing", amount, "from", vault);
        comet.withdrawFrom(address(this), vault, asset, amount);
        console.log("Compound withdraw called", amount);
        // IERC20(asset).safeTransfer(msg.sender, amount);
    }

    function withdrawCrossChain(uint256 amount, uint32 dstEid, address composer) external {
        comet.withdrawFrom(address(this), address(this), asset, amount);
        bytes memory _composeMsg = abi.encode("deposit", amount);
        (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) =
            prepareTakeTaxiAndSpokeCall(address(stargate), dstEid, amount, address(composer), _composeMsg);
        IStargate(stargate).sendToken{value: valueToSend}(sendParam, messagingFee, msg.sender);
    }

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        require(_from == stargate, "!stargate");
        require(msg.sender == endpoint, "!endpoint");

        bytes memory _composeMessage = OFTComposeMsgCodec.composeMsg(_message);

        (string memory _actionType, uint256 _amount) = abi.decode(_composeMessage, (string, uint256));

        if (keccak256(abi.encodePacked(_actionType)) == keccak256(abi.encodePacked("deposit"))) {
            IERC20(asset).approve(address(comet), _amount);
            comet.supplyTo(address(this), asset, _amount);
        }

        emit ReceivedOnDestination(asset);
    }

    function prepareTakeTaxiAndSpokeCall(
        address _stargate,
        uint32 _dstEid,
        uint256 _amount,
        address _composer,
        bytes memory _composeMsg
    ) internal view returns (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) {
        bytes memory extraOptions = _composeMsg.length > 0 ? bytes("") : bytes("");

        sendParam = SendParam({
            dstEid: _dstEid,
            to: addressToBytes32(_composer),
            amountLD: _amount,
            minAmountLD: _amount,
            extraOptions: extraOptions,
            composeMsg: _composeMsg,
            oftCmd: ""
        });

        (,, OFTReceipt memory receipt) = IStargate(_stargate).quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;

        messagingFee = IStargate(_stargate).quoteSend(sendParam, false);
        valueToSend = messagingFee.nativeFee;

        if (IStargate(_stargate).token() == address(0x0)) {
            valueToSend += sendParam.amountLD;
        }
    }

    function getAssetsOf(address account) external view returns (uint256) {
        return comet.balanceOf(account);
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

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

using OptionsBuilder for bytes;

contract CompoundV3Wrapper is ILayerZeroComposer {
    using SafeERC20 for IERC20;

    IComet public comet;
    IComet public cometExt;
    address public asset;
    address public vault;
    address public immutable stargate;
    address public immutable endpoint;
    address public owner;

    struct protocolInfo {
        uint32 dstEid;
        address composer;
    }

    mapping(string => protocolInfo) public protocolToDstEidAndComposer;

    event ComposeAcknowledged(
        address indexed _from, bytes32 indexed _guid, bytes _message, address _executor, bytes _extraData
    );

    constructor(
        address _comet,
        address _asset,
        address _cometExt,
        address _vault,
        address _endpoint,
        address _stargate,
        address _owner
    ) {
        comet = IComet(_comet);
        asset = _asset;
        cometExt = IComet(_cometExt);
        vault = _vault;
        endpoint = _endpoint;
        stargate = _stargate;
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault can call this function");
        _;
    }

    function getLiquidityOf() external view returns (uint256) {
        return comet.getReserves();
    }

    function deposit(uint256 amount) external onlyVault {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(comet), amount);
        comet.supplyTo(address(this), asset, amount);
        console.log("Compound deposit called", amount);
    }

    function withdraw(uint256 amount) external onlyVault {
        console.log("Withdrawing", amount, "from", vault);
        comet.withdrawFrom(address(this), vault, asset, amount);
        console.log("Compound withdraw called", amount);
        // IERC20(asset).safeTransfer(msg.sender, amount);
    }

    function setProtocolInfo(string memory _protocolName, uint32 _dstEid, address _composer) external onlyOwner {
        protocolToDstEidAndComposer[_protocolName] = protocolInfo(_dstEid, _composer);
    }

    function withdrawCrossChain(uint256 amount, string memory _protocolName) external {
        protocolInfo memory _protocolInfo = protocolToDstEidAndComposer[_protocolName];
        comet.withdrawFrom(address(this), address(this), asset, amount);
        bytes memory _composeMsg = abi.encode(amount);
        (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) =
            prepareTakeTaxi(address(stargate), _protocolInfo.dstEid, amount, _protocolInfo.composer, _composeMsg);
        IERC20(asset).approve(address(stargate), amount);
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

        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        // bytes memory _composeMessage = OFTComposeMsgCodec.composeMsg(_message);
        // (uint256 _amount) = abi.decode(_composeMessage, (uint256));
        IERC20(asset).approve(address(comet), amountLD);
        comet.supplyTo(address(this), asset, amountLD);

        emit ComposeAcknowledged(_from, _guid, _message, _executor, _extraData);
    }

    function prepareTakeTaxi(
        address _stargate,
        uint32 _dstEid,
        uint256 _amount,
        address _composer,
        bytes memory _composeMsg
    ) public view returns (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) {
        bytes memory extraOptions = _composeMsg.length > 0
            ? OptionsBuilder.newOptions().addExecutorLzComposeOption(0, 200_000, 0) // compose gas limit
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

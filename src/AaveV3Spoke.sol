// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {MessagingFee, SendParam, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {IStargate} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";

using OptionsBuilder for bytes;

contract AaveV3Spoke is ILayerZeroComposer, Ownable(msg.sender) {
    address public immutable endpoint;
    address public immutable stargate;
    address public immutable assetAddress;
    IPool public immutable poolAddress;

    struct protocolInfo {
        uint32 dstEid;
        address composer;
    }

    mapping(string => protocolInfo) public protocolToDstEidAndComposer;

    event ComposeAcknowledged(
        address indexed _from, bytes32 indexed _guid, bytes _message, address _executor, bytes _extraData
    );

    constructor(address _endpoint, address _stargate, address _assetAddress, address _poolAddress) {
        poolAddress = IPool(_poolAddress);
        endpoint = _endpoint;
        stargate = _stargate;
        assetAddress = _assetAddress;
    }

    function setProtocolInfo(string memory _protocolName, uint32 _dstEid, address _composer) external onlyOwner {
        protocolToDstEidAndComposer[_protocolName] = protocolInfo(_dstEid, _composer);
    }

    function withdrawCrossChain(uint256 amount, string memory _protocolName) external payable onlyOwner {
        protocolInfo memory _protocolInfo = protocolToDstEidAndComposer[_protocolName];
        try poolAddress.withdraw(assetAddress, amount, address(this)) returns (uint256 withdrawnAmount) {
            require(withdrawnAmount == amount, "Withdrawn amount mismatch");
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("Withdraw failed");
        }
        bytes memory _composeMsg = abi.encode(amount);
        (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) = prepareTakeTaxi(
            address(stargate), _protocolInfo.dstEid, amount, address(_protocolInfo.composer), _composeMsg
        );
        IERC20(assetAddress).approve(stargate, amount);
        IStargate(stargate).sendToken{value: valueToSend}(sendParam, messagingFee, msg.sender);
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

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
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
        bytes memory _composeMessage = OFTComposeMsgCodec.composeMsg(_message);

        (uint256 _amount) = abi.decode(_composeMessage, (uint256));

        bool successApprove = IERC20(assetAddress).approve(address(poolAddress), amountLD);
        if (!successApprove) {
            revert("Approve failed");
        }
        IPool(poolAddress).supply(assetAddress, amountLD, address(this), 0);

        emit ComposeAcknowledged(_from, _guid, _message, _executor, _extraData);
    }

    fallback() external payable {}
    receive() external payable {}
}

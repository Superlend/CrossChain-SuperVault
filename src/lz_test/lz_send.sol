// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStargate, Ticket} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import {MessagingFee, OFTReceipt, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract lz_send {
    using OptionsBuilder for bytes;

    function send(
        address _stargate,
        uint32 _dstEid,
        uint256 _amount,
        address _token,
        address _assetOnDestination,
        address _poolAddress,
        address _composer
    ) external payable {
        bytes memory _composeMsg = abi.encode(_assetOnDestination, _poolAddress);
        (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee) =
            prepareTakeTaxi(address(_stargate), _dstEid, _amount, address(_composer), _composeMsg);
        IERC20(_token).approve(address(_stargate), _amount);
        IStargate(_stargate).sendToken{value: valueToSend}(sendParam, messagingFee, msg.sender);
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

        IStargate stargate = IStargate(_stargate);

        (,, OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;

        messagingFee = stargate.quoteSend(sendParam, false);
        valueToSend = messagingFee.nativeFee;

        if (stargate.token() == address(0x0)) {
            valueToSend += sendParam.amountLD;
        }
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

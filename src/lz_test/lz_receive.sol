// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

contract lz_receive is ILayerZeroComposer {
    address public immutable endpoint;
    address public immutable stargate;

    event ReceivedOnDestination(address token);
    event ComposeAcknowledged(
        address indexed _from, bytes32 indexed _guid, bytes _message, address _executor, bytes _extraData
    );

    constructor(address _endpoint, address _stargate) {
        endpoint = _endpoint;
        stargate = _stargate;
    }

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        // require(_from == stargate, "!stargate");
        // require(msg.sender == endpoint, "!endpoint");

        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory _composeMessage = OFTComposeMsgCodec.composeMsg(_message);

        (address _tokenReceiver, uint256 _amount, address _assetOnDestination) =
            abi.decode(_composeMessage, (address, uint256, address));

        bool success = IERC20(_assetOnDestination).transfer(address(_tokenReceiver), amountLD);
        if (!success) {
            revert("Transfer failed");
        }

        emit ReceivedOnDestination(_assetOnDestination);
        emit ComposeAcknowledged(_from, _guid, _message, _executor, _extraData);
    }

    fallback() external payable {}
    receive() external payable {}
}

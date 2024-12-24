// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

contract lz_receive is ILayerZeroComposer {
    address public immutable endpoint;
    address public immutable stargate;

    event ReceivedOnDestination(address token);
    event ComposeAcknowledged(
        address indexed _from, bytes32 indexed _guid, bytes _message, address _executor, bytes _extraData
    );
    event ApproveSuccess(address indexed _assetOnDestination, address indexed _poolAddress, uint256 amountLD);
    event BalanceCheck(address indexed _assetOnDestination, uint256 balance, uint256 amountLD);

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

        (address _assetOnDestination, address _poolAddress) = abi.decode(_composeMessage, (address, address));

        bool successApprove = IERC20(_assetOnDestination).approve(address(_poolAddress), amountLD);
        if (!successApprove) {
            revert("Approve failed");
        }
        IPool(_poolAddress).supply(_assetOnDestination, amountLD, address(this), 0);

        emit ComposeAcknowledged(_from, _guid, _message, _executor, _extraData);
    }

    fallback() external payable {}
    receive() external payable {}
}

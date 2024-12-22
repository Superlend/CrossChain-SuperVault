// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";

contract ComposerReceiverAMM is ILayerZeroComposer, Ownable(msg.sender) {
    address public immutable endpoint;
    address public immutable stargate;
    address public immutable assetAddress;
    // make address of fuse as Ipool
    mapping(string => IPool) public fuseToAddress;

    event ComposeAcknowledged(
        address indexed _from, bytes32 indexed _guid, bytes _message, address _executor, bytes _extraData
    );

    constructor(
        address _endpoint,
        address _stargate,
        address _assetAddress,
        address _fuseToAddress,
        string memory _fuseName
    ) {
        fuseToAddress[_fuseName] = IPool(_fuseToAddress);
        endpoint = _endpoint;
        stargate = _stargate;
        assetAddress = _assetAddress;
    }

    function setFuseToAddress(string memory _fuseName, address _fuseToAddress) public onlyOwner {
        fuseToAddress[_fuseName] = IPool(_fuseToAddress);
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

        bytes memory _composeMessage = OFTComposeMsgCodec.composeMsg(_message);

        (string memory _actionType, uint256 _amount, string memory _fuseType) =
            abi.decode(_composeMessage, (string, uint256, string));

        IPool _fuseToAddress = fuseToAddress[_fuseType];

        if (keccak256(abi.encodePacked(_actionType)) == keccak256(abi.encodePacked("deposit"))) {
            IERC20(assetAddress).approve(address(_fuseToAddress), _amount);
            IPool(_fuseToAddress).supply(assetAddress, _amount, msg.sender, 0);
        } else if (keccak256(abi.encodePacked(_actionType)) == keccak256(abi.encodePacked("withdraw"))) {
            IPool(_fuseToAddress).withdraw(assetAddress, _amount, msg.sender);
        }

        emit ComposeAcknowledged(_from, _guid, _message, _executor, _extraData);
    }

    fallback() external payable {}
    receive() external payable {}
}

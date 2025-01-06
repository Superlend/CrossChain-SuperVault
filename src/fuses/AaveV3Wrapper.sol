// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStargate} from "@stargatefinance/stg-evm-v2/src/interfaces/IStargate.sol";
import {MessagingFee, OFTReceipt, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/contracts/protocol/libraries/types/DataTypes.sol";

using OptionsBuilder for bytes;

contract AaveV3Wrapper is ILayerZeroComposer {
    using SafeERC20 for IERC20;

    IPool public lendingPool;
    address public asset;
    address public poolAddressesProvider;
    address public vault;
    address public immutable endpoint;
    address public immutable stargate;
    address public immutable owner;

    struct protocolInfo {
        uint32 dstEid;
        address composer;
    }

    mapping(string => protocolInfo) public protocolToDstEidAndComposer;

    event ComposeAcknowledged(
        address indexed _from, bytes32 indexed _guid, bytes _message, address _executor, bytes _extraData
    );

    constructor(
        address _lendingPool,
        address _asset,
        address _poolAddressesProvider,
        address _vault,
        address _endpoint,
        address _stargate,
        address _owner
    ) {
        lendingPool = IPool(_lendingPool);
        asset = _asset;
        poolAddressesProvider = _poolAddressesProvider;
        vault = _vault;
        endpoint = _endpoint;
        stargate = _stargate;
        owner = _owner;
    }

    fallback() external payable {}
    receive() external payable {}

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault can call this function");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function setProtocolInfo(string memory _protocolName, uint32 _dstEid, address _composer) external onlyOwner {
        protocolToDstEidAndComposer[_protocolName] = protocolInfo(_dstEid, _composer);
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
        IERC20(asset).approve(address(lendingPool), amount);
        lendingPool.supply(asset, amount, address(this), 0);
        console.log("aave deposit called", amount);
    }

    function withdraw(uint256 amount) external onlyVault {
        try lendingPool.withdraw(asset, amount, msg.sender) returns (uint256 withdrawnAmount) {
            require(withdrawnAmount == amount, "Withdrawn amount mismatch");
            console.log("aave withdraw called", amount);
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("Withdraw failed");
        }
    }

    function withdrawCrossChain(uint256 amount, string memory _protocolName) external payable onlyOwner {
        protocolInfo memory _protocolInfo = protocolToDstEidAndComposer[_protocolName];
        try lendingPool.withdraw(asset, amount, address(this)) returns (uint256 withdrawnAmount) {
            require(withdrawnAmount == amount, "Withdrawn amount mismatch");
            console.log("aave withdraw called", amount);
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("Withdraw failed");
        }
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
        bytes memory _composeMessage = OFTComposeMsgCodec.composeMsg(_message);

        (uint256 _amount) = abi.decode(_composeMessage, (uint256));

        bool successApprove = IERC20(asset).approve(address(lendingPool), amountLD);
        if (!successApprove) {
            revert("Approve failed");
        }
        IPool(lendingPool).supply(asset, amountLD, address(this), 0);

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
        DataTypes.ReserveData memory reserveData = (lendingPool).getReserveData(asset);
        uint256 balanceOf = IERC20(reserveData.aTokenAddress).balanceOf(account);
        return balanceOf;
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

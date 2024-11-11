// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IFuse.sol";

contract SuperVault is Ownable, ERC20, Pausable, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant TIMELOCK_DURATION = 24 * 60 * 60;
    uint256 public constant TIMELOCK_DEADLINE = 3 * 24 * 60 * 60;
    uint256 internal constant WAD = 1e18;

    uint8 internal immutable DECIMALS;
    IERC20 internal immutable ASSET;

    uint256 public fee;
    uint256 public lastTotalAssets;
    uint256 public superPoolCap;
    address public feeRecipient;
    uint256[] public depositQueue;
    uint256[] public withdrawQueue;

    struct Fuse {
        string name;
        address fuseAddress;
    }

    struct PendingFeeUpdate {
        uint256 fee;
        uint256 validAfter;
    }

    mapping(uint256 fuseId => Fuse) public fuseList;
    mapping(uint256 fuseId => uint256 cap) public fuseCapFor;

    PendingFeeUpdate pendingFeeUpdate;

    event DepositQueueUpdated(uint256 fuseId);
    event WithdrawQueueUpdated(uint256 fuseId);
    event FuseAdded(uint256 fuseId, string fuseName, address fuseAddress);
    event FuseRemoved(uint256 fuseId);
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );
    event FuseCapSet(uint256 fuseId, uint256 cap);
    event SuperVaultFeeUpdateRequested(uint256 fee);
    event SuperVaultFeeUpdated(uint256 fee);
    event SuperVaultFeeUpdateRejected(uint256 fee);
    event SuperVaultFeeRecipientUpdated(address feeRecipient);

    error SuperVault_FeeTooHigh();
    error SuperVault_ZeroShareDeposit(address supervault, uint256 assets);
    error SuperVault_NotEnoughLiquidity(address superVault);
    error SuperVault_ZeroAssetMint(address supervault, uint256 shares);
    error SuperVault_ZeroShareWithdraw(address supervault, uint256 assets);
    error SuperVault_ZeroAssetRedeem(address superpool, uint256 shares);
    error SuperFuse_FuseNotInQueue(uint256 fuseId);
    error SuperVault_ZeroPoolCap(uint256 fuseId);
    error SuperFuse_QueueLengthMismatch(address superFuse);
    error SuperVault_TimelockPending(uint256 currentTimestamp, uint256 validAfter);
    error SuperVault_TimelockExpired(uint256 currentTimestamp, uint256 validAfter);
    error SuperVault_ZeroFeeRecipient();
    error SuperVault_NoFeeUpdate();
    error SuperVault_ReorderQueueLength();
    error SuperVault_InvalidQueueReorder();
    error SuperVault_SuperVaultCapReached();

    constructor(
        address asset_,
        address feeRecipient_,
        address owner_,
        uint256 fee_,
        uint256 superPoolCap_,
        string memory name_,
        string memory symbol_
    ) Ownable(owner_) ERC20(name_, symbol_) {
        ASSET = IERC20(asset_);
        DECIMALS = _tryGetAssetDecimals(ASSET);
        superPoolCap = superPoolCap_;
        if (fee > 1e18) revert SuperVault_FeeTooHigh();
        fee = fee_;
        feeRecipient = feeRecipient_;
    }

    function togglePause() external onlyOwner {
        if (Pausable.paused()) Pausable._unpause();
        else Pausable._pause();
    }

    function decimals() public view override returns (uint8) {
        return DECIMALS;
    }

    function asset() public view returns (address) {
        return address(ASSET);
    }

    function convertToShares(uint256 assets) public view virtual returns (uint256 shares) {
        (uint256 feeShares, uint256 newTotalAssets) = simulateAccrue();
        return _convertToShares(assets, newTotalAssets, totalSupply() + feeShares, Math.Rounding.Floor);
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256 assets) {
        (uint256 feeShares, uint256 newTotalAssets) = simulateAccrue();
        return _convertToAssets(shares, newTotalAssets, totalSupply() + feeShares, Math.Rounding.Floor);
    }

    function maxDeposit(address) public view returns (uint256) {
        return _maxDeposit(totalAssets());
    }

    function maxMint(address) public view returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = simulateAccrue();
        return _convertToShares(
            _maxDeposit(newTotalAssets), newTotalAssets, totalSupply() + feeShares, Math.Rounding.Floor
        );
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = simulateAccrue();
        return _maxWithdraw(owner, newTotalAssets, totalSupply() + feeShares);
    }

    function maxRedeem(address owner) public view returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = simulateAccrue();
        uint256 newTotalShares = totalSupply() + feeShares;
        return _convertToShares(
            _maxWithdraw(owner, newTotalAssets, newTotalShares), newTotalAssets, newTotalShares, Math.Rounding.Floor
        );
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = simulateAccrue();
        return _convertToShares(assets, newTotalAssets, totalSupply() + feeShares, Math.Rounding.Floor);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = simulateAccrue();
        return _convertToAssets(shares, newTotalAssets, totalSupply() + feeShares, Math.Rounding.Ceil);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = simulateAccrue();
        return _convertToShares(assets, newTotalAssets, totalSupply() + feeShares, Math.Rounding.Ceil);
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = simulateAccrue();
        return _convertToAssets(shares, newTotalAssets, totalSupply() + feeShares, Math.Rounding.Floor);
    }

    function deposit(uint256 assets, address receiver) public nonReentrant returns (uint256 shares) {
        accrue();
        shares = _convertToShares(assets, lastTotalAssets, totalSupply(), Math.Rounding.Floor);
        if (shares == 0) revert SuperVault_ZeroShareDeposit(address(this), assets);
        _deposit(receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public nonReentrant returns (uint256 assets) {
        accrue();
        assets = _convertToAssets(shares, lastTotalAssets, totalSupply(), Math.Rounding.Ceil);
        if (assets == 0) revert SuperVault_ZeroAssetMint(address(this), shares);
        _deposit(receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner) public nonReentrant returns (uint256 shares) {
        accrue();
        shares = _convertToShares(assets, lastTotalAssets, totalSupply(), Math.Rounding.Ceil);
        if (shares == 0) revert SuperVault_ZeroShareWithdraw(address(this), assets);
        _withdraw(receiver, owner, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public nonReentrant returns (uint256 assets) {
        accrue();
        assets = _convertToAssets(shares, lastTotalAssets, totalSupply(), Math.Rounding.Floor);
        if (assets == 0) revert SuperVault_ZeroAssetRedeem(address(this), shares);
        _withdraw(receiver, owner, assets, shares);
    }

    function fuses() external view returns (uint256[] memory) {
        return depositQueue;
    }

    function getFuseCount() external view returns (uint256) {
        return depositQueue.length;
    }

    function totalAssets() public view returns (uint256) {
        uint256 assets = ASSET.balanceOf(address(this));
        uint256 depositQueueLength = depositQueue.length;
        for (uint256 i; i < depositQueueLength; ++i) {
            assets += IFuse(fuseList[i].fuseAddress).getAssetsOf(address(this));
        }
        return assets;
    }

    function addFuse(
        uint256 fuseId,
        address fuseAddress,
        string memory fuseName,
        uint256 assetCap,
        bytes4[] memory selectors,
        bytes[] memory params,
        address[] memory targets
    ) external onlyOwner {
        require(fuseList[fuseId].fuseAddress == address(0), "Fuse ID already exists");
        require(fuseAddress != address(0), "Invalid fuse address");
        fuseList[fuseId] = Fuse(fuseName, fuseAddress);
        fuseCapFor[fuseId] = assetCap;
        for (uint256 i; i < selectors.length; ++i) {
            (address spender, uint256 amount) = abi.decode(params[i], (address, uint256));
            (bool success,) = targets[i].call(abi.encodeWithSelector(selectors[i], spender, amount));
            require(success, "Failed to execute selector");
        }
        emit FuseAdded(fuseId, fuseName, fuseAddress);
    }

    function removeFuse(uint256 fuseId) external onlyOwner {
        require(fuseList[fuseId].fuseAddress != address(0), "Fuse ID does not exist");
        delete fuseList[fuseId];
        emit FuseRemoved(fuseId);
    }

    function modifyFuseCap(uint256 fuseId, uint256 assetCap) external onlyOwner {
        if (fuseCapFor[fuseId] == 0) revert SuperFuse_FuseNotInQueue(fuseId);
        // cannot modify pool cap to zero, remove pool instead
        if (assetCap == 0) revert SuperVault_ZeroPoolCap(fuseId);
        fuseCapFor[fuseId] = assetCap;
        emit FuseCapSet(fuseId, assetCap);
    }

    function reorderDepositQueue(uint256[] calldata indexes) external onlyOwner {
        if (indexes.length != depositQueue.length) revert SuperFuse_QueueLengthMismatch(address(this));
        depositQueue = _reorderQueue(depositQueue, indexes);
    }

    function reorderWithdrawQueue(uint256[] calldata indexes) external onlyOwner {
        if (indexes.length != withdrawQueue.length) revert SuperFuse_QueueLengthMismatch(address(this));
        withdrawQueue = _reorderQueue(withdrawQueue, indexes);
    }

    function requestFeeUpdate(uint256 _fee) external onlyOwner {
        if (fee > 1e18) revert SuperVault_FeeTooHigh();
        pendingFeeUpdate = PendingFeeUpdate({fee: _fee, validAfter: block.timestamp + TIMELOCK_DURATION});
        emit SuperVaultFeeUpdateRequested(_fee);
    }

    function acceptFeeUpdate() external onlyOwner {
        uint256 newFee = pendingFeeUpdate.fee;
        uint256 validAfter = pendingFeeUpdate.validAfter;
        if (validAfter == 0) revert SuperVault_NoFeeUpdate();
        if (block.timestamp < validAfter) revert SuperVault_TimelockPending(block.timestamp, validAfter);
        if (block.timestamp > validAfter + TIMELOCK_DEADLINE) {
            revert SuperVault_TimelockExpired(block.timestamp, validAfter);
        }
        if (newFee != 0 && feeRecipient == address(0)) revert SuperVault_ZeroFeeRecipient();
        accrue();
        fee = newFee;
        emit SuperVaultFeeUpdated(newFee);
        delete pendingFeeUpdate;
    }

    function rejectFeeUpdate() external onlyOwner {
        emit SuperVaultFeeUpdateRejected(pendingFeeUpdate.fee);
        delete pendingFeeUpdate;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        accrue();
        if (fee != 0 && _feeRecipient == address(0)) revert SuperVault_ZeroFeeRecipient();
        feeRecipient = _feeRecipient;
        emit SuperVaultFeeRecipientUpdated(_feeRecipient);
    }

    function addToDepositQueue(uint256 fuseId) external onlyOwner {
        require(fuseList[fuseId].fuseAddress != address(0), "Invalid fuseId");
        for (uint256 i = 0; i < depositQueue.length; i++) {
            require(depositQueue[i] != fuseId, "Fuse already in queue");
        }
        depositQueue.push(fuseId);
        emit DepositQueueUpdated(fuseId);
    }

    function addToWithdrawQueue(uint256 fuseId) external onlyOwner {
        require(fuseList[fuseId].fuseAddress != address(0), "Invalid fuseId");
        for (uint256 i = 0; i < withdrawQueue.length; i++) {
            require(withdrawQueue[i] != fuseId, "Fuse already in queue");
        }
        withdrawQueue.push(fuseId);
        emit WithdrawQueueUpdated(fuseId);
    }

    function removeFromDepositQueue(uint256 fuseId) external onlyOwner {
        _removeFromQueue(depositQueue, fuseId);
        emit DepositQueueUpdated(fuseId);
    }

    struct ReallocateParams {
        uint256 fuseId;
        uint256 assets;
    }

    function reallocate(ReallocateParams[] calldata withdraws, ReallocateParams[] calldata deposits)
        external
        onlyOwner
    {
        console.log("Reallocate started");
        uint256 withdrawsLength = withdraws.length;
        for (uint256 i; i < withdrawsLength; ++i) {
            if (fuseCapFor[withdraws[i].fuseId] == 0) revert SuperFuse_FuseNotInQueue(withdraws[i].fuseId);
            IFuse fuse = IFuse(fuseList[withdraws[i].fuseId].fuseAddress);
            fuse.withdraw(withdraws[i].assets);
        }
        uint256 depositsLength = deposits.length;
        for (uint256 i; i < depositsLength; ++i) {
            uint256 poolCap = fuseCapFor[deposits[i].fuseId];
            if (poolCap == 0) revert SuperFuse_FuseNotInQueue(deposits[i].fuseId);
            IFuse fuse = IFuse(fuseList[deposits[i].fuseId].fuseAddress);
            uint256 assetsInPool = fuse.getAssetsOf(address(this));
            if (assetsInPool + deposits[i].assets < poolCap) {
                ASSET.approve(address(fuse), deposits[i].assets);
                fuse.deposit(deposits[i].assets);
            }
        }
        console.log("Reallocate done");
    }

    function accrue() public {
        (uint256 feeShares, uint256 newTotalAssets) = simulateAccrue();
        if (feeShares != 0) ERC20._mint(feeRecipient, feeShares);
        lastTotalAssets = newTotalAssets;
    }

    function simulateAccrue() internal view returns (uint256, uint256) {
        uint256 newTotalAssets = totalAssets();
        uint256 interestAccrued = (newTotalAssets > lastTotalAssets) ? newTotalAssets - lastTotalAssets : 0;
        if (interestAccrued == 0 || fee == 0) return (0, newTotalAssets);
        uint256 feeAssets = interestAccrued.mulDiv(fee, WAD);
        uint256 feeShares = _convertToShares(feeAssets, newTotalAssets - feeAssets, totalSupply(), Math.Rounding.Floor);
        return (feeShares, newTotalAssets);
    }

    function _deposit(address receiver, uint256 assets, uint256 shares) internal {
        if (lastTotalAssets + assets > superPoolCap) revert SuperVault_SuperVaultCapReached();
        ASSET.safeTransferFrom(msg.sender, address(this), assets);
        ERC20._mint(receiver, shares);
        _supplyToFuses(assets);
        lastTotalAssets += assets;
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function _withdraw(address receiver, address owner, uint256 assets, uint256 shares) internal {
        _withdrawFromFuses(assets);
        if (msg.sender != owner) ERC20._spendAllowance(owner, msg.sender, shares);
        ERC20._burn(owner, shares);
        lastTotalAssets -= assets;
        ASSET.safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function _supplyToFuses(uint256 assets) internal {
        uint256 depositQueueLength = depositQueue.length;
        for (uint256 i; i < depositQueueLength; ++i) {
            uint256 fuseId = depositQueue[i];
            IFuse fuse = IFuse(fuseList[fuseId].fuseAddress);
            uint256 assetsInVault = fuse.getAssetsOf(address(this));

            if (assetsInVault < fuseCapFor[fuseId]) {
                uint256 supplyAmt = fuseCapFor[fuseId] - assetsInVault;
                if (assets < supplyAmt) supplyAmt = assets;
                ASSET.forceApprove(address(fuse), supplyAmt);

                try fuse.deposit(supplyAmt) {
                    assets -= supplyAmt;
                } catch {}

                if (assets == 0) return;
            }
        }
    }

    function _withdrawFromFuses(uint256 assets) internal {
        uint256 withdrawQueueLength = withdrawQueue.length;
        for (uint256 i; i < withdrawQueueLength; ++i) {
            uint256 fuseId = withdrawQueue[i];
            IFuse fuse = IFuse(fuseList[fuseId].fuseAddress);
            uint256 withdrawAmt = assets;
            uint256 assetsInPool = fuse.getAssetsOf(address(this));
            if (assetsInPool < withdrawAmt) withdrawAmt = assetsInPool;
            uint256 poolLiquidity = fuse.getLiquidityOf();
            console.log("poolLiquidity", poolLiquidity);
            console.log("withdrawAmt", withdrawAmt);
            if (poolLiquidity < withdrawAmt) withdrawAmt = poolLiquidity;
            if (withdrawAmt > 0) {
                console.log("withdrawing", withdrawAmt, "from", fuseList[fuseId].name);
                try fuse.withdraw(withdrawAmt) {
                    assets -= withdrawAmt;
                } catch {}
            }
            if (assets == 0) return;
        }

        revert SuperVault_NotEnoughLiquidity(address(this));
    }

    function _reorderQueue(uint256[] storage queue, uint256[] calldata indexes)
        internal
        view
        returns (uint256[] memory newQueue)
    {
        uint256 indexesLength = indexes.length;
        if (indexesLength != queue.length) revert SuperVault_ReorderQueueLength();
        bool[] memory seen = new bool[](indexesLength);
        newQueue = new uint256[](indexesLength);
        for (uint256 i; i < indexesLength; ++i) {
            if (seen[indexes[i]]) revert SuperVault_InvalidQueueReorder();
            newQueue[i] = queue[indexes[i]];
            seen[indexes[i]] = true;
        }

        return newQueue;
    }

    function _removeFromQueue(uint256[] storage queue, uint256 id) internal {
        uint256 queueLength = queue.length;
        uint256 toRemoveIdx = queueLength;
        for (uint256 i; i < queueLength; ++i) {
            if (queue[i] == id) {
                toRemoveIdx = i;
                break;
            }
        }

        if (toRemoveIdx == queueLength) return;

        for (uint256 i = toRemoveIdx; i < queueLength - 1; ++i) {
            queue[i] = queue[i + 1];
        }
        queue.pop();
    }

    function _convertToShares(uint256 _assets, uint256 _totalAssets, uint256 _totalShares, Math.Rounding _rounding)
        public
        view
        virtual
        returns (uint256 shares)
    {
        shares = _assets.mulDiv(_totalShares + 1, _totalAssets + 1, _rounding);
    }

    function _convertToAssets(uint256 _shares, uint256 _totalAssets, uint256 _totalShares, Math.Rounding _rounding)
        public
        view
        virtual
        returns (uint256 assets)
    {
        assets = _shares.mulDiv(_totalAssets + 1, _totalShares + 1, _rounding);
    }

    function _maxDeposit(uint256 _totalAssets) public view returns (uint256) {
        return superPoolCap > _totalAssets ? (superPoolCap - _totalAssets) : 0;
    }

    function _maxWithdraw(address _owner, uint256 _totalAssets, uint256 _totalShares) internal view returns (uint256) {
        uint256 totalLiquidity;
        uint256 depositQueueLength = depositQueue.length;
        for (uint256 i; i < depositQueueLength; ++i) {
            IFuse fuse = IFuse(fuseList[i].fuseAddress);
            totalLiquidity += fuse.getLiquidityOf();
        }
        uint256 userAssets = _convertToAssets(ERC20.balanceOf(_owner), _totalAssets, _totalShares, Math.Rounding.Floor);
        return totalLiquidity > userAssets ? userAssets : totalLiquidity;
    }

    function _tryGetAssetDecimals(IERC20 _asset) private view returns (uint8) {
        (bool success, bytes memory encodedDecimals) =
            address(_asset).staticcall(abi.encodeWithSelector(IERC20Metadata.decimals.selector));
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) return uint8(returnedDecimals);
        }
        return 6;
    }
}

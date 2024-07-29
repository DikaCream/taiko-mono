// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../libs/LibAddress.sol";
import "../signal/ISignalService.sol";

/// @title TaikoL2
/// @notice Taiko L2 is a smart contract that handles cross-layer message
/// verification and manages EIP-1559 gas pricing for Layer 2 (L2) operations.
/// It is used to anchor the latest L1 block details to L2 for cross-layer
/// communication, manage EIP-1559 parameters for gas pricing, and store
/// verified L1 block information.
/// @custom:security-contact security@taiko.xyz
contract TaikoL2 is EssentialContract {
    using LibAddress for address;
    using SafeERC20 for IERC20;

    /// @notice Golden touch address is the only address that can do the anchor transaction.
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;

    /// @notice Mapping from L2 block numbers to their block hashes. All L2 block hashes will
    /// be saved in this mapping.
    mapping(uint256 blockId => bytes32 blockHash) public l2Hashes;

    /// @notice A hash to check the integrity of public inputs.
    /// @dev Slot 2.
    bytes32 public publicInputHash;

    /// @notice The gas excess value used to calculate the base fee.
    /// @dev Slot 3.
    uint64 public __deprecated3;

    /// @notice The last synced L1 block height.
    uint64 public lastSyncedBlock;

    uint64 private __deprecated1; // was parentTimestamp
    uint64 private __deprecated2; // was __currentBlockTimestamp

    /// @notice The L1's chain ID.
    uint64 public l1ChainId;

    uint256[46] private __gap;

    error L2_FORK_ERROR();
    error L2_INVALID_L1_CHAIN_ID();
    error L2_INVALID_L2_CHAIN_ID();
    error L2_INVALID_PARAM();
    error L2_INVALID_SENDER();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    /// @param _l1ChainId The ID of the base layer.
    function init(
        address _owner,
        address _rollupAddressManager,
        uint64 _l1ChainId
    )
        external
        initializer
    {
        __Essential_init(_owner, _rollupAddressManager);

        if (_l1ChainId == 0 || _l1ChainId == block.chainid) {
            revert L2_INVALID_L1_CHAIN_ID();
        }
        if (block.chainid <= 1 || block.chainid > type(uint64).max) {
            revert L2_INVALID_L2_CHAIN_ID();
        }

        if (block.number == 0) {
            // This is the case in real L2 genesis
        } else if (block.number == 1) {
            // This is the case in tests
            uint256 parentHeight = block.number - 1;
            l2Hashes[parentHeight] = blockhash(parentHeight);
        } else {
            revert L2_TOO_LATE();
        }

        l1ChainId = _l1ChainId;
        (publicInputHash,) = _calcPublicInputHash(block.number);
    }

    function init2() external reinitializer(2) {
        __deprecated1 = 0;
        __deprecated2 = 0;
        __deprecated3 = 0;
    }
    /// @notice Anchors the latest L1 block details to L2 for cross-layer
    /// message verification.
    /// @dev This function can be called freely as the golden touch private key is publicly known,
    /// but the Taiko node guarantees the first transaction of each block is always this anchor
    /// transaction, and any subsequent calls will revert with L2_PUBLIC_INPUT_HASH_MISMATCH.
    /// @param _anchorBlockId The `anchorBlockId` value in this block's metadata.
    /// @param _anchorStateRoot The state root for the L1 block with id equals `_anchorBlockId`

    function anchorV2(uint64 _anchorBlockId, bytes32 _anchorStateRoot) external nonReentrant {
        if (_anchorStateRoot == 0 || _anchorBlockId == 0) {
            revert L2_INVALID_PARAM();
        }

        if (msg.sender != GOLDEN_TOUCH_ADDRESS) revert L2_INVALID_SENDER();

        uint256 parentId = block.number - 1;

        // Verify ancestor hashes
        (bytes32 publicInputHashOld, bytes32 publicInputHashNew) = _calcPublicInputHash(parentId);
        if (publicInputHash != publicInputHashOld) {
            revert L2_PUBLIC_INPUT_HASH_MISMATCH();
        }

        if (_anchorBlockId > lastSyncedBlock) {
            // Store the L1's state root as a signal to the local signal service to
            // allow for multi-hop bridging.
            ISignalService(resolve(LibStrings.B_SIGNAL_SERVICE, false)).syncChainData(
                l1ChainId, LibStrings.H_STATE_ROOT, _anchorBlockId, _anchorStateRoot
            );

            lastSyncedBlock = _anchorBlockId;
        }

        // Update state variables
        bytes32 _parentHash = blockhash(parentId);
        l2Hashes[parentId] = _parentHash;
        publicInputHash = publicInputHashNew;
    }

    /// @notice Withdraw token or Ether from this address
    /// @param _token Token address or address(0) if Ether.
    /// @param _to Withdraw to address.
    function withdraw(
        address _token,
        address _to
    )
        external
        whenNotPaused
        onlyFromOwnerOrNamed(LibStrings.B_WITHDRAWER)
        nonReentrant
    {
        if (_to == address(0)) revert L2_INVALID_PARAM();
        if (_token == address(0)) {
            _to.sendEtherAndVerify(address(this).balance);
        } else {
            IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
        }
    }

    /// @notice Retrieves the block hash for the given L2 block number.
    /// @param _blockId The L2 block number to retrieve the block hash for.
    /// @return The block hash for the specified L2 block id, or zero if the
    /// block id is greater than or equal to the current block number.
    function getBlockHash(uint64 _blockId) public view returns (bytes32) {
        if (_blockId >= block.number) return 0;
        if (_blockId + 256 >= block.number) return blockhash(_blockId);
        return l2Hashes[_blockId];
    }

    function _calcPublicInputHash(uint256 _blockId)
        private
        view
        returns (bytes32 publicInputHashOld, bytes32 publicInputHashNew)
    {
        bytes32[256] memory inputs;

        // Unchecked is safe because it cannot overflow.
        unchecked {
            // Put the previous 255 blockhashes (excluding the parent's) into a
            // ring buffer.
            for (uint256 i; i < 255 && _blockId >= i + 1; ++i) {
                uint256 j = _blockId - i - 1;
                inputs[j % 255] = blockhash(j);
            }
        }

        inputs[255] = bytes32(block.chainid);

        assembly {
            publicInputHashOld := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }

        inputs[_blockId % 255] = blockhash(_blockId);
        assembly {
            publicInputHashNew := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }
    }
}

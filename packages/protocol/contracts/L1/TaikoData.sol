// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title TaikoData
/// @notice This library defines various data structures used in the Taiko
/// protocol.
/// @custom:security-contact security@taiko.xyz
library TaikoData {
    /// @dev Struct holding Taiko configuration parameters. See {TaikoConfig}.
    struct Config {
        // ---------------------------------------------------------------------
        // Group 1: General configs
        // ---------------------------------------------------------------------
        // The chain ID of the network where Taiko contracts are deployed.
        uint64 chainId;
        // ---------------------------------------------------------------------
        // Group 2: Block level configs
        // ---------------------------------------------------------------------
        // The maximum number of proposals allowed in a single block.
        uint64 blockMaxProposals;
        // Size of the block ring buffer, allowing extra space for proposals.
        uint64 blockRingBufferSize;
        // The maximum number of verifications allowed when a block is proposed
        // or proved.
        uint64 maxBlocksToVerify;
        // The maximum gas limit allowed for a block.
        uint32 blockMaxGasLimit;
        // ---------------------------------------------------------------------
        // Group 3: Proof related configs
        // ---------------------------------------------------------------------
        // The amount of Taiko token as a prover liveness bond
        uint96 livenessBond;
        // ---------------------------------------------------------------------
        // Group 4: Cross-chain sync
        // ---------------------------------------------------------------------
        // The number of L2 blocks between each L2-to-L1 state root sync.
        uint8 stateRootSyncInternal;
        uint64 maxAnchorHeightOffset;
        // ---------------------------------------------------------------------
        // Group 5: Previous configs in TaikoL2
        // ---------------------------------------------------------------------
        uint8 basefeeAdjustmentQuotient;
        uint8 basefeeSharingPctg;
        uint32 blockGasIssuance;
    }

    /// @dev A proof and the tier of proof it belongs to
    struct TierProof {
        uint16 tier;
        bytes data;
    }

    /// @dev Represents proposeBlock's _data input parameter
    struct BlockParamsV2 {
        address coinbase;
        bytes32 extraData;
        bytes32 parentMetaHash;
        uint64 anchorBlockId; // NEW
        uint64 timestamp; // NEW
        uint32 blobTxListOffset; // NEW
        uint32 blobTxListLength; // NEW
        uint8 blobIndex; // NEW
    }

    /// @dev Struct containing data only required for proving a block
    /// Note: On L2, `block.difficulty` is the pseudo name of
    /// `block.prevrandao`, which returns a random number provided by the layer
    /// 1 chain.
    struct BlockMetadataV2 {
        bytes32 anchorBlockHash; // `_l1BlockHash` in TaikoL2's anchor tx.
        bytes32 difficulty;
        bytes32 blobHash;
        bytes32 extraData;
        address coinbase;
        uint64 id;
        uint32 gasLimit;
        uint64 timestamp;
        uint64 anchorBlockId; // `_l1BlockId` in TaikoL2's anchor tx.
        uint16 minTier;
        bool blobUsed;
        bytes32 parentMetaHash;
        address proposer;
        uint96 livenessBond;
        // Time this block is proposed at, used to check proving window and cooldown window.
        uint64 proposedAt;
        // L1 block number, required/used by node/client.
        uint64 proposedIn;
        uint32 blobTxListOffset;
        uint32 blobTxListLength;
        uint8 blobIndex;
        uint8 basefeeAdjustmentQuotient;
        uint8 basefeeSharingPctg;
        uint32 blockGasIssuance;
    }

    /// @dev Struct representing transition to be proven.
    struct Transition {
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 stateRoot;
        bytes32 graffiti; // Arbitrary data that the prover can use for various purposes.
    }

    /// @dev Struct representing state transition data.
    /// 6 slots used.
    struct TransitionState {
        bytes32 key; // slot 1, only written/read for the 1st state transition.
        bytes32 blockHash; // slot 2
        bytes32 stateRoot; // slot 3
        address prover; // slot 4
        uint96 validityBond;
        address contester; // slot 5
        uint96 contestBond;
        uint64 timestamp; // slot 6 (90 bits)
        uint16 tier;
        uint8 __reserved1;
    }

    /// @dev Struct containing data required for verifying a block.
    /// 3 slots used.
    struct Block {
        bytes32 metaHash; // slot 1
        address assignedProver; // slot 2
        uint96 livenessBond;
        uint64 blockId; // slot 3
        // Ignore the name, `proposedAt` now represents `params.timestamp`.
        uint64 proposedAt;
        // Ignore the name, `proposedIn` now represents `params.anchorBlockId`.
        uint64 proposedIn;
        uint24 nextTransitionId;
        bool livenessBondReturned;
        // The ID of the transaction that is used to verify this block. However, if
        // this block is not verified as the last block in a batch, verifiedTransitionId
        // will remain zero.
        uint24 verifiedTransitionId;
    }

    /// @dev Forge is only able to run coverage in case the contracts by default
    /// capable of compiling without any optimization (neither optimizer runs,
    /// no compiling --via-ir flag).
    /// In order to resolve stack too deep without optimizations, we needed to
    /// introduce outsourcing vars into structs below.
    struct SlotA {
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 lastSyncedBlockId;
        uint64 lastSynecdAt; // typo!
    }

    struct SlotB {
        uint64 numBlocks;
        uint64 lastVerifiedBlockId;
        bool provingPaused;
        uint8 __reservedB1;
        uint16 __reservedB2;
        uint32 __reservedB3;
        uint64 lastUnpausedAt;
    }

    /// @dev Struct holding the state variables for the {TaikoL1} contract.
    struct State {
        // Ring buffer for proposed blocks and a some recent verified blocks.
        mapping(uint64 blockId_mod_blockRingBufferSize => Block blk) blocks;
        // Indexing to transition ids (ring buffer not possible)
        mapping(uint64 blockId => mapping(bytes32 parentHash => uint24 transitionId)) transitionIds;
        // Ring buffer for transitions
        mapping(
            uint64 blockId_mod_blockRingBufferSize
                => mapping(uint32 transitionId => TransitionState ts)
        ) transitions;
        // Ring buffer for Ether deposits
        bytes32 __reserve1;
        SlotA slotA; // slot 5
        SlotB slotB; // slot 6
        mapping(address account => uint256 bond) bondBalance;
        uint256[43] __gap;
    }
}

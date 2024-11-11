// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestTaikoL1Base.sol";

contract TestTaikoL1_Group4 is TestTaikoL1Base {
    // Test summary:
    // 1. Alice proposes a block, Alice is the prover.
    // 2. Alice proves the block within the proving window, using the correct parent hash.
    // 3. Taylor contests then proves Alice is wrong  in the same transaction with a higher-tier
    // proof.
    // 4. Taylor's proof is used to verify the block.
    function test_taikoL1_group_4_case_1() external {
        mineOneBlockAndWrap(1000 seconds);

        mintTaikoToken(Alice, 10_000 ether);
        mintEther(Alice, 1000 ether);

        mintTaikoToken(Taylor, 10_000 ether);
        mintEther(Taylor, 1000 ether);

        ITierProvider.Tier memory tier3 = tierProvider.getTier(0, 73);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== Alice proves the block as the assigned prover");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(10 seconds);
        proveBlock(Alice, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor contests Alice with a higher tier proof");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineOneBlockAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash, blockHash2, stateRoot2, 73, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, 73);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, tier3.validityBond);
            assertEq(ts.prover, Taylor);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - minTier.validityBond);
            assertEq(
                bondToken.balanceOf(Taylor),
                10_000 ether - tier3.validityBond + minTier.validityBond * 7 / 8
            );
        }

        console2.log("====== Verify the block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);
            // assertEq(blk.livenessBond, livenessBond);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, 73);
            assertEq(ts.prover, Taylor);

            assertEq(getBondTokenBalance(Taylor), 10_000 ether + minTier.validityBond * 7 / 8);
        }
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. David proves the block outside the proving window, using the correct parent hash.
    // 3. Taylor contests then proves David is wrong in the same transaction with a higher-tier
    // proof.
    // 4. Taylor's proof is used to verify the block.
    function test_taikoL1_group_4_case_2() external {
        mineOneBlockAndWrap(1000 seconds);

        mintTaikoToken(Alice, 10_000 ether);
        mintEther(Alice, 1000 ether);

        mintTaikoToken(David, 10_000 ether);
        mintEther(David, 1000 ether);
        mintTaikoToken(Taylor, 10_000 ether);
        mintEther(Taylor, 1000 ether);

        ITierProvider.Tier memory tier3 = tierProvider.getTier(0, 73);

        console2.log("====== Alice propose a block");
        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== Alice proves the block as the assigned prover");
        bytes32 parentHash = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));

        mineOneBlockAndWrap(7 days);
        proveBlock(David, meta, parentHash, blockHash, stateRoot, meta.minTier, "");

        console2.log("====== Taylor contests David with a higher tier proof");
        bytes32 blockHash2 = bytes32(uint256(20));
        bytes32 stateRoot2 = bytes32(uint256(21));
        mineOneBlockAndWrap(10 seconds);
        proveBlock(Taylor, meta, parentHash, blockHash2, stateRoot2, 73, "");

        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);
            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 0);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, 73);
            assertEq(ts.contester, address(0));
            assertEq(ts.validityBond, tier3.validityBond);
            assertEq(ts.prover, Taylor);
            assertEq(ts.timestamp, block.timestamp);

            assertEq(getBondTokenBalance(Alice), 10_000 ether - livenessBond);
            assertEq(
                bondToken.balanceOf(David),
                10_000 ether - minTier.validityBond + livenessBond * 7 / 8
            );
            assertEq(
                bondToken.balanceOf(Taylor),
                10_000 ether - tier3.validityBond + minTier.validityBond * 7 / 8
            );
        }

        console2.log("====== Verify the block");
        mineOneBlockAndWrap(7 days);
        taikoL1.verifyBlocks(1);
        {
            printBlockAndTrans(meta.id);

            TaikoData.BlockV2 memory blk = taikoL1.getBlockV2(meta.id);

            assertEq(blk.nextTransitionId, 2);
            assertEq(blk.verifiedTransitionId, 1);

            TaikoData.TransitionState memory ts = taikoL1.getTransition(meta.id, 1);
            assertEq(ts.blockHash, blockHash2);
            assertEq(ts.stateRoot, stateRoot2);
            assertEq(ts.tier, 73);
            assertEq(ts.prover, Taylor);

            assertEq(getBondTokenBalance(Taylor), 10_000 ether + minTier.validityBond * 7 / 8);
        }
    }
}

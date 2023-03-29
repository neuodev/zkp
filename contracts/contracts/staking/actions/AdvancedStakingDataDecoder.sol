// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { CIPHERTEXT1_WORDS, OUT_RWRD_UTXOs, PUBKEY_WORDS } from "../../common/Constants.sol";
import { G1Point } from "../../common/Types.sol";

/***
 * @title AdvancedStakingDataDecoder
 * @dev It decodes (unpack) `bytes data` of the 'STAKED' message for "advanced staking"
 */
abstract contract AdvancedStakingDataDecoder {
    // in bytes
    uint256 private constant DATA_LENGTH =
        OUT_RWRD_UTXOs * (PUBKEY_WORDS + CIPHERTEXT1_WORDS) * 32;
    // in 32-byte memory slots
    uint256 private constant NUM_DATA_SLOTS =
        (DATA_LENGTH / 32) + ((DATA_LENGTH % 32) & 1);

    // For efficiency we use "packed" (rather than "ABI") encoding.
    // It results in shorter data, but requires custom unpack function.
    function unpackStakingData(bytes memory data)
        internal
        pure
        returns (
            G1Point[OUT_RWRD_UTXOs] memory pubSpendingKeys,
            uint256[CIPHERTEXT1_WORDS][OUT_RWRD_UTXOs] memory secrets
        )
    {
        require(data.length == DATA_LENGTH, "SMP: unexpected msg length");

        // Let's read bytes as uint256 values
        uint256[NUM_DATA_SLOTS + 1] memory words;
        // the 1st slot is `data.length`, then slots with values follow
        for (uint256 i = 1; i <= NUM_DATA_SLOTS; ++i) {
            // solhint-disable no-inline-assembly
            // slither-disable-next-line assembly
            assembly {
                let offset := mul(i, 0x20)
                let word := mload(add(data, offset))
                mstore(add(words, offset), word)
            }
            // solhint-enable no-inline-assembly
        }
        /*
            `bytes memory sample = 0x00010203..1f2021` stored in the memory like this:
            slot #0: 0x22 - length (34 bytes)
            slot #1: 0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
            slot #2: 0x2021000000000000000000000000000000000000000000000000000000000000

            If `OUT_RWRD_UTXOs == 2` and `CIPHERTEXT1_WORDS == 2`,
            `bytes memory data` expected to be:
            concatenate( // each element is 32-byte long
                pubSpendingKeys[0].x, pubSpendingKeys[0].y,
                pubSpendingKeys[1].x, pubSpendingKeys[1].y,
                (secrets[0])[0], (secrets[0])[1],
                (secrets[1])[0], (secrets[1])[1]
            )
        */
        for (uint256 i = 0; i < OUT_RWRD_UTXOs; i++) {
            pubSpendingKeys[i].x = words[i * PUBKEY_WORDS + 1];
            pubSpendingKeys[i].y = words[i * PUBKEY_WORDS + 2];
            for (uint256 k = 0; k < CIPHERTEXT1_WORDS; k++) {
                secrets[i][k] = words[
                    PUBKEY_WORDS *
                        OUT_RWRD_UTXOs +
                        CIPHERTEXT1_WORDS *
                        i +
                        k +
                        1
                ];
            }
        }
    }
}

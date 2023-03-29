// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import { ERC20_TOKEN_TYPE, ERC721_TOKEN_TYPE, ERC1155_TOKEN_TYPE } from "../common/Constants.sol";
import "./errMsgs/VaultErrMsgs.sol";
import "../common/ImmutableOwnable.sol";
import "../common/TransferHelper.sol";
import { LockData } from "../common/Types.sol";
import "./interfaces/IVault.sol";
import "./vault/OnERC1155Received.sol";
import "./vault/OnERC721Received.sol";

/**
 * @title Vault
 * @author Pantherprotocol Contributors
 * @notice Holder of assets (tokens) for `PantherPool` contract
 * @dev It transfers assets from user to itself (Lock) and vice versa (Unlock).
 * `PantherPool` is assumed to be the `owner` that is authorized to trigger
 * locking/unlocking assets.
 */
contract Vault is
    ImmutableOwnable,
    OnERC721Received,
    OnERC1155Received,
    IVault
{
    using TransferHelper for address;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _owner) ImmutableOwnable(_owner) {
        // Proxy-friendly: no storage initialization
    }

    // The caller (i.e. the owner) is supposed to apply reentrancy guard.
    // If an adversarial "token", being called by this function, re-enters it
    // directly, `onlyOwner` will revert as `msg.sender` won't be `owner`.
    function lockAsset(LockData calldata data)
        external
        override
        onlyOwner
        checkLockData(data)
    {
        if (data.tokenType == ERC20_TOKEN_TYPE) {
            // Owner, who only may call this code, is trusted to protect
            // against "Arbitrary from in transferFrom" vulnerability
            // slither-disable-next-line arbitrary-send-erc20,reentrancy-benign,reentrancy-events
            data.token.safeTransferFrom(
                data.extAccount,
                address(this),
                data.extAmount
            );
        } else if (data.tokenType == ERC721_TOKEN_TYPE) {
            // slither-disable-next-line reentrancy-benign,reentrancy-events
            data.token.erc721SafeTransferFrom(
                data.tokenId,
                data.extAccount,
                address(this)
            );
        } else if (data.tokenType == ERC1155_TOKEN_TYPE) {
            // slither-disable-next-line reentrancy-benign,reentrancy-events
            data.token.erc1155SafeTransferFrom(
                data.extAccount,
                address(this),
                data.tokenId,
                uint256(data.extAmount),
                new bytes(0)
            );
        } else {
            revert(ERR_INVALID_TOKEN_TYPE);
        }

        emit Locked(data);
    }

    // The caller (i.e. the owner) is supposed to apply reentrancy guard.
    // If an adversarial "token", being called by this function, re-enters it
    // directly, `onlyOwner` will revert as `msg.sender` won't be `owner`.
    function unlockAsset(LockData calldata data)
        external
        override
        onlyOwner
        checkLockData(data)
    {
        if (data.tokenType == ERC20_TOKEN_TYPE) {
            // slither-disable-next-line reentrancy-benign,reentrancy-events
            data.token.safeTransfer(data.extAccount, data.extAmount);
        } else if (data.tokenType == ERC721_TOKEN_TYPE) {
            // slither-disable-next-line reentrancy-benign,reentrancy-events
            data.token.erc721SafeTransferFrom(
                data.tokenId,
                address(this),
                data.extAccount
            );
        } else if (data.tokenType == ERC1155_TOKEN_TYPE) {
            // slither-disable-next-line reentrancy-benign,reentrancy-events
            data.token.erc1155SafeTransferFrom(
                address(this),
                data.extAccount,
                data.tokenId,
                data.extAmount,
                new bytes(0)
            );
        } else {
            revert(ERR_INVALID_TOKEN_TYPE);
        }

        emit Unlocked(data);
    }

    modifier checkLockData(LockData calldata data) {
        require(data.token != address(0), ERR_ZERO_LOCK_TOKEN_ADDR);
        require(data.extAccount != address(0), ERR_ZERO_EXT_ACCOUNT_ADDR);
        require(data.extAmount > 0, ERR_ZERO_EXT_AMOUNT);
        _;
    }
}

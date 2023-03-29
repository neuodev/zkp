// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import { ERC20_TOKEN_TYPE, zASSET_ENABLED, zASSET_UNKNOWN } from "../common/Constants.sol";
import "./errMsgs/ZAssetsRegistryErrMsgs.sol";
import "../common/ImmutableOwnable.sol";
import { ZAsset } from "../common/Types.sol";
import "./interfaces/IZAssetsRegistry.sol";

/**
 * @title ZAssetsRegistry
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of assets (tokens) supported by the Panther
 * Protocol Multi-Asset Shielded Pool (aka "MASP")
 */
contract ZAssetsRegistry is ImmutableOwnable, IZAssetsRegistry {
    /**
    "zAsset" - abstraction of a token for representation in the MASP.
    ZK-circuits "treat" each zAsset as a unique (independent) token.
    `zAssetId` - ID of a zAsset.
    Circuits "know" a token by its zAssetID rather than the token addresses or
    its _tokenId/_id.
    Each distinguishable token supported by the MASP must be represented by its
    "own" zAsset. zAsset must never  "represent" two (or more) different tokens.
    An ERC-721/ERC-1155 token, with its unique _tokenId/_id, must "have" its own
    zAsset, different from zAssets of other tokens on the same contract.
    An ERC-20 token should be represented by at least one zAsset (further
    referred to as the "default" zAsset). A few other zAssets (aka "alternative"
    zAssets) may exist for the same ERC-20 token, with each zAsset having a
    different "scaling factor" (`ZAsset.scale`).

    `ZAsset` - a record on the Registry with parameters of zAsset(s).
    `zAssetRecId` - ID of a ZAsset record.
    Not every zAsset has its "own" ZAsset record, but each ZAsset keeps params
    of at least one zAsset. It groups all zAssets, which share the same token
    contract and the "scaling factor".
    There is just one ZAsset record for all zAssets representing tokens on an
    ERC-721/1155 contract. Thus, for any such supported contract there must be
    EXACTLY one ZAsset record on the Registry.
    Every zAsset representing an ERC-20 token must have its own ZAsset record.
    So, the Registry must have at LEAST one ZAsset (for the default zAsset) for
    an ERC-20 contract. However, other ZAsset records (for alternative zAssets)
    may exist for the same ERC-20 token.

    `subId` - additional ID which, coupled with the token contract address, let
    deterministically compute `zAssetId` and `zAssetRecId`.

    This code is written with the following specs in mind:
    - If at least one token on an ERC-721/ERC-1155 contract is whitelisted, any
      token on the contract is implicitly whitelisted w/o further configuration
    - Registry must have one ZAsset record only for all tokens of an ERC-721/
      ERC-1155 contract
    - ZAsset record of any zAsset, w/ exception of extremely rare cases, should
      be obtained with just a single SLOAD
    - Backward compatible upgrades should be able to implement ..
    -- .. separate whitelists of zAssets allowed for deposits and withdrawals
       (e.g. via extension of ZAsset.status)
    -- .. blacklist for some tokens on a whitelisted ERC-721/ERC-1155 contract
       (e.g. by extending ZAsset.tokenType and introducing a blacklist)
    -- .. limits per a zAsset for max allowed amounts of deposits/withdrawals
       (e.g. with "alternative" zAssets and re-defining ZAsset._unused)
    */

    uint8 private constant MAX_SCALE = 32; // min scale is 0
    uint8 private constant NO_SCALING = 0;
    uint256 private constant DEFAULT_VER = 0;

    // Mapping from `zAssetRecId` to ZAsset (i.e. params of an zAsset)
    mapping(uint160 => ZAsset) private _registry;

    // solhint-disable-next-line no-empty-blocks
    constructor(address _owner) ImmutableOwnable(_owner) {
        // Proxy-friendly: no storage initialization
    }

    function getZAssetId(address token, uint256 subId)
        public
        pure
        override
        returns (uint160)
    {
        // Being uint160, it is surely less then the FIELD_SIZE
        return
            uint160(
                uint256(
                    keccak256(abi.encode(uint256(uint160(token)), subId))
                ) >> 96
            );
    }

    /// @notice Returns ZAsset record for the given record ID
    function getZAsset(uint160 zAssetRecId)
        external
        view
        override
        returns (ZAsset memory asset)
    {
        asset = _registry[zAssetRecId];
    }

    /// @notice Returns zAsset IDs and ZAsset record for the given token
    /// @param token Address of the token contract
    /// @param subId Extra ID to identify zAsset (0 by default)
    /// @dev For ERC-721/ERC-1155 token, `subId` is the _tokenId/_id. For  the
    // "default" zAsset of an ERC-20 token it is 0. For an "alternative" zAsset
    // it is the `defaultZAssetRecId XOR ver`, where `defaultZAssetRecId` is the
    // `zAssetRecId` of the default zAsset for this token, and `ver` is a unique
    // int in the range [1..31].
    /// @return zAssetId
    /// @return _tokenId ERC-721/1155 _tokenId/_id, if it's an NFT, or 0 for ERC-20
    /// @return zAssetRecId ID of the ZAsset record
    /// @return asset ZAsset record for the token
    function getZAssetAndIds(address token, uint256 subId)
        external
        view
        override
        returns (
            uint160 zAssetId,
            uint256 _tokenId,
            uint160 zAssetRecId,
            ZAsset memory asset
        )
    {
        require(token != address(0), ERR_ZERO_TOKEN_ADDRESS);

        // Gas optimized based on assumptions:
        // - most often, this code is called for the default zAsset of ERC-20
        // - if `ver` is in [1..MAX_SCALE], likely it's an alternative zAsset
        _tokenId = subId;
        if (subId != 0) {
            // Risk of zAssetRecId collision attack (see further) ignored since
            // `subId` variant space is small (less than MAX_SCALE of ~5 bits).
            // Therefore `require(asset.token == token)` omitted here.

            // For an "alternative" zAsset, `subId` must be none-zero...
            uint256 ver = uint256(uint160(token)) ^ subId;
            // ... and `ver` must be in [1..MAX_SCALE]
            if (ver < MAX_SCALE && ver != DEFAULT_VER) {
                // Likely, it's the alternative zAsset w/ `zAssetRecId = subId`
                asset = _registry[uint160(subId)];

                if (asset.version == uint8(ver)) {
                    // Surely, it's the alternative zAsset of the ERC-20 token
                    // as `.version` must be 0 for NFTs and default zAssets.
                    // As `.version != 0`, `.status` can't be zASSET_UNKNOWN.
                    // Check `asset.tokenType == ERC20_TOKEN_TYPE` is skipped
                    // as the code registering ZAssets is assumed to ensure it.
                    zAssetId = getZAssetId(token, subId);
                    zAssetRecId = uint160(subId);
                    _tokenId = DEFAULT_VER;
                    return (zAssetId, _tokenId, zAssetRecId, asset);
                }
            }
        }
        // The zAsset can't be an alternative zAsset of an ERC-20 token here.
        // It's either an NFT (`subId` is _tokenId), or the default zAsset of
        // an ERC-20 token (`subId` is 0). In both cases `asset.version == 0`.

        zAssetRecId = uint160(token); // same as `uint160(token) ^ 0`
        asset = _registry[zAssetRecId];
        if (asset.status == zASSET_UNKNOWN) {
            // Unknown token - return zero IDs, and empty ZAsset
            return (0, 0, 0, asset);
        }

        require(
            // `subId` of an ERC-20 token's default zAsset must be 0
            (subId == 0 || asset.tokenType != ERC20_TOKEN_TYPE) &&
                // zAssetReqId collision attack protection:
                // attacker may vary token id of a fake NFT to make zAssetReqId
                // (i.e. `token ^ subId`) equal to zAssetReqId of another token
                asset.token == token,
            ERR_ZERO_SUBID_EXPECTED
        );
        zAssetId = getZAssetId(token, _tokenId);
        return (zAssetId, _tokenId, zAssetRecId, asset);
    }

    function isZAssetWhitelisted(uint160 zAssetRecId)
        external
        view
        override
        returns (bool)
    {
        ZAsset memory asset = _registry[zAssetRecId];
        return asset.status == zASSET_ENABLED;
    }

    /// @notice Register with the MASP a new asset with given params
    /// @param asset Params of the asset (including its `ZAsset.status`)
    /// @dev The "owner" may call only
    function addZAsset(ZAsset memory asset) external onlyOwner {
        require(asset.token != address(0), ERR_ZERO_TOKEN_ADDRESS);
        require(asset.status != zASSET_UNKNOWN, ERR_WRONG_ASSET_STATUS);
        require(
            // ERC-20 zAsset only may be "alternative" ones
            asset.version == 0 ||
                (asset.tokenType == ERC20_TOKEN_TYPE &&
                    asset.version < MAX_SCALE),
            ERR_WRONG_ASSET_VER
        );
        _checkScaleIsInRange(asset);

        // note, `x ^ 0 == x`
        uint160 zAssetRecId = uint160(asset.token) ^ uint160(asset.version);

        ZAsset memory existingAsset = _registry[zAssetRecId];
        require(
            existingAsset.status == zASSET_UNKNOWN,
            ERR_ASSET_ALREADY_REGISTERED
        );
        _registry[zAssetRecId] = asset;
        emit AssetAdded(zAssetRecId, asset);
    }

    /// @notice Updates the status of the existing asset
    /// @param zAssetRecId ID of the ZAsset record
    /// @param newStatus Status to be set
    /// @dev The "owner" may call only
    function changeZAssetStatus(uint160 zAssetRecId, uint8 newStatus)
        external
        onlyOwner
    {
        require(_registry[zAssetRecId].token != address(0), ERR_UNKNOWN_ASSET);
        uint8 oldStatus = _registry[zAssetRecId].status;
        // New status value restrictions relaxed to allow for protocol updates.
        require(
            newStatus != zASSET_UNKNOWN && oldStatus != newStatus,
            ERR_WRONG_ASSET_STATUS
        );
        _registry[zAssetRecId].status = newStatus;
        emit AssetStatusChanged(zAssetRecId, newStatus, oldStatus);
    }

    function _checkScaleIsInRange(ZAsset memory asset) private pure {
        // Valid range for ERC-20 is [0..31]
        // Valid range for ERC-721/ERC-1155 is 0
        require(
            (asset.scale == NO_SCALING ||
                ((asset.scale < MAX_SCALE) &&
                    (asset.tokenType == ERC20_TOKEN_TYPE))),
            ERR_WRONG_ASSET_SCALE
        );
    }
}

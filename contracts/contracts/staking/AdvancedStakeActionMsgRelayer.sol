// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "./actions/AdvancedStakingBridgedDataCoder.sol";
import "./interfaces/IActionMsgReceiver.sol";
import "./interfaces/IFxMessageProcessor.sol";

/***
 * @title AdvancedStakeActionMsgRelayer
 * @notice It re-translates messages on new "advanced" stakes created on the mainnet (or Goerli)
 * network to the `RewardMaster` contract running on the Polygon (or Mumbai) network.
 * @dev It is assumed to run on the Polygon (or Mumbai) network.
 * Like the `Staking` contract, this contract acts as the "Action Oracle" for the RewardMaster, and
 * this contract must be registered as the oracle with the latest.
 * It receives STAKE action messages (on new "advanced" stakes created) from the `FxChild` contract
 * (a contract of the "Fx-Portal" PoS bridge), sanitizes and relays messages to the RewardMaster on
 * the Polygon (or Mumbai).
 * The `AdvancedStakeRewardAdviserAndMsgSender` contract, a counterpart to this contract that runs
 * on the mainnet (or Goerli) network, sends these messages to this contract over the bridge.
 */
contract AdvancedStakeActionMsgRelayer is
    AdvancedStakingBridgedDataCoder,
    IFxMessageProcessor
{
    event StakeMsgRelayed(uint256 _nonce, bytes data);

    // solhint-disable var-name-mixedcase

    /// @notice Address of the `FxChild` contract on the Polygon/Mumbai network
    /// @dev `FxChild` is the contract of the "Fx-Portal" on the Polygon/Mumbai
    address public immutable FX_CHILD;

    /// @notice Address of the RewardMaster contract on the Polygon/Mumbai
    address public immutable REWARD_MASTER;

    /// @notice Address of the AdvancedStakeRewardAdviserAndMsgSender on the mainnet/Goerli
    /// @dev It sends messages over the PoS bridge to this contract
    address public immutable STAKE_MSG_SENDER;

    // solhint-enable var-name-mixedcase

    /// @notice Message nonce (i.e. sequential number of the latest message)
    uint256 public nonce;

    /// @param _rewardMaster Address of the RewardMaster contract on the Polygon/Mumbai
    /// @param _stakeMsgSender Address of the AdvancedStakeRewardAdviserAndMsgSender on the mainnet/Goerli
    /// @param _fxChild Address of the `FxChild` (Bridge) contract on Polygon/Mumbai
    constructor(
        // slither-disable-next-line similar-names
        address _rewardMaster,
        address _stakeMsgSender,
        address _fxChild
    ) {
        require(
            _fxChild != address(0) &&
                _stakeMsgSender != address(0) &&
                _rewardMaster != address(0),
            "AMR:E01"
        );

        FX_CHILD = _fxChild;
        REWARD_MASTER = _rewardMaster;
        STAKE_MSG_SENDER = _stakeMsgSender;
    }

    /// @dev Sanitizes, decodes and relay to the RewardMaster the STAKE action message.
    /// PoS bridge validators call this method via the `FxChild` contract each time
    /// a new message is posted to the bridge on the mainnet/Goerli
    /// @param rootMessageSender Address on the mainnet/Goerli that sent the message
    /// @param content Message data
    function processMessageFromRoot(
        uint256, // stateId (Polygon PoS Bridge state sync ID, unused)
        address rootMessageSender,
        bytes calldata content
    ) external override {
        require(msg.sender == FX_CHILD, "AMR:INVALID_CALLER");
        require(rootMessageSender == STAKE_MSG_SENDER, "AMR:INVALID_SENDER");

        (
            uint256 _nonce,
            bytes4 action,
            bytes memory message
        ) = _decodeBridgedData(content);

        // Protection against replay attacks/errors. It's supposed that:
        // - failed `.onAction` shall not stop further messages bridging
        // - nonce is expected never be large enough to overflow.
        require(_nonce > nonce, "AMR:INVALID_NONCE");
        nonce = _nonce;

        // trusted contract call - no reentrancy guard needed
        // slither-disable-next-line reentrancy-benign,reentrancy-events
        IActionMsgReceiver(REWARD_MASTER).onAction(action, message);

        emit StakeMsgRelayed(_nonce, content);
    }
}

## Production Deployment

After you have made sure the unit tests pass, you can deploy the contracts on production networks.

Make sure you are inside the [`contracts`](../contracts) workspace. Execute the following command in the root directory to change your directory to the `contracts` workspace:

    cd ./contracts

Before executing the deployment scripts, you need to rename the [.env.example](../.env.example) to `.env`. This file contains the contract addresses that are dependencies for the non-deployed contracts. Don't forget to add your private key (or mnemonic) and an [Alchemy](https://www.alchemy.com)/[Infura](https://www.infura.io) api key there. There are `PRIVATE_KEY` (or `MNEMONIC`) and `ALCHEMY_API_KEY`/`INFURA_API_KEY` variables there which must be filled up by you.

**Note:** The contract addresses will be shown in your terminal after they are deployed.
Additionally, you can find the contracts' artifacts under the [deployments](../deployments) folder. They are generated on the fly under the `mainnet` or `polygon` subfolder, depending on the network where they have been deployed. Each artifact contains the contract ABI, address, constructor parameters, deployment blocks, bytecodes, and other valuable information.

There is a single `yarn` command that sends multiple transactions in sequence to deploy the panther protocol v0.5 contracts plus the `AdvancedStakeRewardController` contract - which handles the rewards of stakers who participate in the [Advanced staking](https://blog.pantherprotocol.io/advanced-staking-is-on-its-way-heres-how-to-prepare-for-it-b14cd01e4cc4) program.

**Note:** In case it throws an error in the middle of the process, feel free to execute it again. It starts the process from where it has been thrown. In other words, it does not deploy the contracts twice.

Now it's time to deploy the contracts. To do that, execute the following command:

    yarn deploy:staking:advanced --network polygon

Since the advanced staking will also be available on the Ethereum Mainnet, we have implemented two smart contracts which can interact with the official polygon bridge contracts to move the stake messages from the Ethereum Mainnet to the Polygon network. To deploy these contracts, you need to go through the following steps:

- Deploying the `AdvancedStakeActionMsgRelayer_Proxy` contract that relays the stake message in Polygon. Note that you need to copy this contract address from your terminal after you deployed it.

```
  yarn deploy:bridge:relayer:proxy --network polygon
```

- After you copied the `AdvancedStakeActionMsgRelayer_Proxy` contract address, you need to add it to `ADVANCED_STAKE_ACTION_MSG_RELAYER_PROXY_POLYGON` env variable in your local `.env` file. Then, you need to deploy the `AdvancedStakeRewardAdviserAndMsgSender` contract. It sends the stake message from the Ethereum Mainnet to the Polygon network. As in the previous step, you need to copy the address of this contract:

```
  yarn deploy:bridge:sender --network mainnet
```

- Add the address of the `AdvancedStakeRewardAdviserAndMsgSender` contract to `ADVANCED_STAKE_REWARD_ADVISER_AND_MSG_SENDER_MAINNET` env variable in your local `.env` file.
  Then, let's deploy an implementation for the `AdvancedStakeActionMsgRelayer_Proxy` contract:

```
  yarn deploy:bridge:relayer:imp --network polygon
```

- And the final step is to upgrade the `AdvancedStakeActionMsgRelayer_Proxy` contract to its implementation:

```
  yarn deploy:bridge:relayer:upgrade --network polygon
```

Congratulation! You have deployed all the contracts needed for Panther Protocol v0.5

## Provide Contracts' Artifacts

After you deployed the contracts, you need to push the artifacts to Git. These artifacts can be found under the [`deployments/mainnet`](../deployments/mainnet) and [`deployments/polygon`](../deployments/polygon) directories.

Here is the name of the artifacts that are expected to be pushed:

- Mainnet artifact:

  - AdvancedStakeRewardAdviserAndMsgSender

- Polygon artifacts:
  - AdvancedStakeActionMsgRelayer_Implementation
  - AdvancedStakeActionMsgRelayer_Proxy
  - AdvancedStakeRewardController
  - PantherPoolV0_Implementation
  - PantherPoolV0_Proxy
  - PNftToken
  - PoseidonT3
  - PoseidonT4
  - Vault_Implementation
  - Vault_Proxy
  - ZAssetsRegistry_Implementation
  - ZAssetsRegistry_Proxy

Let's push these artifacts to the Git. Make sure you are inside the [`contracts`](../contracts) workspace and execute below commands:

Create a new branch and switch to it:

    git checkout -b production-artifacts-v0.5

Add the artifacts to your Git stage:

    git add ./deployments/mainnet ./deployments/polygon  -f

Commit the staged files:

    git commit -m 'add the production artifacts of panther v0.5'

push the files to Git

    git push origin production-artifacts-v0.5

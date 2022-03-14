# ClimateToken
This repo contains the solidity code for ClimateDAO's Climate token smart contract.

ClimateDAO’s $CLIMATE token implements two important features. First, the $CLIMATE token implements OpenZeppelin’s ERC20 Votes API which allows a token to represent governance rights in a DAO.  Second, ClimateDAO’s token transfer fee is based off of the time the token is held, thus incentivizing users to continue holding the token and support ClimateDAO campaigns.

## ERC20 Votes
This extension keeps a history (checkpoints) of each account’s vote power. Vote power can be delegated either by calling the delegate function directly, or by providing a signature to be used with delegateBySig. Voting power can be queried through the public accessors getVotes and getPastVotes.

By default, token balance does not account for voting power. This makes transfers cheaper. The downside is that it requires users to delegate to themselves in order to activate checkpoints and have their voting power tracked.

## Transfer Fee
The $CLIMATE token implements a 15% time based transfer fee that decreases linearly to 0% over 6 months based on the amount of time held. This fee is calculated by calculating what percentage of 6 months has passed since the tokens were obtained, taking that percentage of 15%, and then transferring that percentage of tokens to the ClimateDAO treasury. We calculate the time held by mapping the recipient of a transfer's wallet address to the current time when tokens are received. The actual calculation is explained below:

amount = number of tokens being transferred <br>
base to be taken before time calculation = 15/100 = 15% <br>
expiry = 6 months in seconds <br>
time passed = current time (block.timestamp) - the original time mapped to a user's wallet address <br>

**The base calculation:**

(amount) * (15/100) * ((expiry - time_passed) / expiry)
<br>
<br>

**To avoid decimal issues, we concatenate this into one equation:**

amount * 15 * (expiry - time passed) <br>
____________________________________  = Fee <br>
expiry * 100
<br>
<br>
<br>
The fee is sent to the climateDAO treasury wallets, and we then subtract the original amount from this fee and send it to its intended recipient.

Accounts can be excluded from the transfer fee and the transfer fee can be changed. In the future, we will make the governance smart contract the owner of the climate token contract so these can only be controlled by a successful DAO proposal.

## Transferable Flag
Upon the initial private release of the platform, we do not want other users to be able to transfer the token until the official launch. We have implemented a flag that prevents transfers from anyone who is not the contract owner until we allow transfers. This feature is controlled by the makeTransferable() and makeNonTransferable() functions.

## Pausable
ERC20 token with pausable token transfers, minting and burning.

Useful for scenarios such as preventing trades until the end of an evaluation period, or having an emergency switch for freezing all token transfers in the event of a large bug.

## Set New Wallet Address
The setNewWalletAddress(uint8 wallet0or1, address newAddress) function allows for us to change the DAO treasury wallets that the transfer fee is sent to. This is useful so that we are able to change where the funds are stored in the future without redeploying the token contract





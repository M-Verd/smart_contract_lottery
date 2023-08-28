# smart_contract_lottery
This is a Smart Contract lottery made by me as a second project, following the tutorial from freeCodeCamp.org but changing it a bit.
The project uses a modified version of the pre-built chainlink-mix for Brownie and Chainlink VRF to obtain randomness.
Everything is intended to be tested and used on the Sepolia testnet only, so remember to add it to the Brownie Networks list. I do not take responsability over a different or improper usage.

## Usage
Once deployed the lottery is ready to be opened (which only the owner can do) and everybody is able to enter by paying a fee.
The fee to enter can be obtained by calling the getEntranceFee() function; the same fee, but expressed in USD can be obtained by calling getEntranceFeeInUSD(). Every player is allowed to get only one ticket per lottery session.
*This smart contract is not fully decentralized* because, at the willing time of the owner, he will be closing the lottery by calling the endLottery() function and extracting the random winner.
The winner is extracted by requesting a random number from Chainlink VRF. Once the randomness request is sent, the VRF coordinator will call the fulfillRandomWords(args) function, which will do the proper calculations in order to know which player will get the full prize.
Once closed, the lottery can be reset by the owner calling the resetLottery(args) function.

- The interact.py file provides a fast way to interact with the last deployed contract through the command line.

## Problems solved during the development and what I learned
Since the original tutorial was using Chainlink VRFv1 I wasn't able to use Sepolia as the main network to test and run the smart contract. Also, forking the mainnet didn't work, since the VRF Coordinator wasn't ready to listen at the events emitted by the lottery.
I had to study the Chainlink documentation and implement VRFv2 by my own to overcome this problem.

### Notes
Be sure to add a .env file to match the following evnironment variables:

1. export ETHERSCAN_TOKEN = {Your address}
2. export WEB3_INFURA_PROJECT_ID = {Your ID}

The first one is used to verify the deployed smart contract on the Sepolia Etherscan explorer, while the second is needed by Brownie to be interfaced with the Sepolia testnet through Infura.

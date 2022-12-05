# Decentralized Ranked Choice Voting Contract

## What is [Ranked Choice Voting](https://ballotpedia.org/Ranked-choice_voting_(RCV))?

A ranked-choice voting system (RCV) is an electoral system in which voters rank candidates by preference on their ballots. If a candidate wins a majority of first-preference votes, he or she is declared the winner. If no candidate wins a majority of first-preference votes, the candidate with the fewest first-preference votes is eliminated. First-preference votes cast for the failed candidate are eliminated, lifting the next-preference choices indicated on those ballots. A new tally is conducted to determine whether any candidate has won a majority of the adjusted votes. The process is repeated until a candidate wins an outright majority

The Smart Contract has 3 phases:
1. Phase One: 
- register as a candidate
- register as a voter

2. Phase Two: 
- voting

3. Phase Three:
- Count votes
- Get election results

## Usage

Step 1:

```shell
git clone git@github.com:kmiguel10/decentralized-ranked-choice-voting.git
cd decentralized-ranked-choice-voting
yarn
```

Step 2:
``` Create your own .env file and add required keys```

Step 3:
- To run unit tests
```shell
hh test
or
yarn hardhat test
```

- To check for coverage
```shell
hh coverage
or
yarn hardhat coverage
```

- To mock an election process

*This election will go into round 2 and produce a winner. Look at the console to observe the election process.*

```shell
hh run scripts/mockElection.ts --network localhost
or
yarn hardhat run scripts/mockElection.ts --network localhost
```

goerli testnet address: 0x60ac57F4bB99BBA027C037E3cE4988FF555d77EE


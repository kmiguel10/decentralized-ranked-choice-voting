# Decentralized Ranked Choice Voting Contract

## Rules

A ranked-choice voting system (RCV) is an electoral system in which voters rank candidates by preference on their ballots. If a candidate wins a majority of first-preference votes, he or she is declared the winner. If no candidate wins a majority of first-preference votes, the candidate with the fewest first-preference votes is eliminated. First-preference votes cast for the failed candidate are eliminated, lifting the next-preference choices indicated on those ballots. A new tally is conducted to determine whether any candidate has won a majority of the adjusted votes. The process is repeated until a candidate wins an outright majority

Step 1.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

legend:
*** - rules of the contract

Rules for Ranked Choice Voting
1.The first round of counting votes determines whether a candidate receives a majority (more than 50% of the vote) of the votes.
    a.If no one reaches majority then:
        1. Eliminate those who receive no 1st choice votes ***
        2. Eliminate the candidate with the fewest 1st votes
            i. if there are ties then eliminate tied candidates***
            ii. Distribute 2nd choice votes
    b. repeat process until winner is determined

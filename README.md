# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

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

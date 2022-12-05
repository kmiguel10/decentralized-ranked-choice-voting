const { ethers } = require("hardhat")
const { moveBlocks } = require("../utils/move-blocks")

async function registerCandidates() {
    //get contract
    const rankedChoiceContract = await ethers.getContract(
        "RankedChoiceContract"
    )
    //get users to register as candidates
    const { deployer, user1, user2, user3 } = await getNamedAccounts()

    const deployerAddressSigner = await ethers.getSigner(deployer)
    console.log(`Registering as a candidate and as a voter for ${deployer}`)
    const registerUserTx = await rankedChoiceContract.enterCandidate("Test1")
    const registerUserTxReceipt = await registerUserTx.wait(1)
    console.log(`registerUserTxReceipt ${registerUserTxReceipt}`)

    console.log(`Registering as a candidate and as a voter for ${user1}`)
    //use get signers to get an instance of the new address and use that instance to send transaction
    const user1AddressSigner = await ethers.getSigner(user1)
    const registerUser1Tx = await rankedChoiceContract
        .connect(user1AddressSigner)
        .enterCandidate("Test1")
    const registerUser1TxReceipt = await registerUser1Tx.wait(1)
    console.log(`registerUser1TxReceipt ${registerUser1TxReceipt}`)

    console.log(`Registering as a candidate and as a voter for ${user2}`)
    const user2AddressSigner = await ethers.getSigner(user2)
    const registerUser2Tx = await rankedChoiceContract
        .connect(user2AddressSigner)
        .enterCandidate("Test1")
    const registerUser2TxReceipt = await registerUser2Tx.wait(1)
    console.log(`registerUser1TxReceipt ${registerUser2TxReceipt}`)

    //at this point there are 3 candidates and 3 voters -check
    const checkCandidate1 = await rankedChoiceContract.checkIfCandidateExist(
        deployer
    )
    const checkVoter1 = await rankedChoiceContract.checkIfVoterExist(deployer)
    console.log(
        `Check if candidate: ${checkCandidate1} and voter: ${checkVoter1} exist`
    )

    const checkCandidate2 = await rankedChoiceContract.checkIfCandidateExist(
        user1
    )
    const checkVoter2 = await rankedChoiceContract.checkIfVoterExist(user1)
    console.log(
        `Check if candidate: ${checkCandidate2} and voter: ${checkVoter2} exist`
    )
    const checkCandidate3 = await rankedChoiceContract.checkIfCandidateExist(
        user2
    )
    const checkVoter3 = await rankedChoiceContract.checkIfVoterExist(user2)
    console.log(
        `Check if candidate: ${checkCandidate3} and voter: ${checkVoter3} exist`
    )

    //should return false
    const checkCandidate4 = await rankedChoiceContract.checkIfCandidateExist(
        user3
    )
    const checkVoter4 = await rankedChoiceContract.checkIfVoterExist(user3)
    console.log(
        `Check if candidate: ${checkCandidate4} and voter: ${checkVoter4} exist`
    )

    /// vote
    await rankedChoiceContract
        .connect(deployerAddressSigner)
        .vote(deployer, user1, user2)
    await rankedChoiceContract
        .connect(user1AddressSigner)
        .vote(deployer, user1, user2)
    await rankedChoiceContract
        .connect(user2AddressSigner)
        .vote(deployer, user1, user2)

    /// count vote
    await rankedChoiceContract.connect(deployerAddressSigner).countVotes()
    /// Get Winner
    const winner = await rankedChoiceContract
        .connect(deployerAddressSigner)
        .getWinner()

    console.log(`Winner is ${winner}`)

    if (network.config.chainId == 31337) {
        // Moralis has a hard time if you move more than 1 at once!
        await moveBlocks(1, (sleepAmount = 1000))
    }
}

registerCandidates()
    .then(() => process.exit(0))
    .catch((error) => {
        console.log(error)
        process.exit(1)
    })

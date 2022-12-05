import { getNamedAccounts, network, ethers } from "hardhat"
import { moveBlocks } from "../utils/move-blocks"

async function mockElection() {
    //Get contract
    const rankedChoiceContract = await ethers.getContract(
        "RankedChoiceContract"
    )
    const { user1, user2, user3, user4, user5, user6 } =
        await getNamedAccounts()

    //Register as candidates and voters
    console.log("--- Register as Candidates")
    const user1Adr = await ethers.getSigner(user1)
    await rankedChoiceContract.connect(user1Adr).enterCandidate("Candidate 1")
    const user2Adr = await ethers.getSigner(user2)
    await rankedChoiceContract.connect(user2Adr).enterCandidate("Candidate 2")
    const user3Adr = await ethers.getSigner(user3)
    await rankedChoiceContract.connect(user3Adr).enterCandidate("Candidate 3")
    const user4Adr = await ethers.getSigner(user4)
    await rankedChoiceContract.connect(user4Adr).enterCandidate("Candidate 4")
    const user5Adr = await ethers.getSigner(user5)
    await rankedChoiceContract.connect(user5Adr).enterCandidate("Candidate 5")
    const user6Adr = await ethers.getSigner(user6)
    await rankedChoiceContract.connect(user6Adr).enterCandidate("Candidate 6")

    console.log("--- Move time for 1 hour")
    network.provider.send("evm_increaseTime", [3600])
    network.provider.send("evm_mine", [])

    console.log("--- Perform Upkeep ---")
    //Move time and begin phase 2
    await rankedChoiceContract.performUpkeep([])

    console.log("--- Start Voting ---")
    //voter 1
    await rankedChoiceContract.connect(user1Adr).vote(user1, user2, user3)
    //voter 2
    await rankedChoiceContract.connect(user2Adr).vote(user1, user2, user3)

    //voter 3
    await rankedChoiceContract.connect(user3Adr).vote(user3, user2, user6)

    //voter 4
    await rankedChoiceContract.connect(user4Adr).vote(user4, user5, user6)

    //voter 5
    await rankedChoiceContract.connect(user5Adr).vote(user3, user2, user6)

    //voter 6
    await rankedChoiceContract.connect(user6Adr).vote(user5, user1, user6)

    console.log("--- Voting Ends ---")

    console.log("--- Move time for 1 hour")
    network.provider.send("evm_increaseTime", [3600])
    network.provider.send("evm_mine", [])

    //Move time and begin phase 3
    await rankedChoiceContract.performUpkeep([])

    if (network.config.chainId == 31337) {
        // Moralis has a hard time if you move more than 1 at once!
        await moveBlocks(1, 1000)
    }
}

mockElection()
    .then(() => process.exit(0))
    .catch((error) => {
        console.log(error)
        process.exit(1)
    })

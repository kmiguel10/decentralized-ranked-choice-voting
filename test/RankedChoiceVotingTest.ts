import { RankedChoiceContract } from "./../typechain-types/RankedChoiceContract"
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers"
import { expect, assert } from "chai"
import { ethers } from "hardhat"

describe("RankedChoiceVoting", function () {
    //fixture - deploy contract
    async function deployRankedChoiceVotingContract() {
        const [owner, user1, user2, user3] = await ethers.getSigners()
        const RankedChoiceContract = await ethers.getContractFactory(
            "RankedChoiceContract"
        )
        const rankedChoiceContract = await RankedChoiceContract.deploy()
        await rankedChoiceContract.deployed()
        return { rankedChoiceContract, owner, user1, user2, user3 }
    }

    //check that a new candidate is successdully createdand
    describe("Create candidate", function () {
        it("...emits an event after creating a candidate", async function () {
            const { rankedChoiceContract, owner } = await loadFixture(
                deployRankedChoiceVotingContract
            )
            expect(await rankedChoiceContract.enterCandidate("Test 1")).to.emit(
                rankedChoiceContract,
                "CandidateCreated"
            )
        })
    })
    //check that an event is emitted after candidate is created
})

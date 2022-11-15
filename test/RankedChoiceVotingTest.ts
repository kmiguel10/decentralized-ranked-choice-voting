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

        it("...creates a candidate after calling enterCandidate function", async function () {
            const { rankedChoiceContract, owner } = await loadFixture(
                deployRankedChoiceVotingContract
            )

            await rankedChoiceContract.enterCandidate("Test 1")
            const candidate = await rankedChoiceContract.getCandidateByAddress(
                owner.address
            )
            assert(
                candidate.walletAddress.toString() == owner.address.toString()
            )
        })

        it("...reverts if a candidate of the same address already exists", async function () {
            const { rankedChoiceContract, owner } = await loadFixture(
                deployRankedChoiceVotingContract
            )

            //enter a candidate
            await rankedChoiceContract.enterCandidate("Candidate1")

            await expect(rankedChoiceContract.enterCandidate("Test 1"))
                .to.be.revertedWithCustomError(
                    rankedChoiceContract,
                    "Voting_CandidateAlreadyExists"
                )
                .withArgs(owner.address)
        })
    })
})

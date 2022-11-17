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

    //fixture for withdraw tests
    async function withdrawFixture() {
        const [owner, user1, user2, user3] = await ethers.getSigners()
        const RankedChoiceContract = await ethers.getContractFactory(
            "RankedChoiceContract"
        )
        const rankedChoiceContract = await RankedChoiceContract.deploy()
        await rankedChoiceContract.deployed()
        await rankedChoiceContract.enterCandidate("Candidate 1")

        return { rankedChoiceContract, owner, user1, user2 }
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

        it("...emits a VoterRegistered event after creating a candidate", async function () {
            const { rankedChoiceContract } = await loadFixture(
                deployRankedChoiceVotingContract
            )
            expect(await rankedChoiceContract.enterCandidate("Test 1")).to.emit(
                rankedChoiceContract,
                "VoterRegistered"
            )
        })

        it("...reverts when attempting to register as a voter after entering as a candidate", async function () {
            const { rankedChoiceContract, owner } = await loadFixture(
                deployRankedChoiceVotingContract
            )
            await rankedChoiceContract.enterCandidate("Test 1")
            await expect(rankedChoiceContract.registerToVote())
                .to.be.revertedWithCustomError(
                    rankedChoiceContract,
                    "Voting_VoterIsAlreadyRegistered"
                )
                .withArgs(owner.address)
        })

        it("...creates 3 candidates and returns candidate count which is 3", async function () {
            const { rankedChoiceContract, owner, user1, user2 } =
                await loadFixture(deployRankedChoiceVotingContract)
            await rankedChoiceContract.enterCandidate("Test 1")
            await rankedChoiceContract.connect(user1).enterCandidate("Test 2")
            await rankedChoiceContract.connect(user2).enterCandidate("Test 3")
            const _numberOfCandidates =
                await rankedChoiceContract.getNumberOfCandidates()
            assert.equal(3, _numberOfCandidates)
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

    //withdraw candidate
    //withdraw and check for event
    //withdraw and attempt to withdraw again and revert with error candidate does not exist
    //withdraw and check the number of candidates
    //withdraw and enter and withdraw and check again
    describe("Withdraw candidate", function () {
        it("...emits an events after withdrawing candidate", async function () {
            const { rankedChoiceContract, owner } = await loadFixture(
                withdrawFixture
            )

            expect(await rankedChoiceContract.withdrawCandidate()).to.emit(
                rankedChoiceContract,
                "CandidateWithdrawn"
            )
        })

        it("...it reverts if the user attempts to withdraw a nonexistent candidate", async function () {
            const { rankedChoiceContract, owner } = await loadFixture(
                withdrawFixture
            )

            await rankedChoiceContract.withdrawCandidate()

            await expect(rankedChoiceContract.withdrawCandidate())
                .to.be.revertedWithCustomError(
                    rankedChoiceContract,
                    "Voting_CandidateAddressDoesNotExist"
                )
                .withArgs(owner.address)
        })

        it("...returns the number of candidate after withdrawing", async function () {
            const { rankedChoiceContract, owner, user1, user2 } =
                await loadFixture(withdrawFixture)

            await rankedChoiceContract
                .connect(user1)
                .enterCandidate("Candidate 2")
            await rankedChoiceContract
                .connect(user2)
                .enterCandidate("Candidate 3")
            await rankedChoiceContract.withdrawCandidate()

            const _numOfCandidates =
                await rankedChoiceContract.getNumberOfCandidates()

            assert.equal(2, _numOfCandidates)
        })

        it("...registers a candidate again after registering a candidate and withdrawing", async function () {
            const { rankedChoiceContract, owner, user1, user2 } =
                await loadFixture(withdrawFixture)

            await rankedChoiceContract.withdrawCandidate()
            await rankedChoiceContract.enterCandidate("Candidate 2")

            const _numOfCandidates =
                await rankedChoiceContract.getNumberOfCandidates()

            assert.equal(1, _numOfCandidates)
        })
    })
})

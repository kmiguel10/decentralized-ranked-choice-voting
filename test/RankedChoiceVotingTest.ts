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

    //fixture for voting() tests
    async function votingFixture() {
        //need to vote
        const [owner, user1, user2, user3] = await ethers.getSigners()
        const RankedChoiceContract = await ethers.getContractFactory(
            "RankedChoiceContract"
        )
        const rankedChoiceContract = await RankedChoiceContract.deploy()
        await rankedChoiceContract.deployed()
        //enter candidates
        await rankedChoiceContract.enterCandidate("Candidate 1")
        await rankedChoiceContract.connect(user1).enterCandidate("Candidate 2")
        await rankedChoiceContract.connect(user2).enterCandidate("Candidate 3")

        //connect back to the main user
        await rankedChoiceContract.connect(owner)

        return { rankedChoiceContract, owner, user1, user2, user3 }
    }

    //fixture for countVoting - owner votes
    async function countingVotesFixture() {
        const [owner, user1, user2, user3] = await ethers.getSigners()
        const RankedChoiceContract = await ethers.getContractFactory(
            "RankedChoiceContract"
        )
        const rankedChoiceContract = await RankedChoiceContract.deploy()
        await rankedChoiceContract.deployed()
        //enter candidates
        await rankedChoiceContract.enterCandidate("Candidate 1")
        await rankedChoiceContract.connect(user1).enterCandidate("Candidate 2")
        await rankedChoiceContract.connect(user2).enterCandidate("Candidate 3")

        //connect back to the main user
        await rankedChoiceContract.connect(owner)

        //owner votes
        await rankedChoiceContract.vote(
            owner.address,
            user1.address,
            user2.address
        )

        return { rankedChoiceContract, owner, user1, user2, user3 }
    }

    //fixture to test distributeVotes - doesnt include voting
    async function distributeVotesFixture() {
        const [owner, user1, user2, user3, user4, user5] =
            await ethers.getSigners()
        const RankedChoiceContract = await ethers.getContractFactory(
            "RankedChoiceContract"
        )
        const rankedChoiceContract = await RankedChoiceContract.deploy()
        await rankedChoiceContract.deployed()
        //enter candidates
        await rankedChoiceContract.enterCandidate("Candidate 1")
        await rankedChoiceContract.connect(user1).enterCandidate("Candidate 2")
        await rankedChoiceContract.connect(user2).enterCandidate("Candidate 3")

        await rankedChoiceContract.connect(user3).enterCandidate("Candidate 4")

        await rankedChoiceContract.connect(user4).enterCandidate("Candidate 5")

        await rankedChoiceContract.connect(user5).enterCandidate("Candidate 6")

        //connect back to the main user
        await rankedChoiceContract.connect(owner)

        //owner votes
        // await rankedChoiceContract.vote(
        //     owner.address,
        //     user1.address,
        //     user2.address
        // )

        return {
            rankedChoiceContract,
            owner,
            user1,
            user2,
            user3,
            user4,
            user5,
        }
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

        it("...returns the number of registered voters", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(deployRankedChoiceVotingContract)

            await rankedChoiceContract.enterCandidate("test 1")
            await rankedChoiceContract.connect(user1).enterCandidate("test 2")
            await rankedChoiceContract.connect(user2).enterCandidate("test 2")
            await rankedChoiceContract.connect(user3).registerToVote()

            const _numOfVoters = await rankedChoiceContract.numberOfVoters()

            assert.equal(_numOfVoters, 4)
        })
    })

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

    describe("Vote for candidates", function () {
        it("...emits an event after voting for candidates", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(votingFixture)

            expect(
                await rankedChoiceContract.vote(
                    owner.address,
                    user1.address,
                    user2.address
                )
            ).to.emit(rankedChoiceContract, "Voted")
        })

        it("...checks that after voting, candidate 1 has 1 point", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(votingFixture)
            await rankedChoiceContract.vote(
                owner.address,
                user1.address,
                user2.address
            )

            const _candidate1 =
                await rankedChoiceContract.getCandidateByAddress(owner.address)

            assert.equal(_candidate1.firstVotesCount, 1)
        })
        it("...checks that after voting, candidate 2 has 0 points", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(votingFixture)
            await rankedChoiceContract.vote(
                owner.address,
                user1.address,
                user2.address
            )
            const _candidate2 =
                await rankedChoiceContract.getCandidateByAddress(user1.address)

            assert.equal(_candidate2.firstVotesCount, 0)
        })
        it("...checks that after voting, candidate 3 has 0 point", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(votingFixture)
            await rankedChoiceContract.vote(
                owner.address,
                user1.address,
                user2.address
            )
            const _candidate3 =
                await rankedChoiceContract.getCandidateByAddress(user2.address)
            assert.equal(_candidate3.firstVotesCount, 0)
        })

        it("...checks that after voting from 3 different voters, candidate 1 has 3 points", async function () {
            const { rankedChoiceContract, owner, user1, user2 } =
                await loadFixture(votingFixture)
            await rankedChoiceContract.vote(
                owner.address,
                user1.address,
                user2.address
            )
            await rankedChoiceContract
                .connect(user1)
                .vote(owner.address, user1.address, user2.address)

            await rankedChoiceContract
                .connect(user2)
                .vote(owner.address, user1.address, user2.address)

            const _candidate1 =
                await rankedChoiceContract.getCandidateByAddress(owner.address)

            assert.equal(_candidate1.firstVotesCount, 3)
        })
        it("...checks that after voting from two different voters, candidate 2 has 1 point", async function () {
            const { rankedChoiceContract, owner, user1, user2 } =
                await loadFixture(votingFixture)
            await rankedChoiceContract.vote(
                owner.address,
                user1.address,
                user2.address
            )
            await rankedChoiceContract
                .connect(user1)
                .vote(user1.address, owner.address, user2.address)
            const _candidate2 =
                await rankedChoiceContract.getCandidateByAddress(user1.address)

            assert.equal(_candidate2.firstVotesCount, 1)
        })
        it("...checks that after voting from two different voters, candidate 3 has 0 point", async function () {
            const { rankedChoiceContract, owner, user1, user2 } =
                await loadFixture(votingFixture)
            await rankedChoiceContract.vote(
                owner.address,
                user1.address,
                user2.address
            )
            await rankedChoiceContract
                .connect(user1)
                .vote(owner.address, user1.address, user2.address)

            const _candidate3 =
                await rankedChoiceContract.getCandidateByAddress(user2.address)
            assert.equal(_candidate3.firstVotesCount, 0)
        })

        it("...checks that after voting, the voter has hasVoted flag equal to true", async function () {
            const { rankedChoiceContract, owner, user1, user2 } =
                await loadFixture(votingFixture)
            await rankedChoiceContract.vote(
                owner.address,
                user1.address,
                user2.address
            )

            const _voter = await rankedChoiceContract.getVoterByAddress(
                owner.address
            )
            assert.equal(_voter.hasVoted, true)
        })

        it("...checks that after voting, the voter has stored 3 choices in voter struct", async function () {
            const { rankedChoiceContract, owner, user1, user2 } =
                await loadFixture(votingFixture)
            await rankedChoiceContract.vote(
                owner.address,
                user1.address,
                user2.address
            )

            const _voter = await rankedChoiceContract.getVoterByAddress(
                owner.address
            )
            assert.equal(_voter.voterChoices.length, 3)
        })

        it("...reverts when attempting to cast vote again after voting", async function () {
            const { rankedChoiceContract, owner, user1, user2 } =
                await loadFixture(votingFixture)
            await rankedChoiceContract.vote(
                owner.address,
                user1.address,
                user2.address
            )
            await expect(
                rankedChoiceContract.vote(
                    owner.address,
                    user1.address,
                    user2.address
                )
            )
                .to.be.revertedWithCustomError(
                    rankedChoiceContract,
                    "PhaseTwo_AlreadyVoted"
                )
                .withArgs(owner.address)
        })

        it("...reverts when voting with an unregistered voter", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(votingFixture)
            await rankedChoiceContract.vote(
                owner.address,
                user1.address,
                user2.address
            )
            await expect(
                rankedChoiceContract
                    .connect(user3)
                    .vote(owner.address, user1.address, user2.address)
            )
                .to.be.revertedWithCustomError(
                    rankedChoiceContract,
                    "Voting_VoterDoesNotExist"
                )
                .withArgs(user3.address)
        })

        it("...reverts if candidate receives multiple votes from the same voter", async function () {
            const { rankedChoiceContract, owner, user1 } = await loadFixture(
                votingFixture
            )
            await expect(
                rankedChoiceContract.vote(
                    owner.address,
                    user1.address,
                    owner.address
                )
            )
                .to.be.revertedWithCustomError(
                    rankedChoiceContract,
                    "PhaseTwo_CandidateCannotReceiveMultipleVotesFromTheSameVoter"
                )
                .withArgs(owner.address)
        })

        it("...reverts if voting for a nonexistent candidate", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(votingFixture)
            await expect(
                rankedChoiceContract.vote(
                    owner.address,
                    user1.address,
                    user3.address
                )
            )
                .to.be.revertedWithCustomError(
                    rankedChoiceContract,
                    "Voting_CandidateAddressDoesNotExist"
                )
                .withArgs(user3.address)
        })

        it("...returns the number of voters who already voted", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(votingFixture)

            await rankedChoiceContract.connect(user3).registerToVote()

            await rankedChoiceContract
                .connect(owner)
                .vote(owner.address, user1.address, user2.address)

            await rankedChoiceContract
                .connect(user1)
                .vote(owner.address, user1.address, user2.address)

            await rankedChoiceContract
                .connect(user2)
                .vote(owner.address, user1.address, user2.address)

            await rankedChoiceContract
                .connect(user3)
                .vote(owner.address, user1.address, user2.address)

            const _numberOfVotersVoted =
                await rankedChoiceContract.numberOfVotersVoted()

            assert.equal(_numberOfVotersVoted, 4)
        })
    })

    //TODO checks for countVotes()
    describe("Count Votes", function () {
        // test that winner is picked
        //  - events are emitted
        //test for checks before counting
        //  - reverts
        //test for count()
        // - 0 1st votes candidates are eliminated

        it("...returns the address of the winner after counting votes", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(countingVotesFixture)

            await rankedChoiceContract
                .connect(user1)
                .vote(owner.address, user1.address, user2.address)

            await rankedChoiceContract
                .connect(user2)
                .vote(owner.address, user1.address, user2.address)

            await rankedChoiceContract.connect(owner).countVotes()

            const winner = await rankedChoiceContract.connect(owner).getWinner()

            assert.equal(winner, owner.address)
        })

        it("...emits an event after countingVotes and declaring a winner", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(countingVotesFixture)

            await rankedChoiceContract
                .connect(user1)
                .vote(owner.address, user1.address, user2.address)

            await rankedChoiceContract
                .connect(user2)
                .vote(owner.address, user1.address, user2.address)

            await rankedChoiceContract.connect(owner)

            expect(
                await rankedChoiceContract.connect(owner).countVotes()
            ).to.emit(rankedChoiceContract, "CountVotes_CandidateWins")
        })

        it("...reverts if getWinner() function is called before votes are counted", async function () {
            const { rankedChoiceContract, owner, user1, user2, user3 } =
                await loadFixture(countingVotesFixture)

            await rankedChoiceContract
                .connect(user1)
                .vote(owner.address, user1.address, user2.address)

            await rankedChoiceContract
                .connect(user2)
                .vote(owner.address, user1.address, user2.address)

            await expect(
                rankedChoiceContract.getWinner()
            ).to.be.revertedWithCustomError(
                rankedChoiceContract,
                "PhaseThree_ThereIsNoWinnerYet"
            )
        })

        //Test distributeVotes() function

        it("...returns the address of the winner after 2 rounds", async function () {
            const {
                rankedChoiceContract,
                owner,
                user1,
                user2,
                user3,
                user4,
                user5,
            } = await loadFixture(distributeVotesFixture)

            //voter 1
            await rankedChoiceContract
                .connect(owner)
                .vote(owner.address, user1.address, user2.address)

            //voter 2
            await rankedChoiceContract
                .connect(user1)
                .vote(owner.address, user1.address, user2.address)

            //voter 3
            await rankedChoiceContract
                .connect(user2)
                .vote(user2.address, user1.address, user5.address)

            //voter 4
            await rankedChoiceContract
                .connect(user3)
                .vote(user3.address, user4.address, user5.address)

            //voter 5
            await rankedChoiceContract
                .connect(user4)
                .vote(user2.address, user1.address, user5.address)

            //voter 6
            await rankedChoiceContract
                .connect(user5)
                .vote(user4.address, owner.address, user5.address)

            //count votes
            await rankedChoiceContract.connect(owner).countVotes()

            const winner = await rankedChoiceContract.connect(owner).getWinner()

            assert.equal(winner, owner.address)
        })

        //test a scenario when going to the next round, and distributing the points, the 2nd choice candidate does not exist, but the third does... what do I do? Do i instead give the points to the 3rd candidate?
    })
})

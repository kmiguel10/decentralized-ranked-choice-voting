// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// Errors ///
error ActionIsNotAllowedAtThisStage(
    address user,
    uint16 currentPhase,
    uint16 functionPhase
);
error OnlyElectionAdministratorIsAllowedAccess(address user);
error Voting_CandidateAlreadyExists(address candidateAddress);
error Voting_CandidateAddressDoesNotExist(address candidateAddress);
error Voting_VoterIsAlreadyRegistered(address voterAddress);
error Voting_VoterDoesNotExist(address voterAddress);
error PhaseTwo_RegisteringPhaseIsOver(address voterAddress);
error PhaseTwo_EnteringCandidatePhaseIsOver(address voterAddress);
error PhaseTwo_CannotWithdrawPhaseOneIsOver(address voterAddress);
error PhaseTwo_AlreadyVoted(address voterAddress);
error PhaseTwo_VoterIsNotRegistered(address voterAddress);
error PhaseTwo_CandidateCannotReceiveMultipleVotesFromTheSameVoter(
    address voterAddress
);
error PhaseThree_ThereIsNoWinnerYet();

/**
 * @title A Ranked Choice Voting Smart Contract
 * @author Kent Miguel
 * @dev uses chainlink automation to end and start register, voting, and count phases
 */
contract RankedChoiceContract {
    using Counters for Counters.Counter;

    /////////////////////
    //     Events      //
    /////////////////////
    event CandidateCreated(
        uint256 indexed id,
        string indexed name,
        address indexed walletAddress
    );

    event CandidateWithdrawn(
        uint256 indexed id,
        string indexed name,
        address indexed walletAddress
    );

    event VoterRegistered(uint256 indexed id, address indexed walletAddress);

    event Voted(
        uint256 indexed id,
        address indexed voterAddress,
        address[] voterChoices,
        address firstChoice,
        address secondChoice,
        address thirdChoice
    );

    event CountVotes_DeletedReceivedZeroFirstChoiceVotes(
        address indexed candidateAddress,
        uint256 firstVoteCounts,
        uint256 round
    );

    event CountVotes_CandidateWinsThresholdReached(
        address indexed candidateAddress,
        uint256 firstVoteCounts,
        uint256 round
    );

    event CountVotes_CandidateWinsOnlyCandidateLeft(
        address indexed candidateAddress,
        uint256 firstVoteCounts,
        uint256 round
    );

    event CountVotes_CandidateEliminatedLowestVoteCount(
        address indexed candidateAddress,
        uint256 firstVoteCounts,
        uint256 round
    );

    event CountVotes_CandidateReceivedVoterFromTo(
        address indexed voterAddress,
        address fromCandidate,
        address toCandidate,
        uint256 round
    );

    //Emit event 2nd choice doesnt exist so give vote to 3rd choice
    event CountVotes_SecondChoiceIsEliminated(
        address indexed voterAddress,
        address thirdChoice,
        uint256 round
    );

    event CountVotes_ExhaustedVoterChoices(
        address indexed voterAddress,
        uint256 round
    );

    event CountVotes_AllCandidatesAreTiedAfterCount(uint256 round);

    /// Candidate variables ///
    // we might only need 1st choice vote counts... the rest of the vote counts might only be needed if we alocate the points there for visual and metric analysis for the front end...
    struct Candidate {
        uint256 id;
        string name;
        address walletAddress;
        address[] firstChoiceVoters;
        uint256 firstVotesCount;
        bool isEliminated;
        bool isWinner;
        uint256 totalVotesCount;
    }

    ///Voter choice will be stored in an array , the push and pop nature can be used as a stack, store 3rd choice first and 1st choice last... that way we can keep popping choices for each round.
    struct Voter {
        uint256 voterId;
        // string name;
        address walletAddress;
        address[] voterChoices;
        bool hasVoted;
        bool isRegistered;
        bool isCandidate;
    }

    address[] private candidateAddresses; //array of candidates - might be able to make enumerable
    //mapping(uint256 => mapping(address => Candidate)) private addressToCandidate;
    mapping(address => Candidate) private addressToCandidate; //TODO might be a good idea to use enumerable type from OpenZeppeling
    mapping(address => Voter) private registeredVoters; //TODO might be a good idea to use enumerable type from OpenZeppeling

    /// Election global variables ///
    address public electionAdmin;
    bool private isWinnerPicked; //TODO initialize to false in the constructor
    bool private areAllActiveCandidatesTied; //initialize to false in constructor
    Counters.Counter private candidateIdCounter;
    Counters.Counter private numberOfCandidates;
    Counters.Counter private voterIdCounter;
    Counters.Counter public numberOfVoters;
    Counters.Counter public numberOfVotersVoted;
    uint16 private currentPhase;

    /// phase 3 variables
    address public winner;
    Counters.Counter private round;
    address[] private firstChoiceVotersAddresses; //might be able to make enumerable
    Counters.Counter private activeCandidatesCounter;

    /////////////////////
    ///  Modifiers  ///
    /////////////////////
    modifier onlyExistingVoter() {
        if (checkIfVoterExist(msg.sender) == false) {
            revert Voting_VoterDoesNotExist(msg.sender);
        }
        _;
    }

    modifier onlyExistingCandidateChoices(
        address firstChoice,
        address secondChoice,
        address thirdChoice
    ) {
        //checks if candidates exist
        if (checkIfCandidateExist(firstChoice) == false) {
            revert Voting_CandidateAddressDoesNotExist(firstChoice);
        }
        if (checkIfCandidateExist(secondChoice) == false) {
            revert Voting_CandidateAddressDoesNotExist(secondChoice);
        }
        if (checkIfCandidateExist(thirdChoice) == false) {
            revert Voting_CandidateAddressDoesNotExist(thirdChoice);
        }
        _;
    }

    modifier onlyUniqueChoices(
        address firstChoice,
        address secondChoice,
        address thirdChoice
    ) {
        //checks for candidates must exist - there must be an efficient way, maybe use a mapping
        if (
            firstChoice == secondChoice ||
            firstChoice == thirdChoice ||
            secondChoice == thirdChoice
        ) {
            revert PhaseTwo_CandidateCannotReceiveMultipleVotesFromTheSameVoter(
                msg.sender
            );
        }
        _;
    }

    modifier onlyElectionAdmin() {
        if (msg.sender != electionAdmin) {
            revert OnlyElectionAdministratorIsAllowedAccess(msg.sender);
        }
        _;
    }

    modifier ifCurrentPhaseIsActive(uint16 phase) {
        if (phase != currentPhase) {
            revert ActionIsNotAllowedAtThisStage(
                msg.sender,
                currentPhase,
                phase
            );
        }
        _;
    }

    /////////////////////
    // Constructor //
    /////////////////////

    constructor() {
        electionAdmin = msg.sender;
        isWinnerPicked = false;
        currentPhase = 1;
    }

    /////////////////////
    // Main Functions //
    ////////////////////

    /// --- Phase 1 Functions --- ///
    /**
     * @notice this functions registers candidates
     * @param _candidateName The name of the candidate
     * @dev Candidate will be registered to vote automatically and will be disabled when register phase is over
     */
    function enterCandidate(
        string memory _candidateName
    ) external ifCurrentPhaseIsActive(1) {
        if (checkIfCandidateExist(msg.sender)) {
            revert Voting_CandidateAlreadyExists(msg.sender);
        }

        candidateIdCounter.increment();
        numberOfCandidates.increment();
        activeCandidatesCounter.increment();
        uint256 _candidateId = candidateIdCounter.current();
        address[] memory _firstChoiceVoters;

        Candidate memory candidate = Candidate(
            _candidateId,
            _candidateName,
            // _candidateAddress,
            msg.sender,
            _firstChoiceVoters,
            0,
            false,
            false,
            0
        );

        //store candidate struct in mapping
        addressToCandidate[msg.sender] = candidate;

        //push to candidate address
        candidateAddresses.push(msg.sender);

        emit CandidateCreated(
            candidate.id,
            candidate.name,
            candidate.walletAddress
        );

        //if entering again after withdrawing then doesnt need to register again
        if (registeredVoters[msg.sender].voterId <= 0) {
            registerToVote();
            registeredVoters[msg.sender].isCandidate = true;
        }
    }

    /**
     * @notice this function registers voters to vote for phase 2: Voting
     * @dev
     * 1. users who enter as a candidate will be registered automatically, will be disabled at the end of phase 1
     * 2. Optimize this by accessing struct once and store it in a local variable and use that for the checks.. see coverage first and gas viewer
     *
     */
    function registerToVote() public ifCurrentPhaseIsActive(1) {
        //check for non-candidate voters
        if (
            checkIfVoterExist(msg.sender) &&
            registeredVoters[msg.sender].isCandidate == false
        ) {
            revert Voting_VoterIsAlreadyRegistered(msg.sender);
        }
        //check for candidates
        if (
            checkIfVoterExist(msg.sender) &&
            registeredVoters[msg.sender].isCandidate == true
        ) {
            revert Voting_VoterIsAlreadyRegistered(msg.sender);
        }

        voterIdCounter.increment();
        numberOfVoters.increment();
        uint256 _voterId = voterIdCounter.current();
        address[] memory _Voterchoices;

        Voter memory voter = Voter(
            _voterId,
            msg.sender,
            _Voterchoices,
            false,
            true,
            false
        );

        registeredVoters[msg.sender] = voter;
        emit VoterRegistered(_voterId, msg.sender);
    }

    /**
     * @notice withdraws from election
     * @dev checks:
     *      1 . disabled when register phase is over
     *      2. check that person who registered are only the one who can withdraw
     *      3. check that cannot withdraw if entry does not exist
     */
    function withdrawCandidate() external ifCurrentPhaseIsActive(1) {
        if (addressToCandidate[msg.sender].id <= 0) {
            revert Voting_CandidateAddressDoesNotExist(msg.sender);
        }

        Candidate memory _candidate = addressToCandidate[msg.sender];

        delete (addressToCandidate[msg.sender]);
        numberOfCandidates.decrement();
        activeCandidatesCounter.decrement();
        emit CandidateWithdrawn(
            _candidate.id,
            _candidate.name,
            _candidate.walletAddress
        );
    }

    /// Phase 2 Functions ///

    /**
     * @notice this function turns on the phase 2 (voting) switch which disables phase 1 functionalities
     * @dev look for checks
     * @dev change to private after testing...??
     */
    function beginPhaseTwo()
        public
        onlyElectionAdmin
        ifCurrentPhaseIsActive(1)
    {
        currentPhase = 2;
    }

    /**
     * @notice this function allows voters to vote their choices in the election
     * @dev come back to implement checks:
     * 1. phase switches
     * 2. Undervote is not allowed meaning all voters must choose three candidates in order to cast vote
     */
    function vote(
        address firstChoice,
        address secondChoice,
        address thirdChoice
    )
        public
        onlyExistingVoter
        onlyExistingCandidateChoices(firstChoice, secondChoice, thirdChoice)
        onlyUniqueChoices(firstChoice, secondChoice, thirdChoice)
        ifCurrentPhaseIsActive(2)
    {
        Voter storage _voter = registeredVoters[msg.sender];

        if (_voter.isRegistered == false) {
            revert PhaseTwo_VoterIsNotRegistered(msg.sender);
        }

        if (_voter.hasVoted == true) {
            revert PhaseTwo_AlreadyVoted(msg.sender);
        }

        //Assign vote to firstChoice
        Candidate storage _firstChoice = addressToCandidate[firstChoice];
        _firstChoice.firstChoiceVoters.push(msg.sender);
        _firstChoice.firstVotesCount = _firstChoice.firstChoiceVoters.length;
        addressToCandidate[firstChoice] = _firstChoice;

        //add voter's choices
        //add 1st choice last in order to pop in this order 1st -> 2nd -> 3rd for each round
        _voter.voterChoices.push(thirdChoice);
        _voter.voterChoices.push(secondChoice);
        _voter.voterChoices.push(firstChoice);

        //change flags
        _voter.hasVoted = true;
        registeredVoters[msg.sender] = _voter;
        numberOfVotersVoted.increment();

        emit Voted(
            _voter.voterId,
            _voter.walletAddress,
            _voter.voterChoices,
            firstChoice,
            secondChoice,
            thirdChoice
        );
    }

    /// Phase 3: Count Votes
    // beginPhase3()
    function beginPhaseThree()
        public
        onlyElectionAdmin
        ifCurrentPhaseIsActive(2)
    {
        currentPhase = 3;
    }

    /**
     * @notice this function calculates the votes to get the winner
     * @dev can only be called after phase3 begins and only by the deployer
     */
    function countVotes() public onlyElectionAdmin ifCurrentPhaseIsActive(3) {
        ///TODO checks
        // onlyDeployer can initiate vote count
        //if phase2 is over - check flags

        uint256 totalPossibleVotes = numberOfVotersVoted.current();
        uint256 threshold = (totalPossibleVotes / 2) + 1;

        //loop until winner is found or tied
        while (isWinnerPicked == false && areAllActiveCandidatesTied == false) {
            // calculate total votes for each candidates
            countFirstChoiceVotes(threshold);

            console.log(
                "isWinnerPicked before entering distributeVotes",
                isWinnerPicked
            );
            console.log(
                "First choice votes array length",
                firstChoiceVotersAddresses.length
            );
            console.log(
                "Number of active candidates left: ",
                activeCandidatesCounter.current()
            );

            if (
                isWinnerPicked == false && areAllActiveCandidatesTied == false
            ) {
                console.log("Distributing votes");
                distributeVotes();
                console.log(
                    "Number of candidates after distributing votes",
                    activeCandidatesCounter.current()
                );
            } else if (
                isWinnerPicked == false && areAllActiveCandidatesTied == true
            ) {
                console.log("All candidates are tied after counting votes");
                emit CountVotes_AllCandidatesAreTiedAfterCount(round.current());
            }
        }
    }

    /**
     * @notice this is a helper function for countVotes() to count firstChoice votes for each candidate
     */
    function countFirstChoiceVotes(
        uint256 _threshold
    ) private onlyElectionAdmin ifCurrentPhaseIsActive(3) {
        round.increment();
        console.log("----- COUNT FIRST CHOICE VOTES -----");
        console.log("ROUND: ", round.current());

        uint256 highestVote = 0;
        uint256 lowestVote = _threshold;

        console.log("HighestVote", highestVote);
        console.log("LowestVote", lowestVote);
        console.log("Number of candidates", activeCandidatesCounter.current());

        for (uint256 i = 0; i < numberOfCandidates.current(); i++) {
            address _candidateAddress = candidateAddresses[i];

            if (checkIfCandidateExist(_candidateAddress) == true) {
                Candidate memory _candidate = addressToCandidate[
                    _candidateAddress
                ];

                console.log(
                    "----- Checking candidate: -----",
                    _candidateAddress,
                    " at index ",
                    i
                );

                console.log("Number of votes: ", _candidate.firstVotesCount);

                //Delete 0 firstChoice getters
                if (_candidate.firstVotesCount == 0) {
                    console.log(
                        "Deleting 0 vote candidate: ",
                        _candidateAddress
                    );
                    // delete candidate from mapping
                    delete (addressToCandidate[_candidateAddress]);

                    //emit Event - received 0 votes
                    emit CountVotes_DeletedReceivedZeroFirstChoiceVotes(
                        _candidateAddress,
                        _candidate.firstVotesCount,
                        round.current()
                    );
                    activeCandidatesCounter.decrement();
                } else if (_candidate.firstVotesCount >= _threshold) {
                    highestVote = _candidate.firstVotesCount;
                    winner = _candidate.walletAddress;
                    isWinnerPicked = true;
                    console.log("Reached threshhold found winner", winner);
                    emit CountVotes_CandidateWinsThresholdReached(
                        winner,
                        highestVote,
                        round.current()
                    );
                }
                //Compare vote count if candidate is still active
                if (checkIfCandidateExist(_candidateAddress) == true) {
                    if (_candidate.firstVotesCount <= lowestVote) {
                        //how do we keep track of the lowest votes
                        lowestVote = _candidate.firstVotesCount;
                        console.log("lowestVote after comparison", lowestVote);
                    }
                    if (_candidate.firstVotesCount > highestVote) {
                        //keeps track of highest vote
                        highestVote = _candidate.firstVotesCount;
                        console.log("highestVote after comparison", lowestVote);
                    }
                }

                console.log(
                    "--- Finished counting votes for candidate ----",
                    i
                );
            }
        }
        //Evaluate if all candidates are tied after counting votes
        if (highestVote == lowestVote) {
            //this means there is a tie
            areAllActiveCandidatesTied = true;
        }

        //get the lowest vote getters at the end of the round and eliminate & save the firstChoiceVoters to array
        if (isWinnerPicked == false && areAllActiveCandidatesTied == false) {
            console.log("--- Start eliminating lowest vote candidates ----");
            console.log("Highest vote", highestVote);
            console.log("Lowest vote", lowestVote);

            for (uint256 i = 0; i < numberOfCandidates.current(); i++) {
                address _candidateAddress = candidateAddresses[i];

                if (checkIfCandidateExist(_candidateAddress) == true) {
                    Candidate memory _candidate = addressToCandidate[
                        _candidateAddress
                    ];

                    //if candidate received lowest vote, then eliminate and store firstVote voters to array to be distributed
                    if (_candidate.firstVotesCount == lowestVote) {
                        _candidate.isEliminated = true;
                        emit CountVotes_CandidateEliminatedLowestVoteCount(
                            _candidate.walletAddress,
                            _candidate.firstVotesCount,
                            round.current()
                        );
                        console.log(
                            "Candidate received the lowest votes and eliminated",
                            _candidate.walletAddress
                        );
                        console.log(
                            "...with vote count: ",
                            _candidate.firstVotesCount
                        );
                        if (_candidate.firstVotesCount > 0) {
                            console.log(
                                "These voters will go to their next choice: "
                            );
                            for (
                                uint256 j = 0;
                                j < _candidate.firstVotesCount;
                                j++
                            ) {
                                firstChoiceVotersAddresses.push(
                                    _candidate.firstChoiceVoters[j]
                                );
                                console.log(
                                    "...",
                                    _candidate.firstChoiceVoters[j]
                                );
                            }
                        }

                        //delete candidate
                        delete (addressToCandidate[_candidateAddress]);
                        activeCandidatesCounter.decrement();
                    }
                    //save candidate with highestVote as winner
                    if (_candidate.firstVotesCount == highestVote) {
                        winner = _candidate.walletAddress;
                    }
                }
            }

            //at the end of the loop evaluate if there's only 1 candidate left
            if (activeCandidatesCounter.current() == 1) {
                Candidate memory _candidate = addressToCandidate[winner];
                // if there is only 1 active candidate left then that is the winner
                highestVote = _candidate.firstVotesCount;
                winner = _candidate.walletAddress;
                isWinnerPicked = true;
                console.log("Only one candidate left, found winner", winner);
                emit CountVotes_CandidateWinsOnlyCandidateLeft(
                    winner,
                    highestVote,
                    round.current()
                );
            }
            console.log("---Finished eliminating lowest vote candidates ---");
        }
    }

    /**
     * @notice this function distributes the first choice votes of the eliminated (lowest) vote candidates to their next ranked candidates
     */
    function distributeVotes()
        private
        onlyElectionAdmin
        ifCurrentPhaseIsActive(3)
    {
        //traverse firstChoiceVoters addresses to get address
        console.log(
            "--- Distribute votes from lowest vote candidates ---",
            firstChoiceVotersAddresses.length
        );

        for (uint256 i = 0; i < firstChoiceVotersAddresses.length; i++) {
            //get Voter
            Voter storage _voter = registeredVoters[
                firstChoiceVotersAddresses[i]
            ];

            console.log(
                "--- Distribute voter: ---",
                firstChoiceVotersAddresses[i]
            );

            //pop the 1st choice vote
            if (_voter.voterChoices.length > 0) {
                address _fromCandidate = _voter.voterChoices[
                    _voter.voterChoices.length - 1
                ];
                _voter.voterChoices.pop();
                //access the next choice - get length of voterChoices-1 as index
                if (_voter.voterChoices.length > 0) {
                    //distribute vote for the next choice
                    uint256 index = _voter.voterChoices.length - 1;
                    //check if the second choice is already eliminated, then pop and use the 3rd choice
                    if (
                        checkIfCandidateExist(_voter.voterChoices[index]) ==
                        false
                    ) {
                        _voter.voterChoices.pop();
                        if (_voter.voterChoices.length > 0) {
                            index = _voter.voterChoices.length - 1;
                            console.log(
                                "Next candidate is eliminated so distribute the next choice candidate (3rd voter) :",
                                _voter.voterChoices[index],
                                ", from voter : ",
                                _voter.walletAddress
                            );
                            emit CountVotes_SecondChoiceIsEliminated(
                                _voter.walletAddress,
                                _voter.voterChoices[index],
                                round.current()
                            );
                        } else {
                            console.log(
                                "All of the voter's candidate are eliminated for voter: ",
                                _voter.walletAddress
                            );
                            emit CountVotes_ExhaustedVoterChoices(
                                _voter.walletAddress,
                                round.current()
                            );
                        }
                    }
                    //check if candidate exists and index is within bounds
                    if (
                        checkIfCandidateExist(_voter.voterChoices[index]) &&
                        index >= 0
                    ) {
                        Candidate storage _candidate = addressToCandidate[
                            _voter.voterChoices[index]
                        ];
                        _candidate.firstChoiceVoters.push(_voter.walletAddress);
                        _candidate.firstVotesCount = _candidate
                            .firstChoiceVoters
                            .length;

                        console.log(
                            "Candidate received vote from voter: ",
                            _voter.voterChoices[index]
                        );

                        emit CountVotes_CandidateReceivedVoterFromTo(
                            _voter.walletAddress,
                            _fromCandidate,
                            _voter.voterChoices[index],
                            round.current()
                        );

                        console.log("Voter Address", _voter.walletAddress);
                        console.log("From", _fromCandidate);
                        console.log("to", _voter.voterChoices[index]);

                        //TODO check if it is necessary to save candidate after updating its array if its already accessed by storage
                        addressToCandidate[
                            _voter.voterChoices[index]
                        ] = _candidate;
                    } else {
                        console.log(
                            "All of the voter's candidate are eliminated",
                            _voter.walletAddress
                        );
                        emit CountVotes_ExhaustedVoterChoices(
                            _voter.walletAddress,
                            round.current()
                        );
                    } //should we have an else part to give the point to the next choice if the current choice is already eliminated?
                }
            }
            console.log("--- Done distributing for this voter ---");
        }

        //clear firstChoiceVotersAddresses here
        while (firstChoiceVotersAddresses.length > 0) {
            firstChoiceVotersAddresses.pop();
        }

        console.log(
            "firstChoiceVotersAddresses.length",
            firstChoiceVotersAddresses.length
        );

        console.log("--- Finished Distributing Votes ---");
    }

    ////////////////////////
    /// Getter functions ///
    ////////////////////////
    function getCandidateByAddress(
        address _candidateAddress
    ) external view returns (Candidate memory) {
        if (addressToCandidate[_candidateAddress].id <= 0) {
            revert Voting_CandidateAddressDoesNotExist(_candidateAddress);
        }
        return addressToCandidate[_candidateAddress];
    }

    function getVoterByAddress(
        address _voterAddress
    ) external view returns (Voter memory) {
        if (registeredVoters[_voterAddress].voterId <= 0) {
            revert Voting_VoterDoesNotExist(_voterAddress);
        }
        return registeredVoters[_voterAddress];
    }

    function checkIfCandidateExist(
        address _candidateAddress
    ) public view returns (bool) {
        return (addressToCandidate[_candidateAddress].id > 0) ? true : false;
    }

    function checkIfVoterExist(
        address _voterAddress
    ) public view returns (bool) {
        return (registeredVoters[_voterAddress].voterId > 0) ? true : false;
    }

    function getNumberOfCandidates() public view returns (uint256) {
        return numberOfCandidates.current();
    }

    function getWinner() public view returns (address) {
        //check - only allowed to call if isWinnerPicked is true
        if (isWinnerPicked == false) {
            revert PhaseThree_ThereIsNoWinnerYet();
        }
        return winner;
    }
}

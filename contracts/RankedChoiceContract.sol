// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";

/// Errors ///
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

/**
 * @title A Ranked Choice Voting Smart Contract
 * @author Kent Miguel
 * @dev uses chainlink automation to end register, voting, and count phases
 */
contract RankedChoiceContract {
    using Counters for Counters.Counter;

    //Events
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
        address firstChoice,
        address secondChoice,
        address thirdChoice
    );

    /// Candidate variables ///
    // we might only need 1st choice vote counts... the rest of the vote counts might only be needed if we alocate the points there for visual and metric analysis for the front end...
    struct Candidate {
        uint256 id;
        string name;
        address walletAddress;
        uint256 firstVotesCount;
        uint256 secondVotesCount;
        uint256 thirdVotesCount;
        bool isEliminated;
        bool isWinner;
        uint256 totalVotesCount;
    }

    ///should I create a voter struct???
    /// might not actually need firstVote, secondVote, and thirdVote variables
    struct Voter {
        uint256 voterId;
        // string name;
        address walletAddress;
        uint256 firstVote;
        uint256 secondVote;
        uint256 thirdVote;
        bool hasVoted;
        bool isRegistered;
        bool isCandidate;
    }

    address[] private candidateAddresses; //array of candidates
    //mapping(uint256 => mapping(address => Candidate)) private addressToCandidate;
    mapping(address => Candidate) private addressToCandidate;
    mapping(address => Voter) private registeredVoters;

    /// Voter variables ///

    /// Election global variables ///
    bool phaseOneSwitch;
    bool phaseTwoSwitch;
    bool phaseThreeSwitch;
    bool isWinnerPicked;
    Counters.Counter private candidateIdCounter;
    Counters.Counter private numberOfCandidates;
    Counters.Counter private voterIdCounter;
    Counters.Counter public numberOfVoters;
    Counters.Counter public numberOfVotersVoted;
    uint256 constant FIRST_CHOICE = 3;
    uint256 constant SECOND_CHOICE = 2;
    uint256 constant THIRD_CHOICE = 1;

    //mapping candidate address to struct

    //create a constructor to start timer for phases
    //must initialize the state of voting

    /** Functions */

    /**
     * @notice this function register voters to vote for phase 2: Voting
     * @dev
     * 1. users who enter as a candidate will be registered automatically, will be disabled at the end of phase 1
     * 2. Optimize this by accessing struct once and store it in a local variable and use that for the checks.. see coverage first and gas viewer
     *
     */
    function registerToVote() public {
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

        Voter memory voter = Voter(
            _voterId,
            msg.sender,
            0,
            0,
            0,
            false,
            true,
            false
        );

        registeredVoters[msg.sender] = voter;

        //emit event
        emit VoterRegistered(_voterId, msg.sender);
    }

    /**
     * @notice this functions registers candidates
     * @param _candidateName The name of the candidate
     * @dev will be registered to vote automatically and will be disabled when register phase is over
     */
    function enterCandidate(
        // address _candidateAddress,
        string memory _candidateName // uint256 _firstVotesCount, // uint256 _secondVotesCount, // uint256 _thirdVotesCount
    ) external {
        if (checkIfCandidateExist(msg.sender)) {
            revert Voting_CandidateAlreadyExists(msg.sender);
        }

        //assign candidate id number
        candidateIdCounter.increment();
        numberOfCandidates.increment();
        uint256 _candidateId = candidateIdCounter.current();

        //create candidate struct
        // Candidate memory candidate = addressToCandidate[_candidateAddress];
        Candidate memory candidate = Candidate(
            _candidateId,
            _candidateName,
            // _candidateAddress,
            msg.sender,
            0,
            0,
            0,
            false,
            false,
            0
        );

        //store candidate struct in mapping
        addressToCandidate[msg.sender] = candidate;

        //store user address to registeredVoter mapping
        //emit event

        //push to candidate address - might not be necessary
        candidateAddresses.push(msg.sender);

        //emit CandidateRegistered event
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
     * @notice withdraws from election
     * @dev checks:
     *      1 . disabled when register phase is over
     *      2. check that person who registered are only the one who can withdraw
     *      3. check that cannot withdraw if entry does not exist
     */
    function withdrawCandidate() external {
        if (addressToCandidate[msg.sender].id <= 0) {
            revert Voting_CandidateAddressDoesNotExist(msg.sender);
        }

        Candidate memory _candidate = addressToCandidate[msg.sender];

        delete (addressToCandidate[msg.sender]);
        numberOfCandidates.decrement();
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
     */
    function beginPhaseTwo() private {
        phaseOneSwitch = false;
        phaseTwoSwitch = true;
    }

    /**
     * @notice this function allows voters to vote their choices in the election
     * @dev come back to implement checks:
     * 1. phase switches
     * 2. flags: isRegistered, hasVoted
     * 3. Update points for candidate structs
     */
    function vote(
        address firstChoice,
        address secondChoice,
        address thirdChoice
    ) public {
        //checks
        if (checkIfVoterExist(msg.sender) == false) {
            revert Voting_VoterDoesNotExist(msg.sender);
        }

        Voter memory _voter = registeredVoters[msg.sender];

        if (_voter.isRegistered == false) {
            revert PhaseTwo_VoterIsNotRegistered(msg.sender);
        }

        if (_voter.hasVoted == true) {
            revert PhaseTwo_AlreadyVoted(msg.sender);
        }

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

        //need a check for picking same candidate multiple times... cannot happen

        //updates
        //look for first choice and add score - can definitely improve this...
        //we are accessing storage multiple times...
        Candidate memory _firstChoice = addressToCandidate[firstChoice];
        _firstChoice.firstVotesCount =
            _firstChoice.firstVotesCount +
            FIRST_CHOICE;

        addressToCandidate[firstChoice] = _firstChoice;

        Candidate memory _secondChoice = addressToCandidate[secondChoice];
        _secondChoice.secondVotesCount =
            _secondChoice.secondVotesCount +
            SECOND_CHOICE;

        addressToCandidate[secondChoice] = _secondChoice;

        Candidate memory _thirdChoice = addressToCandidate[thirdChoice];
        _thirdChoice.thirdVotesCount =
            _thirdChoice.thirdVotesCount +
            THIRD_CHOICE;

        addressToCandidate[thirdChoice] = _thirdChoice;

        //change flags
        _voter.hasVoted = true;
        registeredVoters[msg.sender] = _voter;
        numberOfVotersVoted.increment();

        //emit event
        emit Voted(
            _voter.voterId,
            _voter.walletAddress,
            firstChoice,
            secondChoice,
            thirdChoice
        );
    }

    /// Phase 3: Count Votes

    /**
     * @notice this function calculates the votes to get the winner
     * @dev see pointer below:
     * 1. If a candidate has >= 50% of the votes + 1 then he/she is the winner
     * 2. ...if no winner in round 1, go to the next round and distribute the 2nc choice of the 1st choice voters of the eliminated candidate(s)
     * 3. count again
     */
    function countVotes() public returns (address) {
        ///checks
        //if phase2 is over - check flags

        uint256 highestVote = 0;
        uint256 totalPossibleVotes = 6 * numberOfVotersVoted.current();
        uint256 threshold = totalPossibleVotes / 2;
        address winner = address(0);

        // calculate total votes for each candidates
        // need to check for edge cases
        // we can have a helper function for round1
        //this can be a helper function
        for (uint256 i = 0; i < numberOfCandidates.current(); i++) {
            address _candidateAddress = candidateAddresses[i];
            Candidate memory _candidate = addressToCandidate[_candidateAddress];
            //if firstVotes count = 0 , then eliminate -- emit event Eliminated_ReceivedZeroFirstChoice()
            if (_candidate.firstVotesCount > highestVote) {
                highestVote = _candidate.totalVotesCount;
                winner = _candidate.walletAddress;
            }
        }

        if (highestVote >= threshold) {
            //change is winnerPicked flag
            return winner;
        } else {
            //go to the next round - create helper function
            return address(0);
        }
    }

    /// Getter functions ///
    function getCandidateByAddress(address _candidateAddress)
        external
        view
        returns (Candidate memory)
    {
        if (addressToCandidate[_candidateAddress].id <= 0) {
            revert Voting_CandidateAddressDoesNotExist(_candidateAddress);
        }
        return addressToCandidate[_candidateAddress];
    }

    function getVoterByAddress(address _voterAddress)
        external
        view
        returns (Voter memory)
    {
        if (registeredVoters[_voterAddress].voterId <= 0) {
            revert Voting_VoterDoesNotExist(_voterAddress);
        }
        return registeredVoters[_voterAddress];
    }

    function checkIfCandidateExist(address _candidateAddress)
        public
        view
        returns (bool)
    {
        return (addressToCandidate[_candidateAddress].id > 0) ? true : false;
    }

    function checkIfVoterExist(address _voterAddress)
        public
        view
        returns (bool)
    {
        return (registeredVoters[_voterAddress].voterId > 0) ? true : false;
    }

    function getNumberOfCandidates() public view returns (uint256) {
        return numberOfCandidates.current();
    }
}

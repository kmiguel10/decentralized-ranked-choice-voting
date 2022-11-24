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

    event CountVotes_CandidateWins(
        address indexed candidateAddress,
        uint256 firstVoteCounts,
        uint256 round
    );

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

    address[] private candidateAddresses; //array of candidates
    //mapping(uint256 => mapping(address => Candidate)) private addressToCandidate;
    mapping(address => Candidate) private addressToCandidate;
    mapping(address => Voter) private registeredVoters;

    /// Voter variables ///

    /// Election global variables ///
    bool phaseOneSwitch;
    bool phaseTwoSwitch;
    bool phaseThreeSwitch;
    bool isWinnerPicked; //TODO initialize to false in the constructor
    Counters.Counter private candidateIdCounter;
    Counters.Counter private numberOfCandidates;
    Counters.Counter private voterIdCounter;
    Counters.Counter public numberOfVoters;
    Counters.Counter public numberOfVotersVoted;
    uint256 constant FIRST_CHOICE = 3;
    uint256 constant SECOND_CHOICE = 2;
    uint256 constant THIRD_CHOICE = 1;

    /// phase 3 variables
    //uint256 private highestVote = 0;
    address private winner;
    Counters.Counter private round;
    address[] private firstChoiceVotes_test;

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

        address[] memory _firstChoiceVoters;

        //create candidate struct
        // Candidate memory candidate = addressToCandidate[_candidateAddress];
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

        //store user address to registeredVoter mapping
        //emit event

        //push to candidate address
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

        Voter storage _voter = registeredVoters[msg.sender];

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
        //look for first choice and add voter to the array of firstChoice voters - can definitely improve this...
        //we are accessing storage multiple times...
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

        //emit event
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

    /**
     * @notice this function calculates the votes to get the winner
     * @dev see pointer below:
     * 1. If a candidate has >= 50% of the votes + 1 then he/she is the winner
     * 2. ...if no winner in round 1, go to the next round and distribute the 2nc choice of the 1st choice voters of the eliminated candidate(s)
     * 3. count again
     */
    function countVotes() public returns (address winningCandidate) {
        ///TODO checks
        //if phase2 is over - check flags

        //uint256 highestVote = 0;
        uint256 totalPossibleVotes = numberOfVotersVoted.current();
        uint256 threshold = (totalPossibleVotes / 2) + 1;
        //Should this be inside the while loop so it will get reset at each iteration
        //address[] memory firstChoiceVotersOfEliminatedCandidates;

        //TODO wrap in while loop
        while (isWinnerPicked == false) {
            // calculate total votes for each candidates
            // need to check for edge cases
            // we can have a helper function for round1
            //this can be a helper function
            countFirstChoiceVotes(threshold);

            //can move this inside countFirstChoiceVotes()
            if (isWinnerPicked) {
                //TODO - emit event: include round number
                winningCandidate = winner; //needed to name the return value explicitly
                return winningCandidate;
            } else {
                //TODO go to the next round - create helper function
                //distribute eliminated candidates - firstChoiceVoter points
                distributeVotes();
            }
        }
    }

    function distributeVotes() internal {}

    /**
     * @notice this is a helper function for countVotes() to count firstChoice votes for each candidate
     *
     */
    function countFirstChoiceVotes(uint256 _threshold) private {
        //TODO
        //check if there is only 1 remaining candidate - Edge Case
        delete firstChoiceVotes_test;

        //Increment round number
        round.increment();

        uint256 highestVote = 0;
        uint256 lowestVote = 0;

        //array to keep track of lowest vote getters
        //address[] memory lowestVoteGetters;

        for (uint256 i = 0; i < numberOfCandidates.current(); i++) {
            //There variables will reset after each iteration
            address _candidateAddress = candidateAddresses[i];

            Candidate memory _candidate = addressToCandidate[_candidateAddress];

            //Delete 0 firstChoice getters
            if (_candidate.firstVotesCount == 0) {
                // delete candidate from mapping
                delete (addressToCandidate[_candidateAddress]);

                //delete candidate from array
                for (uint256 j = 0; j < candidateAddresses.length; j++) {}
                //emit Event - received 0 votes
                emit CountVotes_DeletedReceivedZeroFirstChoiceVotes(
                    _candidateAddress,
                    _candidate.firstVotesCount,
                    round.current()
                );
            }

            //record highestVoter
            if (_candidate.firstVotesCount > _threshold) {
                highestVote = _candidate.firstVotesCount;
                winner = _candidate.walletAddress;
                isWinnerPicked = true;
                emit CountVotes_CandidateWins(
                    winner,
                    highestVote,
                    round.current()
                );
            }

            //get the lowest vote getters at the end of the round and eliminate
            //and switch the isEliminated flag to true, when distributing votes, make sure to check the flag in order to NOT give the points to an already eliminated candidate
            //how do we keep track of the lowest votes
            if (_candidate.firstVotesCount <= lowestVote) {
                lowestVote = _candidate.firstVotesCount;
            }
        }

        //get lowest vote candidates - at this point we know the lowest vote count, so traverse the list of candidates again
        // save the firstChoiceVoters to array
        for (uint256 i = 0; i < numberOfCandidates.current(); i++) {
            address _candidateAddress = candidateAddresses[i];
            Candidate memory _candidate = addressToCandidate[_candidateAddress];

            for (uint256 j = 0; i < _candidate.firstVotesCount; i++) {
                firstChoiceVotes_test.push(_candidate.firstChoiceVoters[j]);
            }
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

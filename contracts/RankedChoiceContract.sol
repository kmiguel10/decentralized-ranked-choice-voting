// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";

/// Errors ///
error Voting_CandidateAlreadyExists(address candidateAddress);
error Voting_CandidateAddressDoesNotExist(address candidateAddress);
error Voting_VoterIsAlreadyRegistered(address voterAddress);

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

    /// Candidate variables ///
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
    bool isWinnerPicked;
    Counters.Counter private candidateIdCounter;
    Counters.Counter private numberOfCandidates;
    Counters.Counter private voterIdCounter;
    Counters.Counter private numberOfVoters;

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

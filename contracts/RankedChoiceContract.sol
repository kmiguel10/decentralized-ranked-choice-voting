// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";

/// Errors ///
error Voting_CandidateAlreadyExists(address candidateAddress);
error Voting_CandidateAddressDoesNotExist(address candidateAddress);

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

    address[] private candidateAddresses; //array of candidates
    //mapping(uint256 => mapping(address => Candidate)) private addressToCandidate;
    mapping(address => Candidate) private addressToCandidate;

    /// Voter variables ///

    /// Election global variables ///
    bool isWinnerPicked;
    Counters.Counter private candidateIdCounter;
    Counters.Counter private numberOfCandidates;

    //mapping candidate address to struct

    //create a constructor to start timer for phases
    //must initialize the state of voting

    /** Functions */

    /**
     * @notice this functions registers candidates
     * @param _candidateName The name of the candidate
     * @dev will be disabled when register phase is over
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

        //push to candidate address
        candidateAddresses.push(msg.sender);

        //emit CandidateRegistered event
        emit CandidateCreated(
            candidate.id,
            candidate.name,
            candidate.walletAddress
        );
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

    function getNumberOfCandidates() public view returns (uint256) {
        return numberOfCandidates.current();
    }
}

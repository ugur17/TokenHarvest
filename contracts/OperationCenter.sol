// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./InspectorContract.sol";

error OperationCenter__ThisProtocolNotRequestedByThisProducer();
error OperationCenter__YouAreNotMemberOfDao();
error OperationCenter__DeadlineExceeded();
error OperationCenter__YouHaveAlreadyVoted();
error OperationCenter__DeadlineHasNotExceeded();
error OperationCenter__ProposalAlreadyExecuted();
error OperationCenter__ProposalDidntPass();
error OperationCenter__NothingToWithdraw();
error OperationCenter__FailedToWithdrawEthers();

contract OperationCenter is InspectorContract {
    // Struct named Proposal containing all relevant information
    struct Proposal {
        uint256 proposalId;
        address producer;
        uint256 protocolId; // This is the reference id for the farmer protocols which are storing off-chain
        string description;
        uint256 deadline;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        mapping(address => bool) voters;
    }

    // mapping of inspectors to identify which inspector is a dao member
    mapping(address => bool) private daoMemberInspectors;
    // list of proposals from index to Proposal instance
    mapping(uint256 => Proposal) public proposals;
    // counter to identify the id of proposal
    uint256 public proposalCounter;

    event NewProposal(uint256 indexed id, string description);
    event Vote(uint256 indexed id, bool vote, address indexed voter);
    event ProposalExecuted(uint256 indexed id);

    modifier onlyRequestedProtocolByProducer(address producer, uint256 protocolId) {
        if (!requestedProtocolsByProducers[producer][protocolId]) {
            revert OperationCenter__ThisProtocolNotRequestedByThisProducer();
        }
        _;
    }

    modifier onlyMemberInspector(address inspector) {
        if (daoMemberInspectors[inspector] == false) {
            revert OperationCenter__YouAreNotMemberOfDao();
        }
        _;
    }

    modifier onlyActiveProposals(uint256 proposalIndex) {
        if (proposals[proposalIndex].deadline > block.timestamp) {
            revert OperationCenter__DeadlineExceeded();
        }
        _;
    }

    modifier onlyExpiredAndNotExecutedProposals(uint256 proposalIndex) {
        if (proposals[proposalIndex].deadline <= block.timestamp) {
            revert OperationCenter__DeadlineHasNotExceeded();
        }
        if (proposals[proposalIndex].executed) {
            revert OperationCenter__ProposalAlreadyExecuted();
        }
        _;
    }

    modifier onlyFirstVote(uint256 proposalIndex, address voter) {
        if (proposals[proposalIndex].voters[voter]) {
            revert OperationCenter__YouHaveAlreadyVoted();
        }
        _;
    }

    constructor() {
        proposalCounter = 0;
    }

    function createProposal(
        string memory description,
        uint256 protocolId,
        address producer
    )
        external
        onlyMemberInspector(msg.sender)
        onlyRequestedProtocolByProducer(producer, protocolId)
    {
        uint256 deadline = block.timestamp + 5 minutes;
        Proposal storage newPropose = proposals[proposalCounter];
        newPropose.proposalId = proposalCounter;
        newPropose.producer = producer;
        newPropose.protocolId = protocolId;
        newPropose.description = description;
        newPropose.deadline = deadline;
        newPropose.forVotes = 0;
        newPropose.againstVotes = 0;
        newPropose.executed = false;
        proposalCounter++;
        emit NewProposal(proposalCounter, description);
    }

    function vote(
        uint256 proposalIndex,
        bool voteDecision
    )
        external
        onlyMemberInspector(msg.sender)
        onlyActiveProposals(proposalIndex)
        onlyFirstVote(proposalIndex, msg.sender)
    {
        if (voteDecision) {
            proposals[proposalIndex].forVotes++;
        } else {
            proposals[proposalIndex].againstVotes++;
        }
    }

    function executeProposal(
        uint256 proposalIndex
    ) external onlyMemberInspector(msg.sender) onlyExpiredAndNotExecutedProposals(proposalIndex) {
        address producer = proposals[proposalIndex].producer;
        uint256 protocolId = proposals[proposalIndex].protocolId;
        // we are resetting the value of this mapping bcs later the same producer can request for the same protocol
        requestedProtocolsByProducers[producer][protocolId] = false;
        if (proposals[proposalIndex].forVotes > proposals[proposalIndex].againstVotes) {
            proposals[proposalIndex].executed = true;
            // send some credit token to the producer
            // assign an inspector to inspect the farm
            // to assign an inspector, take some commitment to the treasury as guarantor then give them authority to inspect
        } else {
            revert OperationCenter__ProposalDidntPass();
        }
    }

    function withdrawEther() external onlyOwner {
        uint256 amount = address(this).balance;
        if (amount <= 0) {
            revert OperationCenter__NothingToWithdraw();
        }
        (bool sent, ) = payable(owner()).call{value: amount}("");
        if (!sent) {
            revert OperationCenter__FailedToWithdrawEthers();
        }
    }

    receive() external payable {}

    fallback() external payable {}

    function beMemberOfDao() external onlyRole(UserRole.Inspector) {
        daoMemberInspectors[msg.sender] = true;
    }

    function removeFromMembershipOfDao(address inspectorToBeRemoved) external onlyOwner {
        daoMemberInspectors[inspectorToBeRemoved] = false;
    }
}

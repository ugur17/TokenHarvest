// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ProducerContract.sol";

import "./HarvestToken.sol";

error OperationCenter__ThisProtocolNotRequestedByThisProducer();
error OperationCenter__YouAreNotMemberOfDao();
error OperationCenter__DeadlineExceeded();
error OperationCenter__YouHaveAlreadyVoted();
error OperationCenter__DeadlineHasNotExceeded();
error OperationCenter__ProposalAlreadyExecuted();
error OperationCenter__ProposalDidntPass();
error OperationCenter__NothingToWithdraw();
error OperationCenter__FailedToWithdrawEthers();
error OperationCenter__NotSufficientBalance();
error OperationCenter__InvalidProducerAddress();
error OperationCenter__InspectorAlreadyAssigned();
error OperationCenter__ProposalDidntPassedYet();
error OperationCenter__YouAreNotTheInspectorOfThisProposal();

contract OperationCenter is HarvestToken {
    // Struct named Proposal containing all relevant information
    struct Proposal {
        uint256 proposalId;
        address producer;
        address inspector;
        uint256 protocolId; // This is the reference id for the farmer protocols which are storing off-chain
        uint256 avgTokenPriceOfCapacityCommitment;
        string description;
        uint256 deadline;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        // if passed is false, it's not certain that the proposal rejected, but if it's true, the proposal definitely passed
        bool passedVoting;
        bool passedInspection;
        mapping(address => bool) voters;
    }

    ProducerContract public producerContractInstance;

    uint256 constant TOKEN_CREDIT_PERCENTAGE = 25;

    // (inspector address => (proposal index => amount)) of guaranteed amount taken from inspector
    mapping(address => mapping(uint256 => uint256)) public guaranteedAmountsOfInspectors;
    // producer address => amount of credited tokens
    mapping(address => uint256) public creditedTokens;
    // mapping of inspectors to identify which inspector is a dao member
    mapping(address => bool) private daoMemberInspectors;
    // list of proposals from index to Proposal instance
    mapping(uint256 => Proposal) public proposals;
    // counter to identify the id of proposal
    uint256 public proposalCounter;

    event NewProposal(uint256 indexed id, string description);
    event Vote(uint256 indexed id, bool vote, address indexed voter);
    event ProposalExecuted(uint256 indexed id);
    event TokenTransferred(address indexed from, address indexed to, uint256 amount);

    modifier onlyRequestedProtocolByProducer(address producer, uint256 protocolId) {
        if (
            producerContractInstance.getRequestedProtocolsByProducersMapping(
                producer,
                protocolId
            ) == false
        ) {
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

    modifier onlySufficientBalance(uint256 amount) {
        if (getBalance() < amount) {
            revert OperationCenter__NotSufficientBalance();
        }
        _;
    }

    modifier onlyProposalWhichInspectorNotAssigned(uint256 proposalIndex) {
        if (proposals[proposalIndex].inspector != address(0)) {
            revert OperationCenter__InspectorAlreadyAssigned();
        }
        _;
    }

    modifier onlyPassedProposals(uint256 proposalIndex) {
        if (proposals[proposalIndex].passedVoting == false) {
            revert OperationCenter__ProposalDidntPassedYet();
        }
        _;
    }

    modifier onlyAssignedInspector(address inspector, uint256 proposalIndex) {
        if (proposals[proposalIndex].inspector != inspector) {
            revert OperationCenter__YouAreNotTheInspectorOfThisProposal();
        }
        _;
    }

    constructor(address producerContractAddress) {
        proposalCounter = 0;
        producerContractInstance = ProducerContract(producerContractAddress);
    }

    function beMemberOfDao() external onlyRole(UserRole.Inspector) {
        daoMemberInspectors[msg.sender] = true;
    }

    function removeFromMembershipOfDao(address inspectorToBeRemoved) external onlyOwner {
        daoMemberInspectors[inspectorToBeRemoved] = false;
    }

    function createProposal(
        string memory description,
        uint256 protocolId,
        address producer,
        uint256 avgTokenPriceOfCapacityCommitment
    )
        external
        onlyMemberInspector(msg.sender)
        onlyRequestedProtocolByProducer(producer, protocolId)
    {
        if (producer == address(0)) {
            revert OperationCenter__InvalidProducerAddress();
        }
        uint256 deadline = block.timestamp + 5 minutes;
        Proposal storage newPropose = proposals[proposalCounter];
        newPropose.proposalId = proposalCounter;
        newPropose.producer = producer;
        newPropose.protocolId = protocolId;
        newPropose.avgTokenPriceOfCapacityCommitment = avgTokenPriceOfCapacityCommitment;
        newPropose.description = description;
        newPropose.deadline = deadline;
        newPropose.forVotes = 0;
        newPropose.againstVotes = 0;
        newPropose.executed = false;
        newPropose.passedVoting = false;
        newPropose.passedInspection = false;
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
        emit Vote(proposalIndex, voteDecision, msg.sender);
    }

    function executeProposal(
        uint256 proposalIndex
    ) external onlyMemberInspector(msg.sender) onlyExpiredAndNotExecutedProposals(proposalIndex) {
        address producer = proposals[proposalIndex].producer;
        uint256 protocolId = proposals[proposalIndex].protocolId;
        // we are resetting the value of this mapping bcs later the same producer can request for the same protocol
        producerContractInstance.setRequestedProtocolsByProducersMapping(
            producer,
            protocolId,
            false
        );
        if (proposals[proposalIndex].forVotes > proposals[proposalIndex].againstVotes) {
            proposals[proposalIndex].executed = true;
            proposals[proposalIndex].passedVoting = true;
            // send some credit token to the producer
            uint256 approximateCreditAmount = (proposals[proposalIndex]
                .avgTokenPriceOfCapacityCommitment * TOKEN_CREDIT_PERCENTAGE) / 100;
            _creditHarvestToken(approximateCreditAmount, producer);
        } else {
            revert OperationCenter__ProposalDidntPass();
        }
        emit ProposalExecuted(proposalIndex);
    }

    function _creditHarvestToken(
        uint256 amount,
        address producer
    ) private onlySufficientBalance(amount) {
        creditedTokens[producer] = amount;
        transferFrom(address(this), producer, amount);

        emit TokenTransferred(address(this), producer, amount);
    }

    function withdrawHarvestToken(uint256 amount) external onlyOwner onlySufficientBalance(amount) {
        transferFrom(address(this), msg.sender, amount);

        emit TokenTransferred(address(this), msg.sender, amount);
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

    // setter functions
    function _assignInspectorToProposal(
        uint256 proposalIndex,
        address inspector,
        uint256 amount
    )
        external
        onlyRole(UserRole.Inspector)
        onlyProposalWhichInspectorNotAssigned(proposalIndex)
        onlyPassedProposals(proposalIndex)
    {
        proposals[proposalIndex].inspector = inspector;
        guaranteedAmountsOfInspectors[inspector][proposalIndex] = amount;
    }

    function _setPassedInspection(
        address inspector,
        uint256 proposalIndex,
        bool passedOrNot,
        uint256 inspectorFee
    ) external onlyRole(UserRole.Inspector) onlyAssignedInspector(inspector, proposalIndex) {
        proposals[proposalIndex].passedInspection = passedOrNot;
        if (passedOrNot) {
            // send the taken guaranteed token amount from inspector back to the inspector
            // Also adds the comission of inspector
            uint256 amount = (guaranteedAmountsOfInspectors[inspector][proposalIndex] *
                (100 + inspectorFee)) / 100;
            transferFrom(address(this), inspector, amount);
            guaranteedAmountsOfInspectors[inspector][proposalIndex] = 0;
        }
    }

    // getter functions
    function getBalance() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function getAvgTokenPriceOfCapacityCommitment(uint256 index) external view returns (uint256) {
        return proposals[index].avgTokenPriceOfCapacityCommitment;
    }

    function getPassedVotingMemberOfProposal(uint256 proposalIndex) external view returns (bool) {
        return proposals[proposalIndex].passedVoting;
    }

    function getInspectorMemberOfProposal(uint256 proposalIndex) external view returns (address) {
        return proposals[proposalIndex].inspector;
    }
}

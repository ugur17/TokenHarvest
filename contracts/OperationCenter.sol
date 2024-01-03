// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./ProducerContract.sol";
import "./HarvestToken.sol";
import "./Auth.sol";

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
error OperationCenter__YouAreNotTheInspectorOfThisProposal();
error OperationCenter__InsufficientRole();
error OperationCenter__ProposalDoesNotExist();

contract OperationCenter is Ownable {
    // Struct named Proposal containing all relevant information
    struct Proposal {
        uint256 proposalId;
        address producer;
        address inspector;
        uint256 protocolId; // This is the reference id for the farmer protocols which are storing off-chain
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
    HarvestToken public token;
    Auth public auth;

    uint256 public constant TOTAL_PRODUCER_FEE_PERCENTAGE = 20;

    // (inspector address => (proposal index => amount)) of guaranteed amount taken from inspector
    mapping(address => mapping(uint256 => uint256)) public guaranteedAmountsOfInspectors;
    // producer address => amount of credited tokens
    mapping(address => uint256) public creditedTokens;
    // mapping of inspectors to identify which inspector is a dao member
    mapping(address => bool) public daoMemberInspectors;
    // list of proposals from index to Proposal instance
    mapping(uint256 => Proposal) public proposals;
    // counter to identify the id of proposal
    uint256 public proposalCounter;

    event NewMemberAdded(address indexed newMember);
    event NewProposal(uint256 indexed id, address indexed producer);
    event Vote(uint256 indexed id, bool vote, address indexed voter);
    event ProposalExecuted(uint256 indexed id);
    event TokenTransferred(address indexed from, address indexed to, uint256 amount);

    modifier onlyMemberInspector(address inspector) {
        if (daoMemberInspectors[inspector] == false) {
            revert OperationCenter__YouAreNotMemberOfDao();
        }
        _;
    }

    modifier onlySufficientBalance(uint256 amount) {
        if (getBalance() < amount) {
            revert OperationCenter__NotSufficientBalance();
        }
        _;
    }

    modifier onlyRole(address user, Auth.UserRole role) {
        if (auth.getOnlyRole(user, role) == false || auth.isRegistered(user) == false) {
            revert OperationCenter__InsufficientRole();
        }
        _;
    }

    constructor(
        address producerContractAddress,
        address harvestTokenContractAddress,
        address authContractAddres
    ) Ownable(msg.sender) {
        proposalCounter = 0;
        producerContractInstance = ProducerContract(producerContractAddress);
        token = HarvestToken(harvestTokenContractAddress);
        auth = Auth(authContractAddres);
    }

    function addMemberOfDao(
        address inspector
    ) external onlyOwner onlyRole(inspector, Auth.UserRole.Inspector) {
        daoMemberInspectors[inspector] = true;
        emit NewMemberAdded(inspector);
    }

    function removeFromMembershipOfDao(address inspectorToBeRemoved) external onlyOwner {
        daoMemberInspectors[inspectorToBeRemoved] = false;
    }

    function createProposal(
        string memory description,
        uint256 protocolId,
        address producer
    ) external onlyMemberInspector(msg.sender) {
        if (
            producerContractInstance.getRequestedProtocolsByProducersMapping(
                producer,
                protocolId
            ) == false
        ) {
            revert OperationCenter__ThisProtocolNotRequestedByThisProducer();
        }
        if (producer == address(0)) {
            revert OperationCenter__InvalidProducerAddress();
        }
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
        newPropose.passedVoting = false;
        newPropose.passedInspection = false;
        proposalCounter++;
        emit NewProposal(proposalCounter - 1, producer);
    }

    function vote(
        uint256 proposalIndex,
        bool voteDecision
    ) external onlyMemberInspector(msg.sender) {
        if (proposals[proposalIndex].voters[msg.sender]) {
            revert OperationCenter__YouHaveAlreadyVoted();
        }
        if (block.timestamp > proposals[proposalIndex].deadline) {
            revert OperationCenter__DeadlineExceeded();
        }
        if (voteDecision) {
            proposals[proposalIndex].forVotes++;
        } else {
            proposals[proposalIndex].againstVotes++;
        }
        proposals[proposalIndex].voters[msg.sender] = true;
        emit Vote(proposalIndex, voteDecision, msg.sender);
    }

    function executeProposal(
        uint256 proposalIndex,
        uint256 creditAmount
    ) external onlyMemberInspector(msg.sender) {
        Proposal storage proposal = proposals[proposalIndex];
        if (proposal.deadline == 0) {
            revert OperationCenter__ProposalDoesNotExist();
        }
        if (block.timestamp < proposal.deadline) {
            revert OperationCenter__DeadlineHasNotExceeded();
        }
        if (proposal.executed) {
            revert OperationCenter__ProposalAlreadyExecuted();
        }
        address producer = proposal.producer;
        uint256 protocolId = proposal.protocolId;
        // we are resetting the value of this mapping bcs later the same producer can request for the same protocol
        producerContractInstance.setRequestedProtocolsByProducersMapping(
            producer,
            protocolId,
            false
        );
        if (proposal.forVotes > proposal.againstVotes) {
            proposal.executed = true;
            proposal.passedVoting = true;
            // send some credit token to the producer
            _creditHarvestToken(creditAmount, producer);
        } else {
            revert OperationCenter__ProposalDidntPass();
        }
        emit ProposalExecuted(proposalIndex);
    }

    function withdrawHarvestToken(uint256 amount) external onlyOwner onlySufficientBalance(amount) {
        token.transfer(msg.sender, amount);

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

    /* Functions will be called in this contract */
    function _creditHarvestToken(
        uint256 amount,
        address producer
    ) private onlySufficientBalance(amount) {
        creditedTokens[producer] = amount;
        token.transfer(producer, amount);

        emit TokenTransferred(address(this), producer, amount);
    }

    /* Functions will be called from GoodExchange Contract */
    function _handlePurchase(address producer, uint256 totalPrice) external {
        uint256 feeAmount = (TOTAL_PRODUCER_FEE_PERCENTAGE * totalPrice) / 100;
        uint256 producerShare = totalPrice - feeAmount;
        if (producerShare < creditedTokens[producer]) {
            creditedTokens[producer] -= producerShare;
            return;
        } else if (producerShare == creditedTokens[producer]) {
            delete creditedTokens[producer];
            return;
        } else {
            // if producerShare > creditedTokens[producer]
            uint256 paymentAmount = producerShare - creditedTokens[producer];
            token.transfer(producer, paymentAmount);
            delete creditedTokens[producer];
        }
    }

    /* Functions will be called from InspectorContract */
    function _assignInspectorToProposal(
        uint256 proposalIndex,
        address inspector,
        uint256 amount
    ) external onlyRole(msg.sender, Auth.UserRole.Inspector) {
        if (proposals[proposalIndex].passedVoting == false) {
            revert OperationCenter__ProposalDidntPass();
        }
        if (proposals[proposalIndex].inspector != address(0)) {
            revert OperationCenter__InspectorAlreadyAssigned();
        }
        proposals[proposalIndex].inspector = inspector;
        guaranteedAmountsOfInspectors[inspector][proposalIndex] = amount;
    }

    function _setPassedInspection(
        address inspector,
        uint256 proposalIndex,
        bool passedOrNot,
        uint256 inspectorFee
    ) external onlyRole(msg.sender, Auth.UserRole.Inspector) {
        if (proposals[proposalIndex].inspector != inspector) {
            revert OperationCenter__YouAreNotTheInspectorOfThisProposal();
        }
        proposals[proposalIndex].passedInspection = passedOrNot;
        if (passedOrNot) {
            // send the taken guaranteed token amount from inspector back to the inspector
            // Also adds the comission of inspector
            uint256 amount = guaranteedAmountsOfInspectors[inspector][proposalIndex] + inspectorFee;
            delete guaranteedAmountsOfInspectors[inspector][proposalIndex];
            token.transfer(inspector, amount);
            guaranteedAmountsOfInspectors[inspector][proposalIndex] = 0;
        }
    }

    /* Getter Functions */
    function getBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getPassedVotingMemberOfProposal(uint256 proposalIndex) public view returns (bool) {
        return proposals[proposalIndex].passedVoting;
    }

    function getInspectorMemberOfProposal(uint256 proposalIndex) public view returns (address) {
        return proposals[proposalIndex].inspector;
    }
}

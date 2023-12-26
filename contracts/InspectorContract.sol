// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OperationCenter.sol";
import "./NFTHarvest.sol";
import "./ProducerContract.sol";

/* Errors */
error InspectorContract__InspectionRequestNotFound();
error InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId();
error InspectorContract__InspectorDidntRequested();
error InspectorContract__ProposalDidntPassedYet();
error InspectorContract__InspectorAlreadyAssigned();

contract InspectorContract is ProducerContract {
    OperationCenter public dao;
    /* Events */
    event CertificationRequestAccepted(uint256 indexed tokenId, address indexed inspector);
    event CertificationApproved(uint256 indexed tokenId, address indexed inspector);
    event CertificationRejected(uint256 indexed tokenId, address indexed inspector);
    event ProcessInspectionAccepted(uint256 indexed proposalIndex, address indexed inspector);

    /* Modifiers */
    modifier onlySentCertificationRequests(uint256 tokenId) {
        if (certificationRequests[tokenId].producer == address(0)) {
            revert InspectorContract__InspectionRequestNotFound();
        }
        _;
    }

    modifier onlyAcceptedCertificationRequests(uint256 tokenId) {
        if (certificationRequests[tokenId].inspector != msg.sender) {
            revert InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId();
        }
        _;
    }

    modifier onlyPassedProposals(uint256 proposalIndex) {
        if (dao.getPassedMemberOfProposal(proposalIndex) == false) {
            revert InspectorContract__ProposalDidntPassedYet();
        }
        _;
    }

    modifier onlyProposalWhichInspectorNotAssigned(uint256 proposalIndex) {
        if (dao.getInspectorMemberOfProposal(proposalIndex) != address(0)) {
            revert InspectorContract__InspectorAlreadyAssigned();
        }
        _;
    }

    constructor(
        address daoAddress,
        address nftContractAddress
    ) ProducerContract(nftContractAddress) {
        dao = OperationCenter(daoAddress);
    }

    /* Functions */
    function acceptCertificationRequest(
        uint256 tokenId
    ) external onlyRole(UserRole.Inspector) onlySentCertificationRequests(tokenId) {
        certificationRequests[tokenId].inspector = msg.sender;
        emit CertificationRequestAccepted(tokenId, msg.sender);
    }

    function approveCertification(
        uint256 tokenId
    ) external onlyRole(UserRole.Inspector) onlyAcceptedCertificationRequests(tokenId) {
        delete certificationRequests[tokenId];
        nftContract.certifyNft(tokenId);
        emit CertificationApproved(tokenId, msg.sender);
    }

    function rejectCertification(
        uint256 tokenId
    ) external onlyRole(UserRole.Inspector) onlyAcceptedCertificationRequests(tokenId) {
        delete certificationRequests[tokenId];
        emit CertificationRejected(tokenId, msg.sender);
    }

    function assignInspectorToProposal(
        uint256 proposalIndex
    )
        external
        onlyRole(UserRole.Inspector)
        onlyPassedProposals(proposalIndex) // check if proposal is passed
        onlyProposalWhichInspectorNotAssigned(proposalIndex) // check if any inspector already assigned
    {
        uint256 guaranteedAmount = dao.getAvgTokenPriceOfCapacityCommitment(proposalIndex);
        _sendGuaranteedAmount(guaranteedAmount);
        dao.setGuaranteedAmountsOfInspectors(msg.sender, guaranteedAmount);
        dao.setInspectorToProposal(proposalIndex, msg.sender);
        emit ProcessInspectionAccepted(proposalIndex, msg.sender);
    }

    // write a function to approve inspection of process of farm during the execution of protocol

    function _sendGuaranteedAmount(uint256 amount) private {
        transfer(address(dao), amount);
    }
}

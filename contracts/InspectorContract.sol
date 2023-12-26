// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OperationCenter.sol";
import "./ProducerContract.sol";

/* Errors */
error InspectorContract__InspectionRequestNotFound();
error InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId();
error InspectorContract__InspectorDidntRequested();
error InspectorContract__ProposalDidntPassedYet();
error InspectorContract__InspectorAlreadyAssigned();
error InspectorContract__YouAreNotTheInspectorOfThisProposal();

contract InspectorContract is ProducerContract {
    OperationCenter public dao;

    uint256 constant INSPECTOR_FEE = 2;
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

    modifier onlyAcceptedCertificationRequestsByInspector(uint256 tokenId) {
        if (certificationRequests[tokenId].inspector != msg.sender) {
            revert InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId();
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
    ) external onlyRole(UserRole.Inspector) onlyAcceptedCertificationRequestsByInspector(tokenId) {
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

    function assignInspectorToProposal(uint256 proposalIndex) external {
        uint256 guaranteedAmount = dao.getAvgTokenPriceOfCapacityCommitment(proposalIndex);
        dao._assignInspectorToProposal(proposalIndex, msg.sender, guaranteedAmount);
        // send some guaranteed token to the treasury
        _sendGuaranteedAmount(guaranteedAmount);
        emit ProcessInspectionAccepted(proposalIndex, msg.sender);
    }

    function approveProcessInspection(uint256 proposalIndex) external {
        dao._setPassedInspection(msg.sender, proposalIndex, true, INSPECTOR_FEE);
    }

    function _sendGuaranteedAmount(uint256 amount) private {
        transfer(address(dao), amount);
    }
}

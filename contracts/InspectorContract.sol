// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ProducerContract.sol";

/* Errors */
error InspectorContract__InspectionRequestNotFound();
error InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId();
error InspectorContract__InspectorDidntRequested();

contract InspectorContract is ProducerContract {
    // // inspector => producer => assigned or not
    // mapping(address => mapping(address => bool)) public processInspectors;

    /* Events */
    event RequestAccepted(uint256 indexed tokenId, address indexed inspector);
    event CertificationApproved(uint256 indexed tokenId, address indexed inspector);
    event CertificationRejected(uint256 indexed tokenId, address indexed inspector);

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

    /* Functions */
    function acceptCertificationRequest(
        uint256 tokenId
    ) external onlyRole(UserRole.Inspector) onlySentCertificationRequests(tokenId) {
        certificationRequests[tokenId].inspector = msg.sender;
        emit RequestAccepted(tokenId, msg.sender);
    }

    function approveCertification(
        uint256 tokenId
    ) external onlyRole(UserRole.Inspector) onlyAcceptedCertificationRequests(tokenId) {
        delete certificationRequests[tokenId];
        s_nftMetadatas[tokenId].isCertified = true;
        emit CertificationApproved(tokenId, msg.sender);
    }

    function rejectCertification(
        uint256 tokenId
    ) external onlyRole(UserRole.Inspector) onlyAcceptedCertificationRequests(tokenId) {
        delete certificationRequests[tokenId];
        emit CertificationRejected(tokenId, msg.sender);
    }

    function acceptProcessInspection(
        address producer,
        uint256 protocolId
    ) external onlyRole(UserRole.Inspector) {
        if (processInspectorRequested[producer][protocolId] == false) {
            revert InspectorContract__InspectorDidntRequested();
        }
        // take some commitment  to the treasury as guarantor, then give them authority to inspect
        // reset processInspectorRequested mapping in case of producer can request to sign the same protocol id
        processInspectorRequested[producer][protocolId] = false;
        // assign inspector himself/herself as the process inspector
        processInspectors[producer][protocolId] = msg.sender;
    }

    // write a function to approve inspection of process of farm during the execution of protocol
}

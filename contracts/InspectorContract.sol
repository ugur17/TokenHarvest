// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ProducerContract.sol";

/* Errors */
error InspectorContract__InspectionRequestNotFound();
error InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId();

contract InspectorContract is ProducerContract {
    /* Events */
    event RequestAccepted(uint256 indexed tokenId, address indexed inspector);
    event CertificationApproved(uint256 indexed tokenId, address indexed inspector);

    /* Modifiers */
    modifier onlySentRequests(uint256 tokenId) {
        if (certificationRequests[tokenId].producer == address(0)) {
            revert InspectorContract__InspectionRequestNotFound();
        }
        _;
    }

    modifier onlyAcceptedRequests(uint256 tokenId) {
        if (certificationRequests[tokenId].inspector != msg.sender) {
            revert InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId();
        }
        _;
    }

    /* Functions */
    function acceptRequest(
        uint256 tokenId
    ) external onlyRole(UserRole.Inspector) onlySentRequests(tokenId) {
        certificationRequests[tokenId].inspector = msg.sender;
        emit RequestAccepted(tokenId, msg.sender);
    }

    function approveCertification(
        uint256 tokenId
    ) external onlyRole(UserRole.Inspector) onlyAcceptedRequests(tokenId) {
        delete certificationRequests[tokenId];
        s_nftMetadatas[tokenId].isCertified = true;
        emit CertificationApproved(tokenId, msg.sender);
    }
}

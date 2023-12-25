// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTHarvest.sol";

/* Errors */
error ProducerContract__ProductAlreadyCertified();
error ProducerContract__CertificationRequestAlreadySent();

contract ProducerContract is NFTHarvest {
    struct CertificationRequest {
        address producer;
        address inspector;
    }
    // producer => protocol id => inspector requested or not
    mapping(address => mapping(uint256 => bool)) internal processInspectorRequested;
    // producer => protocol id => inspector
    mapping(address => mapping(uint256 => address)) internal processInspectors;
    // token id => CertificationRequest instance
    mapping(uint256 => CertificationRequest) public certificationRequests;
    // (producer address => (protocol id => requested or not)) to store which producer requested which protocol (protocols storing off-chain)
    mapping(address => mapping(uint256 => bool)) public requestedProtocolsByProducers;
    uint256 public deneme = 0;

    event CertificationRequested(uint256 indexed tokenId, address indexed producer);
    event ProtocolRequested(uint256 indexed protocolId, address indexed producer);

    modifier onlyNotCertifiedOrNotRequested(uint256 tokenId) {
        NftMetadata memory nft = getNftMetadata(tokenId);
        if (nft.isCertified == true) {
            revert ProducerContract__ProductAlreadyCertified();
        }
        if (certificationRequests[tokenId].producer != address(0)) {
            revert ProducerContract__CertificationRequestAlreadySent();
        }
        _;
    }

    function requestCertification(
        uint256 tokenId
    )
        external
        onlyRole(UserRole.Producer)
        onlyExists(tokenId)
        onlyNotCertifiedOrNotRequested(tokenId)
    {
        CertificationRequest memory newRequest;
        newRequest.producer = msg.sender;
        certificationRequests[tokenId] = newRequest;
        emit CertificationRequested(tokenId, msg.sender);
    }

    function requestProtocolWithDao(uint256 protocolId) internal onlyRole(UserRole.Producer) {
        requestedProtocolsByProducers[msg.sender][protocolId] = true;
        emit ProtocolRequested(protocolId, msg.sender);
    }

    // This function will be called inside of OperationCenter by DAO
    function requestProcessInspector(address producer, uint256 protocolId) internal {
        processInspectorRequested[producer][protocolId] = true;
    }
}

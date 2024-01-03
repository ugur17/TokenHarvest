// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTHarvest.sol";
import "./HarvestToken.sol";

import "./Auth.sol";

/* Errors */
error ProducerContract__ProductAlreadyCertified();
error ProducerContract__CertificationRequestAlreadySent();
error ProducerContract__TokenDoesNotExist();
error ProducerContract__InsufficientRole();

contract ProducerContract {
    struct CertificationRequest {
        address producer;
        address inspector;
    }

    NFTHarvest nftContract;
    HarvestToken token;
    Auth auth;

    // token id => CertificationRequest instance
    mapping(uint256 => CertificationRequest) public certificationRequests;
    // (producer address => (protocol id => requested or not)) to store which producer requested which protocol (protocols storing off-chain)
    mapping(address => mapping(uint256 => bool)) public requestedProtocolsByProducers;

    event CertificationRequested(uint256 indexed tokenId, address indexed producer);
    event ProtocolRequested(uint256 indexed protocolId, address indexed producer);

    modifier onlyNotCertifiedOrNotRequested(uint256 tokenId) {
        if (nftContract.getIsCertified(tokenId) == true) {
            revert ProducerContract__ProductAlreadyCertified();
        }
        if (certificationRequests[tokenId].producer != address(0)) {
            revert ProducerContract__CertificationRequestAlreadySent();
        }
        _;
    }

    modifier onlyTokenExists(uint256 tokenId) {
        string memory name = nftContract.getNameMemberOfMetadata(tokenId);
        if (bytes(name).length == 0) {
            revert ProducerContract__TokenDoesNotExist();
        }
        _;
    }

    modifier onlyRole(Auth.UserRole role) {
        if (auth.getOnlyRole(msg.sender, role) == false || auth.isRegistered(msg.sender) == false) {
            revert ProducerContract__InsufficientRole();
        }
        _;
    }

    constructor(
        address nftContractAddress,
        address harvestTokenContractAddress,
        address authAddress
    ) {
        nftContract = NFTHarvest(nftContractAddress);
        token = HarvestToken(harvestTokenContractAddress);
        auth = Auth(authAddress);
    }

    function requestCertification(
        uint256 tokenId
    )
        external
        onlyRole(Auth.UserRole.Producer)
        onlyTokenExists(tokenId)
        onlyNotCertifiedOrNotRequested(tokenId)
    {
        CertificationRequest memory newRequest;
        newRequest.producer = msg.sender;
        certificationRequests[tokenId] = newRequest;
        emit CertificationRequested(tokenId, msg.sender);
    }

    function requestProtocolWithDao(uint256 protocolId) external onlyRole(Auth.UserRole.Producer) {
        requestedProtocolsByProducers[msg.sender][protocolId] = true;
        emit ProtocolRequested(protocolId, msg.sender);
    }

    // Setter Functions
    // This function will be called inside of OperationCenter by DAO
    function setRequestedProtocolsByProducersMapping(
        address producer,
        uint256 protocolId,
        bool isRequested
    ) external {
        requestedProtocolsByProducers[producer][protocolId] = isRequested;
    }

    function setCertificationRequestProducer(uint256 tokenId, address producer) external {
        certificationRequests[tokenId].producer = producer;
    }

    function setCertificationRequestInspector(uint256 tokenId, address inspector) external {
        certificationRequests[tokenId].inspector = inspector;
    }

    function deleteCertificationRequest(uint256 tokenId) external {
        delete certificationRequests[tokenId];
    }

    // Getter Functions
    // This function will be called inside of OperationCenter by DAO
    function getRequestedProtocolsByProducersMapping(
        address producer,
        uint256 protocolId
    ) external view returns (bool) {
        return requestedProtocolsByProducers[producer][protocolId];
    }

    function getInspectorOfCertificationRequest(uint256 tokenId) public view returns (address) {
        return certificationRequests[tokenId].inspector;
    }

    function getCertificationRequestProducer(uint256 tokenId) external view returns (address) {
        return certificationRequests[tokenId].producer;
    }

    function getCertificationRequestInspector(uint256 tokenId) external view returns (address) {
        return certificationRequests[tokenId].inspector;
    }
}

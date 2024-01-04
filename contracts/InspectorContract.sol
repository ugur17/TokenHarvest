// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OperationCenter.sol";
import "./ProducerContract.sol";
import "./Auth.sol";
import "./NFTHarvest.sol";
import "./HarvestToken.sol";

/* Errors */
error InspectorContract__InspectionRequestNotFound();
error InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId();
error InspectorContract__InsufficientRole();

contract InspectorContract {
    OperationCenter public dao;
    Auth public auth;
    ProducerContract public producerContract;
    NFTHarvest public nftContract;
    HarvestToken public token;

    uint256 public constant INSPECTOR_FEE = 2;
    /* Events */
    event CertificationRequestAccepted(uint256 indexed tokenId, address indexed inspector);
    event CertificationApproved(uint256 indexed tokenId, address indexed inspector);
    event CertificationRejected(uint256 indexed tokenId, address indexed inspector);
    event ProcessInspectionAccepted(uint256 indexed proposalIndex, address indexed inspector);

    /* Modifiers */
    modifier onlySentCertificationRequests(uint256 tokenId) {
        if (producerContract.getCertificationRequestProducer(tokenId) == address(0)) {
            revert InspectorContract__InspectionRequestNotFound();
        }
        _;
    }

    modifier onlyAcceptedCertificationRequests(uint256 tokenId) {
        if (producerContract.getCertificationRequestInspector(tokenId) != msg.sender) {
            revert InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId();
        }
        _;
    }

    modifier onlyRole(address user, Auth.UserRole role) {
        if (auth.getOnlyRole(user, role) == false || auth.isRegistered(user) == false) {
            revert InspectorContract__InsufficientRole();
        }
        _;
    }

    constructor(
        address daoAddress,
        address nftContractAddress,
        address harvestTokenContractAddress,
        address authAddress,
        address producerContractAddress
    ) {
        dao = OperationCenter(daoAddress);
        nftContract = NFTHarvest(nftContractAddress);
        token = HarvestToken(harvestTokenContractAddress);
        auth = Auth(authAddress);
        producerContract = ProducerContract(producerContractAddress);
    }

    /* Functions */
    function acceptCertificationRequest(
        uint256 tokenId
    )
        external
        onlyRole(msg.sender, Auth.UserRole.Inspector)
        onlySentCertificationRequests(tokenId)
    {
        producerContract.setCertificationRequestInspector(tokenId, msg.sender);
        emit CertificationRequestAccepted(tokenId, msg.sender);
    }

    function approveCertification(
        uint256 tokenId
    )
        external
        onlyRole(msg.sender, Auth.UserRole.Inspector)
        onlyAcceptedCertificationRequests(tokenId)
    {
        producerContract.deleteCertificationRequest(tokenId);
        nftContract.certifyNft(tokenId);
        emit CertificationApproved(tokenId, msg.sender);
    }

    function rejectCertification(
        uint256 tokenId
    )
        external
        onlyRole(msg.sender, Auth.UserRole.Inspector)
        onlyAcceptedCertificationRequests(tokenId)
    {
        producerContract.deleteCertificationRequest(tokenId);
        emit CertificationRejected(tokenId, msg.sender);
    }

    function assignInspectorToProposal(
        uint256 proposalIndex,
        uint256 guaranteedAmount
    ) external onlyRole(msg.sender, Auth.UserRole.Inspector) {
        // uint256 guaranteedAmount = dao._getAvgTokenPriceOfCapacityCommitment(proposalIndex);
        dao._assignInspectorToProposal(proposalIndex, msg.sender, guaranteedAmount);
        // send some guaranteed token to the treasury
        _sendGuaranteedAmount(msg.sender, guaranteedAmount);
        emit ProcessInspectionAccepted(proposalIndex, msg.sender);
    }

    function approveProcessInspection(uint256 proposalIndex) external {
        dao._setPassedInspection(msg.sender, proposalIndex, true, INSPECTOR_FEE);
    }

    function _sendGuaranteedAmount(address inspector, uint256 amount) public {
        token.transferFrom(inspector, address(dao), amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenHarvest.sol";

/* Errors */
error ProducerContract__ProductAlreadyCertified();
error ProducerContract__CertificationRequestAlreadySent();

contract ProducerContract is TokenHarvest {
    struct CertificationRequest {
        address producer;
        address inspector;
    }
    mapping(uint256 => CertificationRequest) certificationRequests; // token id => CertificationRequest instance

    event CertificationRequested(uint256 indexed tokenId, address indexed producer);

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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ProducerContract.sol";

contract InspectorContract is ProducerContract {
    struct CertificationRequest {
        uint256 productId;
        address producer;
        bool isApproved;
    }

    // ProducerContract public producerContract;
    // address public inspectorAddress;

    // struct CertificationRequest {
    //     uint256 productId;
    //     address producer;
    //     bool isApproved;
    // }

    // CertificationRequest[] public certificationRequests;

    // mapping(uint256 => bool) public certifiedProducts;

    // constructor(ProducerContract _producerContract) {
    //     inspectorAddress = msg.sender;
    //     producerContract = _producerContract;
    // }

    // function getCertificationRequestsCount() external view returns (uint256) {
    //     return certificationRequests.length;
    // }

    // function requestCertification(uint256 _productId) external {
    //     require(
    //         msg.sender == producerContract.producerAddress(),
    //         "Only producer can request certification"
    //     );
    //     require(_productId < producerContract.productCounter(), "Invalid product ID");

    //     certificationRequests.push(CertificationRequest(_productId, msg.sender, false));
    // }

    // function approveCertification(uint256 _requestId) external {
    //     require(msg.sender == inspectorAddress, "Only inspector can approve certification");
    //     require(_requestId < certificationRequests.length, "Invalid request ID");

    //     CertificationRequest storage request = certificationRequests[_requestId];
    //     request.isApproved = true;
    //     certifiedProducts[request.productId] = true;
    //     producerContract.products(request.productId).isCertified = true;
    // }
}

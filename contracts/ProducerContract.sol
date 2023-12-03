// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Auth.sol";

error ProducerContract__ProducerNotFound();
error ProducerContract__ProductAlreadyExist();
error ProducerContract__ProductDoesNotExist();
error ProducerContract__ProductNotCertified();
error ProducerContract__ProductAlreadyListed();
error ProducerContract__InvalidListingQuantity();
error ProducerContract__InvalidPrice();

contract ProducerContract is Auth {
    struct Product {
        address owner;
        string name;
        uint256 id;
        uint256 noOfTokensTotal;
        uint256 productAmountOfEachToken;
        bool isCertified;
        uint256 noOfTokensForSale;
        uint256 unitPrice;
    }

    // struct Producer {
    //     string name,
    //     mapping(uint256 => Product) public products
    // }

    // mapping(uint256 => Product) public products;
    mapping(address => mapping(uint256 => Product)) public producersAndProducts;

    // modifier onlyOwnerOfProduct(uint256 id) {
    //     require(producersAndProducts[msg.sender][id].owner)
    // }

    // NOTE: When i come back, i will add modifier to check if the msg.sender has the product which has the id param
    // To do that, most probably i will need a new type of storage to store products

    function createProduct(
        string memory name,
        uint256 id,
        uint256 noOfTokensTotal,
        uint256 productAmountOfEachToken
    ) external onlyRole(UserRole.Producer) returns (Product memory) {
        if (bytes(users[msg.sender].username).length == 0) {
            revert ProducerContract__ProducerNotFound();
        }
        if (bytes(producersAndProducts[msg.sender][id].name).length > 0) {
            revert ProducerContract__ProductAlreadyExist();
        }
        Product memory newProduct = Product(
            msg.sender,
            name,
            id,
            noOfTokensTotal,
            productAmountOfEachToken,
            false,
            0,
            0
        );
        producersAndProducts[msg.sender][id] = newProduct;
        return newProduct;
    }

    function removeProduct(uint256 id) external onlyRole(UserRole.Producer) {
        if (bytes(users[msg.sender].username).length == 0) {
            revert ProducerContract__ProducerNotFound();
        }
        delete producersAndProducts[msg.sender][id];
    }

    function listProductForSale(
        uint256 id,
        uint256 noOfTokensForSale,
        uint256 unitPrice
    ) external onlyRole(UserRole.Producer) returns (Product memory) {
        if (bytes(users[msg.sender].username).length == 0) {
            revert ProducerContract__ProducerNotFound();
        }
        Product storage currentProduct = producersAndProducts[msg.sender][id];
        if (bytes(currentProduct.name).length == 0) {
            revert ProducerContract__ProductDoesNotExist();
        }
        if (currentProduct.isCertified == false) {
            revert ProducerContract__ProductNotCertified();
        }
        if (currentProduct.noOfTokensForSale > 0) {
            revert ProducerContract__ProductAlreadyListed();
        }
        if (noOfTokensForSale <= 0) {
            revert ProducerContract__InvalidListingQuantity();
        }
        if (unitPrice <= 0) {
            revert ProducerContract__InvalidPrice();
        }
        currentProduct.noOfTokensForSale = noOfTokensForSale;
        currentProduct.unitPrice = unitPrice;
        return currentProduct;
    }

    // function cancelListing(uint256 id) external {

    // }

    // function updateProductForSale(uint256 id, uint256 noOfTokensForSale, uint256 unitPrice) external returns(Product) {

    // }

    // function requestCertification(uint256 _productId) external {
    //     require(msg.sender == producerAddress, "Only producer can request certification");
    //     require(_productId < productCounter, "Invalid product ID");

    //     inspectorContract.requestCertificationByProducer(_productId);
    // }

    // function mintNFT(string memory _farmerName, uint256 _quantity) external {
    //     require(msg.sender == producerAddress, "Only producer can mint tokens");

    //     // "TokenHarvest" sözleşmesinden mintNFT fonksiyonunu çağır
    //     tokenHarvest.mintNFT(_farmerName, _quantity);
    // }
}

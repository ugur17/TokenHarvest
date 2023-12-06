// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*
    This is the old implementation approach.
    Everything works fine in this contract, but instead of using
    struct type to define products, i choosed to use ERC1155
    nft standard. I will keep it here, until complete the whole project,
    just in case if i need these functionalities.
*/

import "./Auth.sol";

error ProducerContract__ProductAlreadyExist();
error ProducerContract__ProductDoesNotExist();
error ProducerContract__ProductNotCertified();
error ProducerContract__ProductAlreadyListed();
error ProducerContract__InvalidListingQuantity();
error ProducerContract__InvalidPrice();
error ProducerContract__TotalShouldBeBiggerThanForSaleQuantity();
error ProducerContract__ProductNotListed();

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

    // producer address => product id => Product instance
    mapping(address => mapping(uint256 => Product)) public producersAndProducts;
    // Product[] public listedProducts;

    modifier onlyCreatedProduct(uint256 id) {
        if (producersAndProducts[msg.sender][id].owner == address(0)) {
            revert ProducerContract__ProductDoesNotExist();
        }
        _;
    }

    function createProduct(
        string memory name,
        uint256 id,
        uint256 noOfTokensTotal,
        uint256 productAmountOfEachToken
    ) external onlyRole(UserRole.Producer) returns (Product memory) {
        if (producersAndProducts[msg.sender][id].owner != address(0)) {
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

    function updateProduct(
        string memory name,
        uint256 id,
        uint256 noOfTokensTotal,
        uint256 productAmountOfEachToken
    ) external onlyRole(UserRole.Producer) onlyCreatedProduct(id) returns (Product memory) {
        Product storage currentProduct = producersAndProducts[msg.sender][id];
        if (noOfTokensTotal < currentProduct.noOfTokensForSale) {
            revert ProducerContract__TotalShouldBeBiggerThanForSaleQuantity();
        }
        currentProduct.name = name;
        currentProduct.noOfTokensTotal = noOfTokensTotal;
        currentProduct.productAmountOfEachToken = productAmountOfEachToken;
        return currentProduct;
    }

    function removeProduct(uint256 id) external onlyRole(UserRole.Producer) onlyCreatedProduct(id) {
        delete producersAndProducts[msg.sender][id];
    }

    function listProductForSale(
        uint256 id,
        uint256 noOfTokensForSale,
        uint256 unitPrice
    ) external onlyRole(UserRole.Producer) onlyCreatedProduct(id) {
        Product storage currentProduct = producersAndProducts[msg.sender][id];
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
    }

    function cancelListing(uint256 id) external onlyRole(UserRole.Producer) onlyCreatedProduct(id) {
        Product storage currentProduct = producersAndProducts[msg.sender][id];
        if (currentProduct.noOfTokensForSale <= 0) {
            revert ProducerContract__ProductNotListed();
        }
        currentProduct.noOfTokensForSale = 0;
        currentProduct.unitPrice = 0;
    }

    function updateListing(
        uint256 id,
        uint256 noOfTokensForSale,
        uint256 unitPrice
    ) external onlyRole(UserRole.Producer) onlyCreatedProduct(id) {
        Product storage currentProduct = producersAndProducts[msg.sender][id];
        if (currentProduct.noOfTokensForSale <= 0) {
            revert ProducerContract__ProductNotListed();
        }
        if (noOfTokensForSale <= 0) {
            revert ProducerContract__InvalidListingQuantity();
        }
        if (unitPrice <= 0) {
            revert ProducerContract__InvalidPrice();
        }
        currentProduct.noOfTokensForSale = noOfTokensForSale;
        currentProduct.unitPrice = unitPrice;
    }

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

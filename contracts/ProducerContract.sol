// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenHarvest.sol";

contract ProducerContract {
    TokenHarvest public tokenHarvest;
    address public producerAddress;
    uint256 public productCounter;

    struct Product {
        string name;
        string category;
        uint256 quantity;
        bool isCertified;
        bool isListed;
    }

    // productId => Product
    mapping(uint256 => Product) public products;

    constructor(TokenHarvest _tokenHarvest) {
        producerAddress = msg.sender;
        tokenHarvest = _tokenHarvest;
    }

    function createProduct(
        string memory _name,
        string memory _category,
        uint256 _quantity
    ) external {
        require(msg.sender == producerAddress, "Only producer can create products");

        products[productCounter] = Product(_name, _category, _quantity, false, false);
        productCounter++;
    }

    function requestCertification(uint256 _productId) external {
        require(msg.sender == producerAddress, "Only producer can request certification");
        require(_productId < productCounter, "Invalid product ID");

        products[_productId].isCertified = true;
    }

    function listProductForSale(uint256 _productId) external {
        require(msg.sender == producerAddress, "Only producer can list product for sale");
        require(products[_productId].isCertified, "Product must be certified to list for sale");

        products[_productId].isListed = true;
    }

    function mintNFT(string memory _farmerName, uint256 _quantity) external {
        require(msg.sender == producerAddress, "Only producer can mint tokens");

        // "TokenHarvest" sözleşmesinden mintNFT fonksiyonunu çağır
        tokenHarvest.mintNFT(_farmerName, _quantity);
    }
}

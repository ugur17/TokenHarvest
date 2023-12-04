// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenHarvest is ERC1155, Ownable {
    struct TokenMetadata {
        string name;
        string symbol;
        string description;
        string imageURL;
        uint256 price;
    }

    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => address) private _creators;
    mapping(uint256 => uint256) private _totalSupply;

    string private _baseURI;

    constructor(string memory baseURI) ERC1155(baseURI) {
        _baseURI = baseURI;
    }

    function setURI(uint256 tokenId, string memory tokenURI) external onlyOwner {
        _tokenURIs[tokenId] = tokenURI;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(_baseURI, tokenId.toString()));
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        string memory tokenURI
    ) external onlyOwner {
        require(!_exists(id), "Token ID already exists");
        _mint(account, id, amount, "");
        _creators[id] = msg.sender;
        _tokenURIs[id] = tokenURI;
        _totalSupply[id] = amount;
        _tokenMetadata[id] = metadata;
    }

    function burn(address account, uint256 id, uint256 amount) external {
        require(account == msg.sender || isApprovedForAll(account, msg.sender), "Not authorized");
        _burn(account, id, amount);
    }

    function updateTokenMetadata(uint256 tokenId, TokenMetadata memory newMetadata) external {
        require(_creators[tokenId] == msg.sender, "Not the creator");
        _tokenMetadata[tokenId] = newMetadata;
    }

    function getTokenMetadata(uint256 tokenId) external view returns (TokenMetadata memory) {
        return _tokenMetadata[tokenId];
    }

    function updateTokenURI(uint256 tokenId, string memory newTokenURI) external {
        require(_creators[tokenId] == msg.sender, "Not the creator");
        _tokenURIs[tokenId] = newTokenURI;
    }

    function totalSupply(uint256 tokenId) external view returns (uint256) {
        return _totalSupply[tokenId];
    }

    function sell(uint256 tokenId, uint256 amount, uint256 price) external {
        require(balanceOf(msg.sender, tokenId) >= amount, "Insufficient balance");
        _approveForAll(msg.sender, address(this), true);
        _tokenMetadata[tokenId].price = price;
    }

    function buy(address account, uint256 tokenId, uint256 amount) external payable {
        require(_tokenMetadata[tokenId].price > 0, "Token not for sale");
        require(msg.value == _tokenMetadata[tokenId].price * amount, "Incorrect payment amount");

        _transferFrom(account, msg.sender, tokenId, amount);
        payable(account).transfer(msg.value);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }
}

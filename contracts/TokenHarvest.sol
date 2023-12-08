// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";

import "./Auth.sol";

error TokenHarvest__NotOwner();
error TokenHarvest__NotEnoguhSupply();
error TokenHarvest__ExceedsTheSupplyLimit();
error TokenHarvest__NotEnoughToken();

contract TokenHarvest is ERC1155, Ownable, Auth {
    /* Type Declarations */
    struct NftMetadata {
        string name;
        uint256 productAmountOfEachToken;
        bool isCertified;
    }

    /* Non-Fungible Token State Variables */
    uint256 private s_nftCounter;
    string private constant BASE_URI = "data:application/json;base64,";
    // mapping(uint256 => string) private s_nftURIs; // id => uri
    mapping(uint256 => NftMetadata) private s_nftMetadatas; // id => NftMetadata

    // mapping(uint256 => uint256) private s_nftTotalSupply; // id => total supply

    /* Fungible Token State Variables */
    string private constant NAME_OF_FUNGIBLE_TOKEN = "HarvestToken";
    string private constant SYMBOL_OF_FUNGIBLE_TOKEN = "Hrv";
    uint256 private constant ID_OF_FUNGIBLE_TOKEN = 0; // id of HRV token
    uint256 private s_hrvCurrentSupply;
    uint256 private constant MAX_SUPPLY_OF_FUNGIBLE_TOKEN = 10000000; // 10m

    event CreatedNFT(
        uint256 indexed tokenId,
        uint256 amount,
        string indexed name,
        uint256 productAmountOfEachToken
    );

    modifier onlyOwnerHasEnoughToken(
        address owner,
        uint256 tokenId,
        uint256 amount
    ) {
        if (balanceOf(owner, tokenId) < amount) {
            revert TokenHarvest__NotEnoughToken();
        }
        _;
    }

    constructor(address initialOwner) ERC1155(BASE_URI) Ownable(initialOwner) {
        s_nftCounter = 1; // NFT id counter starts from 1, because id of fungible token is 0
        s_hrvCurrentSupply = 0;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        // check if token exists
        // check if tokenId is zero
        return
            string(
                abi.encodePacked(
                    BASE_URI,
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"Product Name":"',
                                s_nftMetadatas[tokenId].name,
                                '", "Product Amount of Each Token":"',
                                toString(s_nftMetadatas[tokenId].productAmountOfEachToken),
                                '", "Does Product Certified by Any Inspector?":"',
                                convertBoolToString(s_nftMetadatas[tokenId].isCertified),
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function mintNFT(
        uint256 amount,
        string memory name,
        uint256 productAmountOfEachToken
    ) external onlyRole(UserRole.Producer) {
        uint256 tokenId = s_nftCounter;
        s_nftCounter++;
        _mint(msg.sender, tokenId, amount, "");
        NftMetadata memory newToken = NftMetadata(name, productAmountOfEachToken, false);
        s_nftMetadatas[tokenId] = newToken;
        // s_nftURIs[tokenId] = uri(tokenId);
        // s_nftTotalSupply[tokenId] = s_nftTotalSupply[tokenId] + amount;
        emit CreatedNFT(tokenId, amount, name, productAmountOfEachToken);
    }

    function mintHRV(uint256 amount) public onlyOwner {
        if (s_hrvCurrentSupply + amount > MAX_SUPPLY_OF_FUNGIBLE_TOKEN) {
            revert TokenHarvest__ExceedsTheSupplyLimit();
        }
        s_hrvCurrentSupply += amount;
        _mint(msg.sender, ID_OF_FUNGIBLE_TOKEN, amount, "");
    }

    function burnNft(
        uint256 tokenId,
        uint256 amount
    ) external onlyRole(UserRole.Producer) onlyOwnerHasEnoughToken(msg.sender, tokenId, amount) {
        // if (amount > s_nftTotalSupply[tokenId]) {
        //     revert TokenHarvest__NotEnoguhSupply();
        // }
        _burn(msg.sender, tokenId, amount);
        // s_nftTotalSupply[tokenId] = s_nftTotalSupply[tokenId] - amount;
    }

    function getIdOfFungibleToken() public view returns (uint256) {
        return ID_OF_FUNGIBLE_TOKEN;
    }

    // function updateNftMetadata(
    //     uint256 tokenId,
    //     string memory name,
    //     uint256 productAmountOfEachToken,
    //     bool isCertified
    // ) external onlyRole(UserRole.Producer) onlyOwnerHasEnoughNft(tokenId, amount) {
    //     NftMetadata memory newMetadata = NftMetadata(name, productAmountOfEachToken, isCertified);
    //     s_nftMetadatas[tokenId] = newMetadata;
    //     string memory newTokenUri = uri(tokenId);
    //     s_nftURIs[tokenId] = newTokenUri;
    // }

    // function exchangeNftWithHrv(
    //     address sender,
    //     address receiver,
    //     uint256 tokenId,
    //     uint256 nftAmount,
    //     uint256 hrvAmount
    // )
    //     external
    //     onlyOwnerHasEnoughToken(sender, tokenId, nftAmount) // sender should have enough nft
    //     onlyOwnerHasEnoughToken(receiver, ID_OF_FUNGIBLE_TOKEN, hrvAmount) // receiver should have enough hrv token to buy
    // {
    //     safeTransferFrom(receiver, sender, ID_OF_FUNGIBLE_TOKEN, hrvAmount, ""); // send hrv token to the nft owner
    //     safeTransferFrom(sender, receiver, tokenId, nftAmount, ""); // send nft to the account who send money as hrv token
    // }

    function getHrvTokenBalance(address account) public view returns (uint256) {
        return balanceOf(account, ID_OF_FUNGIBLE_TOKEN); // id of Hrv token is zero
    }

    function getNftMetadata(uint256 tokenId) external view returns (NftMetadata memory) {
        return s_nftMetadatas[tokenId];
    }

    // function totalSupply(uint256 tokenId) external view returns (uint256) {
    //     return s_nftTotalSupply[tokenId];
    // }

    // function withdraw() external onlyRole(UserRole.Producer) {
    //     payable(owner()).transfer(address(this).balance);
    // }

    // function exists(uint256 tokenId) external view returns (bool) {
    //     return _exists(tokenId);
    // }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    function convertBoolToString(bool input) internal pure returns (string memory) {
        if (input) {
            return "true";
        } else {
            return "false";
        }
    }
}

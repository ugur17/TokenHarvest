// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// I will care with the admin account after i've completed other tasks
import "./ToString.sol";
import "base64-sol/base64.sol";

import "./HarvestToken.sol";

error TokenHarvest__NotOwner();
error TokenHarvest__NotEnoguhSupply();
error TokenHarvest__ExceedsTheSupplyLimit();
error TokenHarvest__NotEnoughToken();
error TokenHarvest__TokenDoesNotExist();
error TokenHarvest__InvalidParameters();
error TokenHarvest__ThisTokenIsNotNft();
error NFTHarvest__YouDidntAcceptAnyRequestWithThisTokenId();

contract NFTHarvest is ERC1155, HarvestToken {
    /* Type Declarations */
    struct NftMetadata {
        string name;
        uint256 productAmountOfEachToken;
        bool isCertified;
    }

    /* Non-Fungible Token State Variables */
    uint256 private s_nftCounter;
    string private constant BASE_URI = "data:application/json;base64,";
    mapping(uint256 => NftMetadata) internal s_nftMetadatas; // id => NftMetadata

    /* Events */
    event CreatedNFT(
        address account,
        uint256 indexed tokenId,
        uint256 amount,
        string indexed name,
        uint256 productAmountOfEachToken
    );

    event BurnedNFT(address indexed account, uint256 indexed tokenId, uint256 amount);

    event MintedHrv(address indexed owner, uint256 amount);

    /* Modifiers */
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

    modifier onlyExists(uint256 tokenId) {
        if (bytes(s_nftMetadatas[tokenId].name).length == 0) {
            revert TokenHarvest__TokenDoesNotExist();
        }
        _;
    }

    modifier onlyNft(uint256 tokenId) {
        if (tokenId == 0) {
            revert TokenHarvest__ThisTokenIsNotNft();
        }
        _;
    }

    modifier onlyValidParameters(
        string memory name,
        uint256 amount,
        uint256 productAmountOfEachToken
    ) {
        if (bytes(name).length == 0 || amount <= 0 || productAmountOfEachToken <= 0) {
            revert TokenHarvest__InvalidParameters();
        }
        _;
    }

    constructor() ERC1155(BASE_URI) {
        s_nftCounter = 1; // NFT id counter starts from 1, because id of fungible token is 0
    }

    /* Functions */
    function uri(
        uint256 tokenId
    ) public view override onlyExists(tokenId) onlyNft(tokenId) returns (string memory) {
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
                                ToString.toString(s_nftMetadatas[tokenId].productAmountOfEachToken),
                                '", "Does Product Certified by Any Inspector?":"',
                                ToString.convertBoolToString(s_nftMetadatas[tokenId].isCertified),
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
    )
        external
        onlyRole(UserRole.Producer)
        onlyValidParameters(name, amount, productAmountOfEachToken)
    {
        uint256 tokenId = s_nftCounter;
        s_nftCounter++;
        _mint(msg.sender, tokenId, amount, "");
        NftMetadata memory newToken = NftMetadata(name, productAmountOfEachToken, false);
        s_nftMetadatas[tokenId] = newToken;
        emit CreatedNFT(msg.sender, tokenId, amount, name, productAmountOfEachToken);
    }

    function burnNFT(
        uint256 tokenId,
        uint256 amount
    )
        external
        onlyNft(tokenId)
        onlyRole(UserRole.Producer)
        onlyOwnerHasEnoughToken(msg.sender, tokenId, amount)
    {
        _burn(msg.sender, tokenId, amount);
        emit BurnedNFT(msg.sender, tokenId, amount);
    }

    // this function will be called from inspector contract
    function certifyNft(uint256 tokenId) external {
        s_nftMetadatas[tokenId].isCertified = true;
    }

    /* Getter Functions */

    function getNftMetadata(uint256 tokenId) public view returns (NftMetadata memory) {
        return s_nftMetadatas[tokenId];
    }

    function getBaseUri() public pure returns (string memory) {
        return BASE_URI;
    }

    function getNftCounter() public view returns (uint256) {
        return s_nftCounter;
    }

    function getNameMemberOfMetadata(uint256 tokenId) public view returns (string memory) {
        return s_nftMetadatas[tokenId].name;
    }

    function getIsCertified(uint256 tokenId) public view returns (bool) {
        return s_nftMetadatas[tokenId].isCertified;
    }

    function getBalanceOf(address owner, uint256 tokenId) public view returns (uint256) {
        return balanceOf(owner, tokenId);
    }
}

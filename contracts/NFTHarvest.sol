// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// I will care with the admin account after i've completed other tasks
import "./ToString.sol";
import "base64-sol/base64.sol";

import "./Auth.sol";

error TokenHarvest__NotOwner();
error TokenHarvest__NotEnoguhSupply();
error TokenHarvest__ExceedsTheSupplyLimit();
error TokenHarvest__NotEnoughToken();
error TokenHarvest__TokenDoesNotExist();
error TokenHarvest__InvalidParameters();
error TokenHarvest__ThisTokenIsNotNft();

contract NFTHarvest is ERC1155, Auth {
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

    /* Fungible Token State Variables */
    string private constant NAME_OF_FUNGIBLE_TOKEN = "HarvestToken";
    string private constant SYMBOL_OF_FUNGIBLE_TOKEN = "Hrv";
    uint256 private constant ID_OF_FUNGIBLE_TOKEN = 0; // id of HRV token
    uint256 private s_hrvCurrentSupply;
    uint256 private constant MAX_SUPPLY_OF_FUNGIBLE_TOKEN = 10000000; // 10m

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
        s_hrvCurrentSupply = 0;
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

    function mintHRV(uint256 amount) public /* onlyOwner */ {
        if (s_hrvCurrentSupply + amount > MAX_SUPPLY_OF_FUNGIBLE_TOKEN) {
            revert TokenHarvest__ExceedsTheSupplyLimit();
        }
        s_hrvCurrentSupply += amount;
        _mint(msg.sender, ID_OF_FUNGIBLE_TOKEN, amount, "");
        emit MintedHrv(msg.sender, amount);
    }

    // function burnHRV(uint256 amount) public /* onlyOwner */ {

    // }

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

    /* Getter Functions */
    function getIdOfFungibleToken() public pure returns (uint256) {
        return ID_OF_FUNGIBLE_TOKEN;
    }

    function getHrvTokenBalance(address account) public view returns (uint256) {
        return balanceOf(account, ID_OF_FUNGIBLE_TOKEN); // id of Hrv token is zero
    }

    function getNftMetadata(uint256 tokenId) public view returns (NftMetadata memory) {
        return s_nftMetadatas[tokenId];
    }

    function getBaseUri() public pure returns (string memory) {
        return BASE_URI;
    }

    function getNftCounter() public view returns (uint256) {
        return s_nftCounter;
    }

    function getCurrentHrvSupply() public view returns (uint256) {
        return s_hrvCurrentSupply;
    }
}

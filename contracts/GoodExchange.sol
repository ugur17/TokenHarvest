// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

// import "./ProducerContract.sol";
import "./TokenHarvest.sol";

/* Errors */
error GoodExchange__ProductNotCertified();
error GoodExchange__InvalidListingId();
error GoodExchange__ProductAlreadySold();
error GoodExchange__InsufficientFunds();
error GoodExchange__InvalidListingPrice();
error GoodExchange__AlreadyListed();

contract GoodExchange is TokenHarvest {
    //     // While writing purchase function, don't forget to check if the amount of tokens which the customer trying
    //     // to buy is bigger then the total amount of token. After purchase, if left amount is zero, then delete the product.

    /* Type declarations */
    struct Listing {
        address producer;
        uint256 amount;
        uint256 unitPrice;
    }

    /* State variables */
    mapping(address => mapping(uint256 => Listing)) private listingByProducer; // producer => token id => Listing

    //     /* Events */
    //     event ProductListed(uint256 indexed productId, address indexed producer, uint256 price);
    //     event ProductPurchased(uint256 indexed productId, address indexed buyer, uint256 price);

    modifier notListed(address account, uint256 tokenId) {
        if (listingByProducer[account][tokenId].amount > 0) {
            revert GoodExchange__AlreadyListed();
        }
        _;
    }

    constructor() TokenHarvest(msg.sender) {}

    /**
     * @dev This is the function to make any product open to sell
     * @param tokenId Id of the product which the msg.sender wants sell
     * @param amount The amount of token which the owner wants to list for sale
     * @param unitPrice Price of the product which msg.sender desire
     */
    function listProductForSale(
        uint256 tokenId,
        uint256 amount,
        uint256 unitPrice
    ) external onlyOwnerHasEnoughToken(msg.sender, tokenId, amount) notListed(msg.sender, tokenId) {
        if (unitPrice <= 0) {
            revert GoodExchange__InvalidListingPrice();
        }
        // will be continued...
    }

    //     /**
    //      *
    //      * @param listingIndex
    //      */
    //     function purchaseProduct(uint256 listingIndex) external payable {
    //         if (listingIndex > productListingByProducer[msg.sender].length) {
    //             revert GoodExchange__InvalidListingId();
    //         }
    //         ProductListing storage listing = productListingByProducer[msg.sender][listingIndex];
    //         if (listing.isSold) {
    //             revert GoodExchange__ProductAlreadySold();
    //         }
    //         if (msg.value < listing.price) {
    //             revert GoodExchange__InsufficientFunds();
    //         }

    //         listing.isSold = true;
    //         payable(listing.producer).transfer(listing.price);

    //         emit ProductPurchased(listing.productId, msg.sender, listing.price);
    //     }

    //     function getProducerContract(uint256 index) external view returns (ProducerContract) {
    //         return s_producerContracts[index];
    //     }

    //     function getProductListingByProducer(
    //         address producer,
    //         uint256 index
    //     ) public view returns (ProductListing) {
    //         return productListingByProducer[producer][index];
    //     }

    //     function getProductListingsCountByProducer(address _producer) external view returns (uint256) {
    //         return productListingByProducer[_producer].length;
    //     }
}

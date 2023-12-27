// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTHarvest.sol";
import "./HarvestToken.sol";
import "./OperationCenter.sol";

import "./Auth.sol";

/* Errors */
error GoodExchange__ProductNotCertified();
error GoodExchange__InsufficientFunds();
error GoodExchange__InvalidListingPrice();
error GoodExchange__AlreadyListed();
error GoodExchange__ProductNotListed();
error GoodExchange__NotEnoughSupplyForSale();
error GoodExchange__InvalidAmount();
error GoodExchange__ZeroIsIdOfFungibleToken();
error GoodExchange__MarketPlaceNotApprovedBySeller();
error GoodExchange__MarketPlaceNotApprovedByBuyer();

contract GoodExchange is Auth {
    /* Type declarations */
    struct Listing {
        address producer;
        uint256 amount;
        uint256 unitPrice;
    }

    NFTHarvest nftContract;
    HarvestToken token;
    OperationCenter dao;

    /* State variables */
    mapping(address => mapping(uint256 => Listing)) private listingByProducer; // producer => token id => Listing

    /* Events */
    event ProductListed(
        uint256 indexed tokenId,
        address indexed producer,
        uint256 amount,
        uint256 unitPrice
    );

    event ListingCancelled(uint256 indexed tokenId, address indexed producer);

    event ListingUpdated(
        uint256 indexed tokenId,
        address indexed producer,
        uint256 amount,
        uint256 unitPrice
    );

    event ProductPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 amount,
        uint256 unitPrice
    );

    /* Modifiers */
    modifier onlyNotListed(address account, uint256 tokenId) {
        if (listingByProducer[account][tokenId].amount > 0) {
            revert GoodExchange__AlreadyListed();
        }
        _;
    }

    modifier onlyListed(address account, uint256 tokenId) {
        if (listingByProducer[account][tokenId].producer == address(0)) {
            revert GoodExchange__ProductNotListed();
        }
        _;
    }

    modifier invalidPrice(uint256 price) {
        if (price <= 0) {
            revert GoodExchange__InvalidListingPrice();
        }
        _;
    }

    modifier invalidAmount(uint256 amount) {
        if (amount <= 0) {
            revert GoodExchange__InvalidAmount();
        }
        _;
    }

    modifier onlyCertified(uint256 tokenId) {
        if (nftContract.getIsCertified(tokenId) == false) {
            revert GoodExchange__ProductNotCertified();
        }
        _;
    }

    modifier onlyOwnerHasEnoughToken(
        address owner,
        uint256 tokenId,
        uint256 amount
    ) {
        if (nftContract.getBalanceOf(owner, tokenId) < amount) {
            revert TokenHarvest__NotEnoughToken();
        }
        _;
    }

    constructor(
        address nftContractAddress,
        address harvestTokenContractAddress,
        address daoAddress
    ) {
        nftContract = NFTHarvest(nftContractAddress);
        token = HarvestToken(harvestTokenContractAddress);
        dao = OperationCenter(daoAddress);
    }

    /* Functions */

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
    )
        external
        invalidPrice(unitPrice)
        invalidAmount(amount)
        onlyOwnerHasEnoughToken(msg.sender, tokenId, amount)
        onlyNotListed(msg.sender, tokenId)
        onlyCertified(tokenId)
    {
        // check for approval
        if (nftContract.isApprovedForAll(msg.sender, address(this)) == false) {
            revert GoodExchange__MarketPlaceNotApprovedBySeller();
        }
        listingByProducer[msg.sender][tokenId] = Listing(msg.sender, amount, unitPrice);
        emit ProductListed(tokenId, msg.sender, amount, unitPrice);
    }

    function cancelListing(
        uint256 tokenId
    )
        external
        onlyListed(msg.sender, tokenId)
        onlyOwnerHasEnoughToken(msg.sender, tokenId, listingByProducer[msg.sender][tokenId].amount)
    {
        delete listingByProducer[msg.sender][tokenId];
        emit ListingCancelled(tokenId, msg.sender);
    }

    function updateListing(
        uint256 tokenId,
        uint256 amount,
        uint256 unitPrice
    )
        external
        invalidPrice(unitPrice)
        invalidAmount(amount)
        onlyListed(msg.sender, tokenId)
        onlyOwnerHasEnoughToken(msg.sender, tokenId, amount)
    {
        listingByProducer[msg.sender][tokenId].amount = amount;
        listingByProducer[msg.sender][tokenId].unitPrice = unitPrice;
        emit ListingUpdated(tokenId, msg.sender, amount, unitPrice);
    }

    // Whole function will be updated
    function purchaseProduct(
        address producer,
        uint256 tokenId,
        uint256 amount
    ) external invalidAmount(amount) onlyListed(producer, tokenId) {
        Listing memory listing = listingByProducer[producer][tokenId];
        if (listing.amount < amount) {
            revert GoodExchange__NotEnoughSupplyForSale();
        }
        uint256 totalPrice = listing.amount * listing.unitPrice;
        if (token.balanceOf(msg.sender) < totalPrice) {
            revert GoodExchange__InsufficientFunds();
        }
        // check for approvals
        if (nftContract.isApprovedForAll(producer, address(this)) == false) {
            revert GoodExchange__MarketPlaceNotApprovedBySeller();
        }
        if (token.allowance(msg.sender, address(this)) < totalPrice) {
            revert GoodExchange__MarketPlaceNotApprovedByBuyer();
        }
        // make the payment as hrv token
        token.transferFrom(msg.sender, address(dao), totalPrice);
        dao.handlePurchase(producer, totalPrice);
        // send nft to the account who send money as hrv token
        nftContract.safeTransferFrom(producer, msg.sender, tokenId, amount, "");
        if (listing.amount == amount) {
            delete listingByProducer[producer][tokenId];
        } else {
            listingByProducer[producer][tokenId].amount -= amount;
        }
        emit ProductPurchased(tokenId, msg.sender, amount, listing.unitPrice);
    }

    /* Getter Functions */
    function getListing(
        address producer,
        uint256 tokenId
    ) external view onlyListed(producer, tokenId) returns (Listing memory) {
        return listingByProducer[producer][tokenId];
    }
}

const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("GoodExchange Contract Unit Tests", function () {
        let deployer, accounts, inspector, producer;
        let goodExchange, inspectorContract, producerContract, producerConnectedGoodExchange;
        let producerConnectedNftContract, buyerConnectedNftContract;
        let producerConnectedAuth, inspectorConnectedAuth;
        let buyerConnectedHarvestToken
        let tokenId, totalProductAmount, productAmountOfEachToken, saleAmount, unitPrice;
        const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
        beforeEach(async () => {
            accounts = await ethers.getSigners();
            deployer = accounts[0]; // will act as a buyer
            inspector = accounts[1];
            producer = accounts[2];
            await deployments.fixture(["goodExchange", "nftHarvest", "harvestToken", "operationCenter", "auth", "producerContract", "inspectorContract"]);
            producerConnectedAuth = await ethers.getContract("Auth", producer);
            inspectorConnectedAuth = await ethers.getContract("Auth", inspector);
            goodExchange = await ethers.getContract("GoodExchange", deployer);
            producerConnectedGoodExchange = await ethers.getContract("GoodExchange", producer);
            inspectorContract = await ethers.getContract("InspectorContract", inspector);
            producerContract = await ethers.getContract("ProducerContract", producer);
            producerConnectedNftContract = await ethers.getContract("NFTHarvest", producer);
            buyerConnectedNftContract = await ethers.getContract("NFTHarvest", deployer);
            buyerConnectedHarvestToken = await ethers.getContract("HarvestToken", deployer);
            // register, create product, send certification request, accept the request, certify the product
            tokenId = 0;
            totalProductAmount = 10;
            productAmountOfEachToken = 5;
            saleAmount = 5
            unitPrice = 5;
            await producerConnectedAuth.register("producer", "producer@hotmail.com", 0);
            await inspectorConnectedAuth.register("inspector", "inspector@hotmail.com", 1);
            await producerConnectedNftContract.mintNFT(totalProductAmount, "cucumber", productAmountOfEachToken);
            await producerContract.requestCertification(tokenId);
            await inspectorContract.acceptCertificationRequest(tokenId);
        }),
        describe("listProductForSale Function", () => {
            it("revert if price is invalid", async () => {
                await expect(producerConnectedGoodExchange.listProductForSale(tokenId, 5, 0)).to.be.revertedWithCustomError(producerConnectedGoodExchange, "GoodExchange__InvalidListingPrice()");
            })
            it("reverts if the amount is invalid", async () => {
                await expect(producerConnectedGoodExchange.listProductForSale(tokenId, 0, 5)).to.be.revertedWithCustomError(producerConnectedGoodExchange, "GoodExchange__InvalidAmount()");                
            }),
            it("revert if the seller does not have enough token", async () => {
                await expect(producerConnectedGoodExchange.listProductForSale(tokenId, 15, 5)).to.be.revertedWithCustomError(producerConnectedGoodExchange, "GoodExchange__NotEnoughToken()");
            }),
            it("revert if product is not certified", async () => {
                await expect(producerConnectedGoodExchange.listProductForSale(tokenId, 5, 5)).to.be.revertedWithCustomError(producerConnectedGoodExchange, "GoodExchange__ProductNotCertified()");                
            }),
            it("revert if contract not approved", async () => {
                await inspectorContract.approveCertification(tokenId);
                await expect(producerConnectedGoodExchange.listProductForSale(tokenId, 5, 5)).to.be.revertedWithCustomError(producerConnectedGoodExchange, "GoodExchange__MarketPlaceNotApprovedBySeller()");
            }),
            it("execute funtion successfully", async () => {
                await inspectorContract.approveCertification(tokenId);
                producerConnectedNftContract.setApprovalForAll(producerConnectedGoodExchange.target, true);
                await producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice);
                const listing = await producerConnectedGoodExchange.listingByProducer(producer.address, tokenId);
                assert.equal(Number(listing.producer), producer.address);
                assert.equal(Number(listing.amount), saleAmount)
                assert.equal(listing.unitPrice, unitPrice);
            }),
            it("revert if token already listed", async () => {
                await inspectorContract.approveCertification(tokenId);
                producerConnectedNftContract.setApprovalForAll(producerConnectedGoodExchange.target, true);
                await producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice);
                await expect(producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice)).to.be.revertedWithCustomError(producerConnectedGoodExchange, "GoodExchange__AlreadyListed()");
            }),
            it("emits the event", async () => {
                await inspectorContract.approveCertification(tokenId);
                producerConnectedNftContract.setApprovalForAll(producerConnectedGoodExchange.target, true);
                await expect(producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice)).to.emit(producerConnectedGoodExchange, "ProductListed").withArgs(tokenId, producer.address, saleAmount, unitPrice);
            })
        }),
        describe("cancelListing()", () => {
            beforeEach(async () => {
                await inspectorContract.approveCertification(tokenId);
                producerConnectedNftContract.setApprovalForAll(producerConnectedGoodExchange.target, true);
            }),
            it("revert if not listed by producer", async () => {
                await expect(producerConnectedGoodExchange.cancelListing(tokenId)).to.be.revertedWithCustomError(producerConnectedGoodExchange, "GoodExchange__ProductNotListedByThisProducer()");
            }),
            it("execute the function successfully", async () => {
                await producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice);
                await producerConnectedGoodExchange.cancelListing(tokenId);
                const listing = await producerConnectedGoodExchange.listingByProducer(producer.address, tokenId);
                assert.equal(listing.producer, ZERO_ADDRESS);
            }),
            it("emits the event", async () => {
                await producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice);
                await expect(producerConnectedGoodExchange.cancelListing(tokenId)).to.emit(producerConnectedGoodExchange, "ListingCancelled").withArgs(tokenId, producer.address);
            })
        }),
        describe("updateListing()", () => {
            beforeEach(async () => {
                await inspectorContract.approveCertification(tokenId);
                producerConnectedNftContract.setApprovalForAll(producerConnectedGoodExchange.target, true);
            }),
            it("revert if price is invalid", async () => {
                await expect(producerConnectedGoodExchange.updateListing(tokenId, 5, 0)).to.be.revertedWithCustomError(producerConnectedGoodExchange, "GoodExchange__InvalidListingPrice()");
            })
            it("reverts if the amount is invalid", async () => {
                await expect(producerConnectedGoodExchange.updateListing(tokenId, 0, 5)).to.be.revertedWithCustomError(producerConnectedGoodExchange, "GoodExchange__InvalidAmount()");                
            }),
            it("revert if not listed by the caller of the function", async () => {
                await expect(goodExchange.updateListing(tokenId, 10, 5)).to.be.revertedWithCustomError(goodExchange, "GoodExchange__ProductNotListedByThisProducer()");
            })
            it("revert if the seller does not have enough token", async () => {
                await producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice);
                await expect(producerConnectedGoodExchange.updateListing(tokenId, 15, 5)).to.be.revertedWithCustomError(producerConnectedGoodExchange, "GoodExchange__NotEnoughToken()");
            }),
            it("executes the function succesfully", async () => {
                const newAmount = saleAmount - 1;
                const newUnitPrice = unitPrice + 2;
                await producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice);
                await producerConnectedGoodExchange.updateListing(tokenId, newAmount, newUnitPrice);
                const listing = await producerConnectedGoodExchange.listingByProducer(producer.address, tokenId);
                assert.equal(listing.amount, newAmount);
                assert.equal(listing.unitPrice, newUnitPrice);
            }),
            it("emits the event", async () => {
                const newAmount = saleAmount - 1;
                const newUnitPrice = unitPrice + 2;
                await producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice);
                await expect(producerConnectedGoodExchange.updateListing(tokenId, newAmount, newUnitPrice)).to.emit(producerConnectedGoodExchange, "ListingUpdated").withArgs(tokenId, producer.address, newAmount, newUnitPrice);
            })
        }),
        describe("purchaseProduct()", () => {
            let purchaseAmount, listing;
            beforeEach(async () => {
                await inspectorContract.approveCertification(tokenId);
                producerConnectedNftContract.setApprovalForAll(producerConnectedGoodExchange.target, true);
                await producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice);
                listing = await producerConnectedGoodExchange.getListing(producer.address, tokenId);
                purchaseAmount = 3;
            }),
            it("revert if purchase amount is invalid", async () => {
                await expect(goodExchange.purchaseProduct(producer.address, tokenId, 0)).to.be.revertedWithCustomError(goodExchange, "GoodExchange__InvalidAmount()");
            }),
            it("revert if not listed by given producer", async () => {
                await expect(goodExchange.purchaseProduct(inspector.address, tokenId, purchaseAmount)).to.be.revertedWithCustomError(goodExchange, "GoodExchange__ProductNotListedByThisProducer()");
            }),
            it("revert if purchase amount > the listed amount", async () => {
                await expect(goodExchange.purchaseProduct(producer.address, tokenId, saleAmount + 5)).to.be.revertedWithCustomError(goodExchange, "GoodExchange__NotEnoughSupplyForSale()");
            }),
            // it("revert if buyer does not have enough token", async () => {
            //     await expect(goodExchange.purchaseProduct(producer.address, tokenId, purchaseAmount)).to.be.revertedWithCustomError(goodExchange, "GoodExchange__InsufficientFunds()");
            // }),
            it("revert if marketplace not approved by buyer", async () => {
                await expect(goodExchange.purchaseProduct(producer.address, tokenId, purchaseAmount)).to.be.revertedWithCustomError(goodExchange, "GoodExchange__MarketPlaceNotApprovedByBuyer()");
            }),
            it("execute the function successfully", async () => {
                const balanceOfBuyerBeforePurchase = await buyerConnectedHarvestToken.balanceOf(deployer.address);
                const prevNftBalanceOfBuyer = await buyerConnectedNftContract.balanceOf(deployer.address, tokenId);
                await buyerConnectedHarvestToken.approve(goodExchange.target, (listing.amount * listing.unitPrice));
                await goodExchange.purchaseProduct(producer.address, tokenId, purchaseAmount);
                const balanceOfBuyerAfterPurchase = await buyerConnectedHarvestToken.balanceOf(deployer.address);
                const afterNftBalanceOfBuyer = await buyerConnectedNftContract.balanceOf(deployer.address, tokenId);
                const afterListing = await goodExchange.getListing(producer.address, tokenId);
                assert.equal(Number(afterListing.amount), Number(listing.amount) - purchaseAmount);
                assert(Number(balanceOfBuyerAfterPurchase), Number(balanceOfBuyerBeforePurchase) - 15);
                assert(Number(afterNftBalanceOfBuyer), Number(prevNftBalanceOfBuyer) + 3);
            }),
            it("emits the event", async () => {
                await buyerConnectedHarvestToken.approve(goodExchange.target, (listing.amount * listing.unitPrice));
                await expect(goodExchange.purchaseProduct(producer.address, tokenId, purchaseAmount)).to.emit(goodExchange, "ProductPurchased").withArgs(tokenId, deployer.address, purchaseAmount, listing.unitPrice);
            })
        })
    })
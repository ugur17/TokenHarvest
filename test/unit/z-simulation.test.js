const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Simulation", function () {
        let accounts, deployer, inspector, producer;
        let dao, auth, harvestToken;
        let inspectorConnectedAuth, producerConnectedAuth, inspectorConnectedDao, producerConnectedProducerContract;
        let producerConnectedNftHarvest;
        let description, protocolId, proposalIndex;
        let tokenId;
        let purchaseAmount;
        const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
        const GUARANTEED_AMOUNT = 10; 
        // this is the token credit amount which will be credited to the producer after proposal passed and executed
        const CREDIT_AMOUNT = 10; 
        // this is the fee amount which will be paid to the inspector 
        const INSPECTOR_FEE = 5;
        beforeEach(async () => {
            accounts = await ethers.getSigners();
            deployer = accounts[0];
            inspector = accounts[1];
            producer = accounts[2];
            await deployments.fixture(["operationCenter", "producerContract", "harvestToken", "nftHarvest", "auth", "inspectorContract", "goodExchange"]);
            dao = await ethers.getContract("OperationCenter", deployer);
            inspectorConnectedDao = dao.connect(inspector);
            auth = await ethers.getContract("Auth", deployer);
            inspectorConnectedAuth = auth.connect(inspector);
            console.log();
            console.log("Inspector is registering to the system...");
            await inspectorConnectedAuth.register("inspector", "inspector@hotmail.com", 1); // 1 means inspector
            producerConnectedAuth = auth.connect(producer);
            console.log("Producer is registering to the system...");
            await producerConnectedAuth.register("producer", "producer@hotmail.com", 0); // 0 means producer
            producerConnectedProducerContract = await ethers.getContract("ProducerContract", producer);
            harvestToken = await ethers.getContract("HarvestToken", deployer);
            producerConnectedNftHarvest = await ethers.getContract("NFTHarvest", producer);
            inspectorConnectedHarvestToken = await ethers.getContract("HarvestToken", inspector);
            inspectorConnectedInspectorContract = await ethers.getContract("InspectorContract", inspector);
            producerConnectedGoodExchange = await ethers.getContract("GoodExchange", producer);
            buyerConnectedNftContract = await ethers.getContract("NFTHarvest", deployer);
            buyerConnectedHarvestToken = await ethers.getContract("HarvestToken", deployer);
            goodExchange = await ethers.getContract("GoodExchange", deployer);
            protocolId = 6;
            description = "Farmer x, requests to sign the protocol number " + protocolId + " with dao. Conditions: *****. Expected Result: *****";
            proposalIndex = 0;
            tokenId = 0;
            totalProductAmount = 10;
            productAmountOfEachToken = 5;
            saleAmount = 5
            unitPrice = 5;
            purchaseAmount = 3;
        }),
        describe("Simulation starting...", () => {
            it("-------------", async () => {
                console.log();
                console.log("Inspector is being member of dao...");
                await dao.addMemberOfDao(inspector.address);
                console.log();
                console.log("Protocol request is sending by producer to the dao...");
                await producerConnectedProducerContract.requestProtocolWithDao(protocolId);
                console.log();
                console.log("Proposal is creating by dao members...");
                await inspectorConnectedDao.createProposal(description, protocolId, producer);
                console.log();
                console.log("Created proposal is printing...");
                let proposal = await dao.proposals(proposalIndex);
                console.log(proposal);
                console.log();
                console.log("Voting for the proposal just created...");
                await inspectorConnectedDao.vote(proposalIndex, true);
                console.log();
                console.log("Proposal is executing...");
                await harvestToken.transfer(dao.target, 100000);
                await network.provider.send("evm_increaseTime", [Number(proposal.deadline) + 1]);
                await inspectorConnectedDao.executeProposal(proposalIndex, CREDIT_AMOUNT);
                console.log();
                console.log("Proposal printing after voting and execution processes...");
                proposal =  await dao.proposals(proposalIndex);
                console.log(proposal);
                console.log();
                console.log("Assigning inspector to the proposal...");
                await harvestToken.transfer(inspector.address, 100);
                await inspectorConnectedHarvestToken.approve(inspectorConnectedInspectorContract.target, GUARANTEED_AMOUNT);
                await inspectorConnectedInspectorContract.assignInspectorToProposal(proposalIndex, GUARANTEED_AMOUNT);
                console.log();
                console.log("Process inspection is approving...");
                await inspectorConnectedInspectorContract.approveProcessInspection(proposalIndex);

                console.log();
                console.log("Cucumber product is creating...");
                console.log();
                await producerConnectedNftHarvest.mintNFT(10, "cucumber", 5);
                console.log("Token uri link is printing...");
                let uri = await producerConnectedNftHarvest.uri(tokenId);
                console.log(uri);
                console.log();
                console.log("Token uri string is printing...");
                let stringUri = await producerConnectedNftHarvest.getUriString(tokenId);
                console.log(stringUri);
                console.log();
                console.log("Product certification is requesting by producer...");
                await producerConnectedProducerContract.requestCertification(tokenId);
                console.log();
                console.log("Product certification request is being accepted by inspector...");
                await inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId);
                console.log();
                console.log("Product certification request is being approved by inspector...");
                await inspectorConnectedInspectorContract.approveCertification(tokenId);
                console.log();

                console.log("Product is listing for sale...");
                producerConnectedNftHarvest.setApprovalForAll(producerConnectedGoodExchange.target, true);
                await producerConnectedGoodExchange.listProductForSale(tokenId, saleAmount, unitPrice);
                console.log();
                console.log("Listing is printing...");
                const listing = await producerConnectedGoodExchange.listingByProducer(producer.address, tokenId);
                console.log(listing);
                console.log();
                console.log("Product is purchasing by customer...");
                await buyerConnectedHarvestToken.approve(goodExchange.target, (listing.amount * listing.unitPrice));
                await goodExchange.purchaseProduct(producer.address, tokenId, purchaseAmount);
                console.log();
                console.log("Listing is printing after purchase...");
                const afterPurchaseListing = await producerConnectedGoodExchange.listingByProducer(producer.address, tokenId);;
                console.log(afterPurchaseListing);
            })
        })
    })
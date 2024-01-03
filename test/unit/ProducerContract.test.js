const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("ProducerContract Unit Tests", function () {
        let deployer, accounts, producerContract, nftHarvest, auth;
        beforeEach(async () => {
            accounts = await ethers.getSigners();
            deployer = accounts[0];
            await deployments.fixture(["producerContract", "nftHarvest", "harvestToken", "auth"]);
            producerContract = await ethers.getContract("ProducerContract", deployer);
            nftHarvest = await ethers.getContract("NFTHarvest", deployer);
            auth = await ethers.getContract("Auth", deployer);
        }),
        describe("requestCertification()", () => {
            beforeEach(async () => {
                await auth.register("jieun", "jieun@hotmail.com", 0);
                await nftHarvest.mintNFT(10, "cucumber", 5);
            }),
            it("revert if the user is not producer", async () => {
                const connectedProducerContract = producerContract.connect(accounts[1]);
                const connectedAuthContract = auth.connect(accounts[1]);
                await connectedAuthContract.register("jieun2", "jieun2@hotmail.com", 1);
                await expect(connectedProducerContract.requestCertification(0)).to.be.revertedWithCustomError(connectedProducerContract, "ProducerContract__InsufficientRole()");
            }),
            it("revert if token id does not exist", async () => {
                await expect(producerContract.requestCertification(5)).to.be.revertedWithCustomError(producerContract, "ProducerContract__TokenDoesNotExist()");
            }),
            it("adds the new certification request", async () => {
                await producerContract.requestCertification(0);
                const producerAddressOfNewRequest = await producerContract.certificationRequests(0);
                assert.equal(producerAddressOfNewRequest.producer, deployer.address);
            }),
            it("emits the event", async () => {
                await expect(producerContract.requestCertification(0)).to.emit(producerContract, "CertificationRequested").withArgs(0, deployer.address);
            })
        }),
        describe("requestProtocolWithDao()", () => {
            it("revert if the ser is not producer", async () => {
                await auth.register("jieun", "jieun@hotmail.com", 1); // 1 means inspector
                const protocolId = 0;
                await expect(producerContract.requestProtocolWithDao(protocolId)).to.be.revertedWithCustomError(producerContract, "ProducerContract__InsufficientRole()");
            }),
             it("adds the new protocol request to the mapping", async () => {
                await auth.register("jieun", "jieun@hotmail.com", 0); // 0 means producer
                const protocolId = 0;
                await producerContract.requestProtocolWithDao(protocolId);
                const boolRequestedProtocolsByProducers = await producerContract.requestedProtocolsByProducers(deployer.address, protocolId);
                assert.equal(boolRequestedProtocolsByProducers, true);
             }),
              it("emits the event", async () => {
                await auth.register("jieun", "jieun@hotmail.com", 0); // 0 means producer
                const protocolId = 0;
                await expect(producerContract.requestProtocolWithDao(protocolId)).to.emit(producerContract, "ProtocolRequested").withArgs(protocolId, deployer.address);
              })
        }),
        describe("setRequestedProtocolsByProducersMapping()", () => {
            it("sets the parameter values", async () => {
                await auth.register("jieun", "jieun@hotmail.com", 0); // 0 means producer
                const protocolId = 0;
                await producerContract.requestProtocolWithDao(protocolId);
                await producerContract.setRequestedProtocolsByProducersMapping(deployer.address, protocolId, false);
                const boolRequestedProtocolsByProducers = await producerContract.requestedProtocolsByProducers(deployer.address, protocolId);
                assert.equal(boolRequestedProtocolsByProducers, false);
            })
        }),
        describe("getRequestedProtocolsByProducersMapping()", () => {
            it("get the output values", async () => {
                await auth.register("jieun", "jieun@hotmail.com", 0); // 0 means producer
                const protocolId = 0;
                await producerContract.requestProtocolWithDao(protocolId);
                const boolRequestedProtocolsByProducers = await producerContract.getRequestedProtocolsByProducersMapping(deployer.address, protocolId);
                assert.equal(boolRequestedProtocolsByProducers, true);
            })
        })
    })
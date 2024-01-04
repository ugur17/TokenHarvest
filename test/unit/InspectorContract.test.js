const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("InspectorContract Contract Unit Tests", function () {
        let deployer, accounts, inspector, producer;
        let inspectorContract, inspectorConnectedInspectorContract;
        let producerConnectedProducerContract
        let inspectorConnectedAuth, producerConnectedAuth;
        let producerConnectedNftContract;
        let tokenId;
        const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
        const GUARANTEED_AMOUNT = 10; 
        beforeEach(async () => {
            accounts = await ethers.getSigners();
            deployer = accounts[0];
            inspector = accounts[1];
            producer = accounts[2];
            await deployments.fixture(["inspectorContract", "operationCenter", "producerContract", "nftHarvest", "harvestToken", "auth"]);
            inspectorContract = await ethers.getContract("InspectorContract", deployer);
            inspectorConnectedInspectorContract = await ethers.getContract("InspectorContract", inspector);
            producerConnectedProducerContract = await ethers.getContract("ProducerContract", producer);
            inspectorConnectedAuth = await ethers.getContract("Auth", inspector);
            producerConnectedAuth = await ethers.getContract("Auth", producer);
            producerConnectedNftContract = await ethers.getContract("NFTHarvest", producer);
            await inspectorConnectedAuth.register("inspector", "inspector@hotmail.com", 1);
            await producerConnectedAuth.register("producer", "producer@hotmail.com", 0);
            tokenId = 0;
        }),
        describe("acceptCertificationRequest()", () => {
            it("revert if the caller is not inspector", async () => {
                await expect(inspectorContract.acceptCertificationRequest(tokenId)).to.be.revertedWithCustomError(inspectorContract, "InspectorContract__InsufficientRole()");
            }),
            it("revert if certification not requested", async () => {
                await expect(inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId)).to.be.revertedWithCustomError(inspectorConnectedInspectorContract, "InspectorContract__InspectionRequestNotFound()");
            }),
            it("execute the function successfully", async () => {
                await producerConnectedNftContract.mintNFT(10, "cucumber", 5);
                await producerConnectedProducerContract.requestCertification(tokenId);
                await inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId);
                const inspectorOfCertificationRequest = await producerConnectedProducerContract.getInspectorOfCertificationRequest(tokenId);
                assert.equal(inspectorOfCertificationRequest, inspector.address);
            }),
             it("emits the event", async () => {
                await producerConnectedNftContract.mintNFT(10, "cucumber", 5);
                await producerConnectedProducerContract.requestCertification(tokenId);
                await expect(inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId)).to.emit(inspectorConnectedInspectorContract, "CertificationRequestAccepted").withArgs(tokenId, inspector.address);
             })
        }),
        describe("approveCertification()", () => {
            beforeEach(async () => {
                await producerConnectedNftContract.mintNFT(10, "cucumber", 5);
                await producerConnectedProducerContract.requestCertification(tokenId);
            }),
            it("revert if request not accepted by inspector", async () => {
                await expect(inspectorConnectedInspectorContract.approveCertification(tokenId)).to.be.revertedWithCustomError(inspectorConnectedInspectorContract, "InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId()");
            })
            it("revert if caller is not inspector", async () => {
                await inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId);
                await expect(inspectorContract.approveCertification(tokenId)).to.be.revertedWithCustomError(inspectorContract, "InspectorContract__InsufficientRole()");
            }),
            it("execute function successfully", async () => {
                await inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId);
                await inspectorConnectedInspectorContract.approveCertification(tokenId);
                // request will be deleted, because product already certified
                const certificationRequestInspectorAddress = await producerConnectedProducerContract.getCertificationRequestInspector(tokenId);
                assert.equal(certificationRequestInspectorAddress, ZERO_ADDRESS);
            }),
            it("certify nft in the metadata mapping", async () => {
                await inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId);
                await inspectorConnectedInspectorContract.approveCertification(tokenId);
                const metadata = await producerConnectedNftContract.s_nftMetadatas(tokenId);
                assert.equal(metadata.isCertified, true);
            })
            it("emits the event", async () => {
                await inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId);
                await expect(inspectorConnectedInspectorContract.approveCertification(tokenId)).to.emit(inspectorConnectedInspectorContract, "CertificationApproved").withArgs(tokenId, inspector.address);
            })
        }),
        describe("rejectCertification()", () => {
            beforeEach(async () => {
                await producerConnectedNftContract.mintNFT(10, "cucumber", 5);
                await producerConnectedProducerContract.requestCertification(tokenId);
            }),
            it("revert if request not accepted by inspector", async () => {
                await expect(inspectorConnectedInspectorContract.rejectCertification(tokenId)).to.be.revertedWithCustomError(inspectorConnectedInspectorContract, "InspectorContract__YouDidntAcceptAnyRequestWithThisTokenId()");
            })
            it("revert if caller is not inspector", async () => {
                await inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId);
                await expect(inspectorContract.rejectCertification(tokenId)).to.be.revertedWithCustomError(inspectorContract, "InspectorContract__InsufficientRole()");
            }),
            it("execute function successfully", async () => {
                await inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId);
                await inspectorConnectedInspectorContract.rejectCertification(tokenId);
                const certificationRequestInspectorAddress = await producerConnectedProducerContract.getCertificationRequestInspector(tokenId);
                assert.equal(certificationRequestInspectorAddress, ZERO_ADDRESS);
            }),
            it("emits the event", async () => {
                await inspectorConnectedInspectorContract.acceptCertificationRequest(tokenId);
                await expect(inspectorConnectedInspectorContract.rejectCertification(tokenId)).to.emit(inspectorConnectedInspectorContract, "CertificationRejected").withArgs(tokenId, inspector.address);
            })
        }),
        describe("assignInspectorToProposal()", () => {
            let proposalIndex, description, protocolId;
            let dao, inspectorConnectedDao, harvestToken, inspectorConnectedHarvestToken;
            beforeEach(async () => {
                description = "abc";
                protocolId = 6;
                proposalIndex = 0;
                dao = await ethers.getContract("OperationCenter", deployer);
                inspectorConnectedDao = await ethers.getContract("OperationCenter", inspector);
                harvestToken = await ethers.getContract("HarvestToken", deployer);
                inspectorConnectedHarvestToken = await ethers.getContract("HarvestToken", inspector);
                await dao.addMemberOfDao(inspector.address);
                await producerConnectedProducerContract.requestProtocolWithDao(protocolId);
                await inspectorConnectedDao.createProposal(description, protocolId, producer);
                await inspectorConnectedDao.vote(proposalIndex, true);
                await harvestToken.transfer(dao.target, 100000);
                await harvestToken.transfer(inspector.address, 100);
                proposal = await inspectorConnectedDao.proposals(proposalIndex);
                await network.provider.send("evm_increaseTime", [Number(proposal.deadline) + 1]);
                await inspectorConnectedDao.executeProposal(proposalIndex, GUARANTEED_AMOUNT);
            }),
            it("revert if caller is not inspector", async () => {
                await expect(inspectorContract.assignInspectorToProposal(proposalIndex, GUARANTEED_AMOUNT)).to.be.revertedWithCustomError(inspectorContract, "InspectorContract__InsufficientRole()");
            }),
            describe("_sendGuaranteedAmount", () => {
                it("executes function successfully", async () => {
                    const beforeBalanceOfInspector = await harvestToken.balanceOf(inspector.address);
                    await inspectorConnectedHarvestToken.approve(inspectorConnectedInspectorContract.target, GUARANTEED_AMOUNT);
                    await inspectorConnectedInspectorContract._sendGuaranteedAmount(inspector.address, GUARANTEED_AMOUNT);
                    const afterBalanceOfInspector = await harvestToken.balanceOf(inspector.address);
                    assert.equal(Number(afterBalanceOfInspector) + GUARANTEED_AMOUNT, beforeBalanceOfInspector);
                })
            })
            it("execute function successfully", async () => {
                const beforeBalanceOfInspector = await harvestToken.balanceOf(inspector.address);
                await inspectorConnectedHarvestToken.approve(inspectorConnectedInspectorContract.target, GUARANTEED_AMOUNT);
                await inspectorConnectedInspectorContract.assignInspectorToProposal(proposalIndex, GUARANTEED_AMOUNT);
                const afterBalanceOfInspector = await harvestToken.balanceOf(inspector.address);
                assert.equal(Number(afterBalanceOfInspector) + GUARANTEED_AMOUNT, beforeBalanceOfInspector);
            }),
            it("emits the event", async () => {
                await inspectorConnectedHarvestToken.approve(inspectorConnectedInspectorContract.target, GUARANTEED_AMOUNT);
                await expect(inspectorConnectedInspectorContract.assignInspectorToProposal(proposalIndex, GUARANTEED_AMOUNT)).to.emit(inspectorConnectedInspectorContract, "ProcessInspectionAccepted").withArgs(proposalIndex, inspector.address);
            })
        }),
        describe("approveProcessInspection()", () => {
            let proposalIndex, description, protocolId;
            let dao, inspectorConnectedDao, harvestToken, inspectorConnectedHarvestToken;
            beforeEach(async () => {
                description = "abc";
                protocolId = 6;
                proposalIndex = 0;
                dao = await ethers.getContract("OperationCenter", deployer);
                inspectorConnectedDao = await ethers.getContract("OperationCenter", inspector);
                harvestToken = await ethers.getContract("HarvestToken", deployer);
                inspectorConnectedHarvestToken = await ethers.getContract("HarvestToken", inspector);
                await dao.addMemberOfDao(inspector.address);
                await producerConnectedProducerContract.requestProtocolWithDao(protocolId);
                await inspectorConnectedDao.createProposal(description, protocolId, producer);
                await inspectorConnectedDao.vote(proposalIndex, true);
                await harvestToken.transfer(dao.target, 100000);
                await harvestToken.transfer(inspector.address, 100);
                proposal = await inspectorConnectedDao.proposals(proposalIndex);
                await network.provider.send("evm_increaseTime", [Number(proposal.deadline) + 1]);
                await inspectorConnectedDao.executeProposal(proposalIndex, GUARANTEED_AMOUNT);
                await inspectorConnectedHarvestToken.approve(inspectorConnectedInspectorContract.target, GUARANTEED_AMOUNT);
                await inspectorConnectedInspectorContract.assignInspectorToProposal(proposalIndex, GUARANTEED_AMOUNT);
            }),
            it("execute the function successfully", async () => {
                const beforeBalanceOfInspector = await harvestToken.balanceOf(inspector.address);
                const inspectorFee = await inspectorConnectedInspectorContract.INSPECTOR_FEE();
                await inspectorConnectedInspectorContract.approveProcessInspection(proposalIndex);
                const afterBalanceOfInspector = await harvestToken.balanceOf(inspector.address);
                assert.equal(Number(beforeBalanceOfInspector) + Number(inspectorFee) + GUARANTEED_AMOUNT, Number(afterBalanceOfInspector));
            })
        })
    })
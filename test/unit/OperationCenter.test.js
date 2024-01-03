const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("OperationCenter Contract Unit Tests", function () {
        let accounts, deployer, inspector, producer;
        let dao, auth, harvestToken;
        let inspectorConnectedAuth, producerConnectedAuth, inspectorConnectedDao;
        let description, protocolId, proposalIndex;
        const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
        // this is the token credit amount which will be credited to the producer after proposal passed and executed
        const CREDIT_AMOUNT = 10; 
        beforeEach(async () => {
            accounts = await ethers.getSigners();
            deployer = accounts[0];
            inspector = accounts[1];
            producer = accounts[2];
            await deployments.fixture(["operationCenter", "producerContract", "harvestToken", "nftHarvest", "auth"]);
            dao = await ethers.getContract("OperationCenter", deployer);
            inspectorConnectedDao = dao.connect(inspector);
            auth = await ethers.getContract("Auth", deployer);
            inspectorConnectedAuth = auth.connect(inspector);
            await inspectorConnectedAuth.register("inspector", "inspector@hotmail.com", 1); // 1 means inspector
            producerConnectedAuth = auth.connect(producer);
            await producerConnectedAuth.register("producer", "producer@hotmail.com", 0); // 0 means producer
            producerConnectedProducerContract = await ethers.getContract("ProducerContract", producer);
            harvestToken = await ethers.getContract("HarvestToken", deployer);
        }),
        describe("Constructor", () => {
            it("initialize variables correctly", async () => {
                const proposalCounter = await dao.proposalCounter();
                assert.equal(proposalCounter, 0);
            })
        }),
        describe("addMemberOfDao()", () => {
            it("only insector role can be added as a new member", async () => {
                await expect(dao.addMemberOfDao(producer.address)).to.be.revertedWithCustomError(dao, "OperationCenter__InsufficientRole()");
            })
            it("only onwer can add new member", async () => {
                const secondInspector = accounts[3];
                const secondInspectorConnectedAuth = auth.connect(secondInspector);
                secondInspectorConnectedAuth.register("secondInspector", "secondInspector@hotmail.com", 1);
                await expect(inspectorConnectedDao.addMemberOfDao(secondInspector.address)).to.be.reverted;
            }),
            it("adds the new member of dao", async () => {
                await dao.addMemberOfDao(inspector.address);
                const isMember = await dao.daoMemberInspectors(inspector.address);
                assert.equal(isMember, true);
            }),
            it("emits the event", async () => {
                await expect(dao.addMemberOfDao(inspector.address)).to.emit(dao, "NewMemberAdded").withArgs(inspector.address);
            })
        }),
        describe("removeFromMembershipOfDao()", () => {
            it("only owner can remove member", async () => {
                const secondInspector = accounts[3];
                const secondInspectorConnectedAuth = auth.connect(secondInspector);
                secondInspectorConnectedAuth.register("secondInspector", "secondInspector@hotmail.com", 1);
                await dao.addMemberOfDao(secondInspector.address);
                await expect(inspectorConnectedDao.removeFromMembershipOfDao(secondInspector.address)).to.be.reverted;
            }),
            it("remove it successfully", async () => {
                await dao.addMemberOfDao(inspector.address);
                await dao.removeFromMembershipOfDao(inspector.address);
                const isMember = await dao.daoMemberInspectors(inspector.address);
                assert.equal(isMember, false);
            })
        }),
        describe("createProposal()", () => {
            beforeEach(async () => {
                description = "abc";
                protocolId = 6;
                proposalIndex = 0;
            }),
            it("only member of dao can create proposal", async () => {
                await expect(inspectorConnectedDao.createProposal(description, protocolId, producer.address)).to.be.revertedWithCustomError(inspectorConnectedDao, "OperationCenter__YouAreNotMemberOfDao()");
            })
            it("revert if not requested by producer", async () => {
                await dao.addMemberOfDao(inspector.address);
                await expect(inspectorConnectedDao.createProposal(description, protocolId, producer.address)).to.be.revertedWithCustomError(inspectorConnectedDao, "OperationCenter__ThisProtocolNotRequestedByThisProducer()");
            }),
            it("create and add the proposal", async () => {
                await dao.addMemberOfDao(inspector.address);
                await producerConnectedProducerContract.requestProtocolWithDao(protocolId);
                await inspectorConnectedDao.createProposal(description, protocolId, producer);
                const proposal = await inspectorConnectedDao.proposals(proposalIndex);
                assert.equal(proposal.producer, producer.address);
                assert.equal(proposal.description, description);
                assert.equal(proposal.protocolId, protocolId);
                assert.equal(proposal.proposalId, proposalIndex);
            }),
            it("emits the event", async () => {
                await dao.addMemberOfDao(inspector.address);
                await producerConnectedProducerContract.requestProtocolWithDao(protocolId);
                await expect(inspectorConnectedDao.createProposal(description, protocolId, producer)).to.emit(inspectorConnectedDao, "NewProposal").withArgs(proposalIndex, producer.address);
                
            })
        }),
        describe("vote()", () => {
            beforeEach(async () => {
                description = "abc";
                protocolId = 6;
                proposalIndex = 0;
                await dao.addMemberOfDao(inspector.address);
                await producerConnectedProducerContract.requestProtocolWithDao(protocolId);
                await inspectorConnectedDao.createProposal(description, protocolId, producer);
            }),
            it("only member of dao can vote", async () => {
                const secondInspector = accounts[3];
                const secondInspectorConnectedAuth = auth.connect(secondInspector);
                secondInspectorConnectedAuth.register("secondInspector", "secondInspector@hotmail.com", 1);
                const secondInspectorConnectedDao = dao.connect(secondInspector);
                await expect(secondInspectorConnectedDao.vote(proposalIndex, true)).to.be.revertedWithCustomError(secondInspectorConnectedDao, "OperationCenter__YouAreNotMemberOfDao()");
            }),
            it("revert if deadline exceeded", async () => {
                const proposal = await inspectorConnectedDao.proposals(proposalIndex);
                // manipulate the time to test deadline of proposal
                await network.provider.send("evm_increaseTime", [Number(proposal.deadline) + 1]);
                await expect(inspectorConnectedDao.vote(proposalIndex, true)).to.be.revertedWithCustomError(inspectorConnectedDao, "OperationCenter__DeadlineExceeded()");
            }),
            it("add vote successfully", async () => {
                const beforeVoteProposal = await inspectorConnectedDao.proposals(proposalIndex);
                const beforeForVotes = beforeVoteProposal.forVotes;
                await inspectorConnectedDao.vote(proposalIndex, true);
                const afterVoteProposal = await inspectorConnectedDao.proposals(proposalIndex);
                const afterForVotes = afterVoteProposal.forVotes;
                assert.equal(Number(afterForVotes), Number(beforeForVotes) + 1);
            }),
            it("revert if somebody try to vote twice", async () => {
                await inspectorConnectedDao.vote(proposalIndex, true);
                await expect(inspectorConnectedDao.vote(proposalIndex, true)).to.be.revertedWithCustomError(inspectorConnectedDao, "OperationCenter__YouHaveAlreadyVoted()");
            })
        }),
        describe("executeProposal()", () => {
            beforeEach(async () => {
                description = "abc";
                protocolId = 6;
                proposalIndex = 0;
                await dao.addMemberOfDao(inspector.address);
                await producerConnectedProducerContract.requestProtocolWithDao(protocolId);
                await inspectorConnectedDao.createProposal(description, protocolId, producer);
                await inspectorConnectedDao.vote(proposalIndex, true);
                proposal = await inspectorConnectedDao.proposals(proposalIndex);
                await harvestToken.transfer(dao.target, 100000);
            })
            it("only member of dao can execute the proposal", async () => {
                const secondInspector = accounts[3];
                const secondInspectorConnectedAuth = auth.connect(secondInspector);
                secondInspectorConnectedAuth.register("secondInspector", "secondInspector@hotmail.com", 1);
                const secondInspectorConnectedDao = dao.connect(secondInspector);
                await expect(secondInspectorConnectedDao.executeProposal(proposalIndex, CREDIT_AMOUNT)).to.be.revertedWithCustomError(secondInspectorConnectedDao, "OperationCenter__YouAreNotMemberOfDao()");
            }),
            it("revert if proposal does not exist", async () => {
                await expect(inspectorConnectedDao.executeProposal(proposalIndex + 500, CREDIT_AMOUNT)).to.be.revertedWithCustomError(inspectorConnectedDao, "OperationCenter__ProposalDoesNotExist()");
            }),
            it("revert if deadline has not exceeded", async () => {
                await expect(inspectorConnectedDao.executeProposal(proposalIndex, CREDIT_AMOUNT)).to.be.revertedWithCustomError(inspectorConnectedDao, "OperationCenter__DeadlineHasNotExceeded()");               
            }),
            it("set requestedProtocolsByProducers after execute the proposal successfully", async () => {
                await network.provider.send("evm_increaseTime", [Number(proposal.deadline) + 1]);
                const beforeExecution = await producerConnectedProducerContract.getRequestedProtocolsByProducersMapping(producer.address, protocolId);
                // const balance = await harvestToken.balanceOf(dao.target);
                // console.log(balance);
                // console.log(dao.target);
                // console.log(deployer.address);
                // console.log(dao.target);
                // console.log(harvestToken.target);
                await inspectorConnectedDao.executeProposal(proposalIndex, CREDIT_AMOUNT);
                const afterExecution = await producerConnectedProducerContract.getRequestedProtocolsByProducersMapping(producer.address, protocolId);
                assert.equal(beforeExecution, true);
                assert.equal(afterExecution, false);
            }),
            it("check 'executed' and 'passedVoting parameters after execution' ", async () => {
                await network.provider.send("evm_increaseTime", [Number(proposal.deadline) + 1]);
                await inspectorConnectedDao.executeProposal(proposalIndex, CREDIT_AMOUNT);
                const proposalAfterExecution = await inspectorConnectedDao.proposals(proposalIndex);
                assert.equal(proposalAfterExecution.executed, true);
                assert.equal(proposalAfterExecution.passedVoting, true);
            }),
            it("revert if proposal already executed", async () => {
                await network.provider.send("evm_increaseTime", [Number(proposal.deadline) + 1]);
                await inspectorConnectedDao.executeProposal(proposalIndex, CREDIT_AMOUNT);
                await expect(inspectorConnectedDao.executeProposal(proposalIndex, CREDIT_AMOUNT)).to.be.revertedWithCustomError(inspectorConnectedDao, "OperationCenter__ProposalAlreadyExecuted()");
            }),
            // test the creditHarvestToken() function implementations
            describe("creditHarvestToken() function", () => {

            }),
            it("revert if againstVotes > forVotes", async () => {
                const startingIndex = 3; // deployer: 0 - inspector: 1 - producer: 2
                const additionalEntrants = 2; // we need 2 against vote
                for(let i = startingIndex; i < startingIndex + additionalEntrants; i++){
                    const againstInspector = accounts[i];
                    const againstInspectorConnectedAuth = auth.connect(againstInspector);
                    againstInspectorConnectedAuth.register("againstInspector", "againstInspector@hotmail.com", 1);
                    const againstInspectorConnectedDao = dao.connect(againstInspector);
                    await dao.addMemberOfDao(againstInspector.address);
                    await againstInspectorConnectedDao.vote(proposalIndex, false);
                }
                await network.provider.send("evm_increaseTime", [Number(proposal.deadline) + 1]);
                await expect(inspectorConnectedDao.executeProposal(proposalIndex, CREDIT_AMOUNT)).to.be.revertedWithCustomError(inspectorConnectedDao, "OperationCenter__ProposalDidntPass()");
            }),
            it("emits the event", async () => {
                await network.provider.send("evm_increaseTime", [Number(proposal.deadline) + 1]);
                await expect(inspectorConnectedDao.executeProposal(proposalIndex, CREDIT_AMOUNT)).to.emit(inspectorConnectedDao, "ProposalExecuted").withArgs(proposalIndex);
            })
        })
    })
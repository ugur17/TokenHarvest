const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("InspectorContract Contract Unit Tests", function () {
        let deployer, accounts, inspectorContract;
        beforeEach(async () => {
            accounts = await ethers.getSigners();
            deployer = accounts[0];
            await deployments.fixture(["inspectorContract", "operationCenter", "producerContract", "nftHarvest", "harvestToken", "auth"]);
            inspectorContract = await ethers.getContract("InspectorContract", deployer);
        }),
        describe("acceptCertificationRequest()", () => {
            it("revert if the caller is not inspector", async () => {

            })
        })
    })
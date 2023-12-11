const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("GoodExchange Contract Unit Tests", function () {
        let deployer, accounts, goodExchange;
        beforeEach(async () => {
            accounts = await ethers.getSigners();
            deployer = accounts[0];
            await deployments.fixture(["goodExchange"]);
            goodExchange = await ethers.getContract("GoodExchange", deployer);
        }),
        describe("listProductForSale Function", () => {
        })
    })
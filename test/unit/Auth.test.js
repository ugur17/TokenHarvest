const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Auth Contract Unit Tests", function () {
        let deployer, accounts, authContract;
        beforeEach(async () => {
            accounts = await ethers.getSigners();
            deployer = accounts[0];
            await deployments.fixture(["auth"]);
            authContract = await ethers.getContract("Auth", deployer);
        }),
        describe("Register Function", () => {
            it("stores the infos of users correctly", async () => {
                await authContract.register("jieun", "jieun@hotmail.com", 0);
                const user = await authContract.users(deployer);
                assert((user.username == "jieun") && (user.email == "jieun@hotmail.com") && (user.registered == true) && (user.role == 0));
            }),
            it("checks error if the user already registered", async () => {
                await authContract.register("jieun", "jieun@hotmail.com", 0);
                await expect(authContract.register("jieun2", "jieun2@hotmail.com", 0)).to.be.revertedWithCustomError(authContract, "Auth__AlreadyRegistered()");
            }),
            it("checks the validity of input parameters", async () => {
                await expect(authContract.register("", "jieun@hotmail.com", 0)).to.be.revertedWithCustomError(authContract, "Auth__InvalidNameOrEmail()");
                await expect(authContract.register("jieun", "", 0)).to.be.revertedWithCustomError(authContract, "Auth__InvalidNameOrEmail()");
            }),
            it("emits the registered event", async () => {
                await expect(authContract.register("jieun", "jieun@hotmail.com", 0)).to.emit(authContract, "UserRegistered").withArgs(deployer.address, "jieun", "jieun@hotmail.com", 0);
            })
        })
    })
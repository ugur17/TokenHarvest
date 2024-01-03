const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("NFTHarvest Contract Unit Tests", function () {
        let deployer, accounts, nftHarvest, auth;
        beforeEach(async () => {
            accounts = await ethers.getSigners();
            deployer = accounts[0];
            await deployments.fixture(["nftHarvest", "auth"]);
            nftHarvest = await ethers.getContract("NFTHarvest", deployer);
            auth = await ethers.getContract("Auth", deployer);
        }),
        describe("Constructor", () => {
            it("initilize variables correctly", async () => {
                const nftCounter = await nftHarvest.getNftCounter();
                assert(nftCounter == 0); 
            })
        }),
        describe("MintNFT", () => {
            it("only producer role can mint nft", async () => {
                await auth.register("jieun", "jieun@hotmail.com", 1);
                await expect(nftHarvest.mintNFT(10, "cucumber", 5)).to.be.revertedWithCustomError(nftHarvest, "NFTHarvest__InsufficientRole()");
            }),
            it("only accepts valid parameters", async () => {
                await auth.register("jieun", "jieun@hotmail.com", 0);
                await expect(nftHarvest.mintNFT(10, "", 5)).to.be.revertedWithCustomError(nftHarvest, "NFTHarvest__InvalidParameters()");
                await expect(nftHarvest.mintNFT(0, "cucumber", 5)).to.be.revertedWithCustomError(nftHarvest, "NFTHarvest__InvalidParameters()");
                await expect(nftHarvest.mintNFT(10, "cucumber", 0)).to.be.revertedWithCustomError(nftHarvest, "NFTHarvest__InvalidParameters()");
            }),
            it("will increment the nft counter", async () => {
                const prevNftCounter = await nftHarvest.getNftCounter();
                await auth.register("jieun", "jieun@hotmail.com", 0);
                await nftHarvest.mintNFT(10, "cucumber", 5);
                const currentNftCounter = await nftHarvest.getNftCounter();
                assert.equal(Number(prevNftCounter) + 1, Number(currentNftCounter));
            }),
            it("will mint nft to the balance of msg.sender", async () => {
                const nextId = await nftHarvest.getNftCounter();
                await auth.register("jieun", "jieun@hotmail.com", 0);
                await nftHarvest.mintNFT(10, "cucumber", 5);
                const balance = await nftHarvest.balanceOf(deployer.address, nextId);
                assert.equal(Number(balance), 10);
            }),
            it("sets the metadata of nft", async () => {
                const nextId = await nftHarvest.getNftCounter();
                await auth.register("jieun", "jieun@hotmail.com", 0);
                await nftHarvest.mintNFT(10, "cucumber", 5);
                const metadata = await nftHarvest.getNftMetadata(nextId);
                assert((metadata.name == "cucumber") && (Number(metadata.productAmountOfEachToken) == 5) && (metadata.isCertified == false));
            }),
            it("emits the event", async () => {
                const nextId = await nftHarvest.getNftCounter();
                await auth.register("jieun", "jieun@hotmail.com", 0);
                await expect(nftHarvest.mintNFT(10, "cucumber", 5)).to.emit(nftHarvest, "CreatedNFT").withArgs(deployer.address, nextId, 10, "cucumber", 5);
            })
        }),
        describe("burnNFT", () => {
            it("only producer role can burn nft", async () => {
                await auth.register("jieun", "jieun@hotmail.com", 1);
                // does not matter the id of product, function firstly will check the role of msg.sender
                const anyId = 2; 
                await expect(nftHarvest.burnNFT(anyId, 10)).to.be.revertedWithCustomError(nftHarvest, "NFTHarvest__InsufficientRole()");
            }),
            it("checks if the user has enough nft to burn", async () => {
                const nextId = await nftHarvest.getNftCounter();
                await auth.register("jieun", "jieun@hotmail.com", 0);
                await nftHarvest.mintNFT(10, "cucumber", 5);
                await expect(nftHarvest.burnNFT(nextId, 11)).to.be.revertedWithCustomError(nftHarvest, "NFTHarvest__NotEnoughToken()");
            }),
            it("burns nft from the balance of msg.sender", async () => {
                const nextId = await nftHarvest.getNftCounter();
                await auth.register("jieun", "jieun@hotmail.com", 0);
                await nftHarvest.mintNFT(10, "cucumber", 5);
                await nftHarvest.burnNFT(nextId, 5);
                const prevBalance = await nftHarvest.balanceOf(deployer.address, nextId);
                await nftHarvest.burnNFT(nextId, 5);
                const currentBalance = await nftHarvest.balanceOf(deployer.address, nextId);
                assert((Number(prevBalance) == 5) && (Number(currentBalance) == 0));
            })
        })
    })
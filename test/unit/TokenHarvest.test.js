const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("TokenHarvest Contract Unit Tests", function () {
        let deployer, accounts, tokenHarvest;
        beforeEach(async () => {
            accounts = await ethers.getSigners();
            deployer = accounts[0];
            await deployments.fixture(["tokenHarvest"]);
            tokenHarvest = await ethers.getContract("TokenHarvest", deployer);
        }),
        describe("Constructor", () => {
            it("initilize variables correctly", async () => {
                const nftCounter = await tokenHarvest.getNftCounter();
                const currentHrvSupply = await tokenHarvest.getCurrentHrvSupply();
                assert((nftCounter == 1) && (currentHrvSupply == 0)); 
            })
        }),
        describe("MintNFT", () => {
            it("only producer role can mint nft", async () => {
                await tokenHarvest.register("jieun", "jieun@hotmail.com", 1);
                await expect(tokenHarvest.mintNFT(10, "cucumber", 5)).to.be.revertedWithCustomError(tokenHarvest, "Auth__InsufficientRole()");
            }),
            it("only accepts valid parameters", async () => {
                await tokenHarvest.register("jieun", "jieun@hotmail.com", 0);
                await expect(tokenHarvest.mintNFT(10, "", 5)).to.be.revertedWithCustomError(tokenHarvest, "TokenHarvest__InvalidParameters()");
                await expect(tokenHarvest.mintNFT(0, "cucumber", 5)).to.be.revertedWithCustomError(tokenHarvest, "TokenHarvest__InvalidParameters()");
                await expect(tokenHarvest.mintNFT(10, "cucumber", 0)).to.be.revertedWithCustomError(tokenHarvest, "TokenHarvest__InvalidParameters()");
            }),
            it("will increment the nft counter", async () => {
                const prevNftCounter = await tokenHarvest.getNftCounter();
                await tokenHarvest.register("jieun", "jieun@hotmail.com", 0);
                await tokenHarvest.mintNFT(10, "cucumber", 5);
                const currentNftCounter = await tokenHarvest.getNftCounter();
                assert.equal(Number(prevNftCounter) + 1, Number(currentNftCounter));
            }),
            it("will mint nft to the balance of msg.sender", async () => {
                const nextId = await tokenHarvest.getNftCounter();
                await tokenHarvest.register("jieun", "jieun@hotmail.com", 0);
                await tokenHarvest.mintNFT(10, "cucumber", 5);
                const balance = await tokenHarvest.balanceOf(deployer.address, nextId);
                assert.equal(Number(balance), 10);
            }),
            it("sets the metadata of nft", async () => {
                const nextId = await tokenHarvest.getNftCounter();
                await tokenHarvest.register("jieun", "jieun@hotmail.com", 0);
                await tokenHarvest.mintNFT(10, "cucumber", 5);
                const metadata = await tokenHarvest.getNftMetadata(nextId);
                assert((metadata.name == "cucumber") && (Number(metadata.productAmountOfEachToken) == 5) && (metadata.isCertified == false));
            }),
            it("emits the event", async () => {
                const nextId = await tokenHarvest.getNftCounter();
                await tokenHarvest.register("jieun", "jieun@hotmail.com", 0);
                await expect(tokenHarvest.mintNFT(10, "cucumber", 5)).to.emit(tokenHarvest, "CreatedNFT").withArgs(deployer.address, nextId, 10, "cucumber", 5);
            })
        }),
        describe("mintHrv", () => {}),
        describe("burnNFT", () => {
            it("can work only for nfts", async () => {
                // does not matter the value of amount parameter in the burnNFT function, firstly the token will be checked if it's nft or not
                const anyAmount = 5; 
                await expect(tokenHarvest.burnNFT(0, anyAmount)).to.be.revertedWithCustomError(tokenHarvest, "TokenHarvest__ThisTokenIsNotNft()");
            }),
            it("only producer role can burn nft", async () => {
                await tokenHarvest.register("jieun", "jieun@hotmail.com", 1);
                // does not matter the id of product, function will check the role of msg.sender after checked if it's nft or not
                const anyId = 2; 
                await expect(tokenHarvest.burnNFT(anyId, 10)).to.be.revertedWithCustomError(tokenHarvest, "Auth__InsufficientRole()");
            }),
            it("checks if the user has enough nft to burn", async () => {
                const nextId = await tokenHarvest.getNftCounter();
                await tokenHarvest.register("jieun", "jieun@hotmail.com", 0);
                await tokenHarvest.mintNFT(10, "cucumber", 5);
                await expect(tokenHarvest.burnNFT(nextId, 11)).to.be.revertedWithCustomError(tokenHarvest, "TokenHarvest__NotEnoughToken()");
            }),
            it("burns nft from the balance of msg.sender", async () => {
                const nextId = await tokenHarvest.getNftCounter();
                await tokenHarvest.register("jieun", "jieun@hotmail.com", 0);
                await tokenHarvest.mintNFT(10, "cucumber", 5);
                await tokenHarvest.burnNFT(nextId, 5);
                const prevBalance = await tokenHarvest.balanceOf(deployer.address, nextId);
                await tokenHarvest.burnNFT(nextId, 5);
                const currentBalance = await tokenHarvest.balanceOf(deployer.address, nextId);
                assert((Number(prevBalance) == 5) && (Number(currentBalance) == 0));
            })
        })
    })
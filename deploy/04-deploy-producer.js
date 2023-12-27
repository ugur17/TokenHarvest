const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify.js");

module.exports = async function ({getNamedAccounts, deployments}) {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();

    args = [];

    const nftHarvest = await deployments.get('NFTHarvest');
    const harvestTokenContract = await deployments.get("HarvestToken");
    args.push(nftHarvest.address);
    args.push(harvestTokenContract.address);

    const producerContract = await deploy("ProducerContract", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1
    })

    if(!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...");
        await verify(producerContract.address, args);
    }
    log("------------------------------------");
}

module.exports.tags = ["all", "producerContract"];
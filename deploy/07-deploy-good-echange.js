const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify.js");

module.exports = async function ({getNamedAccounts, deployments}) {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();

    args = [];

    const nftHarvest = await deployments.get('NFTHarvest');
    const harvestToken = await deployments.get('HarvestToken');
    const operationCenter = await deployments.get('OperationCenter');
    args.push(nftHarvest.address);
    args.push(harvestToken.address);
    args.push(operationCenter.address);

    const goodExchange = await deploy("GoodExchange", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1
    })

    if(!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...");
        await verify(goodExchange.address, args);
    }
    log("------------------------------------");
}

module.exports.tags = ["all", "goodExchange"];
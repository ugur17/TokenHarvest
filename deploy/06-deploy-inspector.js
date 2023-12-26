const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify.js");

module.exports = async function ({getNamedAccounts, deployments}) {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();

    args = [];

    const operationCenter = await deployments.get('OperationCenter');
    const nftHarvest = await deployments.get('NFTHarvest');
    args.push(operationCenter.address);
    args.push(nftHarvest.address);

    const inspectorContract = await deploy("InspectorContract", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1
    })

    if(!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...");
        await verify(inspectorContract.address, args);
    }
    log("------------------------------------");
}

module.exports.tags = ["all", "inspectorContract"];
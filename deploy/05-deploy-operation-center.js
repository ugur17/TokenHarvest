const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify.js");

module.exports = async function ({getNamedAccounts, deployments}) {
    const {deploy, log} = deployments;
    const {deployer} = await getNamedAccounts();

    args = [];

    const producerContract = await deployments.get('ProducerContract');
    args.push(producerContract.address);

    const operationCenter = await deploy("OperationCenter", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1
    })

    if(!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...");
        await verify(operationCenter.address, args);
    }
    log("------------------------------------");
}

module.exports.tags = ["all", "operationCenter"];
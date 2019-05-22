'use strict';

/*global artifacts*/
const BridgeFactory = artifacts.require('BridgeFactory');

module.exports = (deployer) => {
    if (!process.env.NEW_BRIDGE) {
        return;
    }
    
    return deployer.then(async () => {
        if (!process.env.ACCOUNT) {
            throw new Error('Provide \'ACCOUNT\' option via environment, ' +
                'e.g. ACCOUNT=0x2f39...');
        }

        if (!process.env.BRIDGE_FACTORY) {
            throw new Error('Provide \'BRIDGE_FACTORY\' option via environment, ' +
                'like BRIDGE_FACTORY=0x4579...');
        }

        if (!process.env.VALIDATORS) {
            throw new Error('Provide \'VALIDATORS\' option via environment, ' +
                'like VALIDATORS=0x4579...,0x2f39...(comma seperated addresses)');
        }

        if (!process.env.ETH_CAPACITY) {
            throw new Error('Provide \'ETH_CAPACITY\' parameter via environment, ' +
                'like ETH_CAPACITY=1000 (in wei)');
        }

        if (!process.env.ETH_MIN_EXCHANGE) {
            throw new Error('Provide \'ETH_MIN_EXCHANGE\' parameter via environment, ' +
                'like ETH_MIN_EXCHANGE=1000000000000000000000 (in wei)');
        }

        if (!process.env.ETH_FEE_PERCENTAGE) {
            throw new Error('Provide \'ETH_FEE_PERCENTAGE\' parameter via environment, ' +
                'like  ETH_FEE_PERCENTAGE=10 (maximum 10000)');
        }

        const account           = process.env.ACCOUNT;
        const validators        = process.env.VALIDATORS.split(',');
        const ethCapacity       = process.env.ETH_CAPACITY;
        const ethMinExchange    = process.env.ETH_MIN_EXCHANGE;
        const ethFeePercentage  = process.env.ETH_FEE_PERCENTAGE;

        const bridgeFactory = await BridgeFactory.at(process.env.BRIDGE_FACTORY);

        console.log('\tCreating new Bridge contract...');

        console.log('\t1. Creating BankStorage contract');

        let tx = await bridgeFactory.createBankStorage(
            {
                from:     account,
                gas:      process.env.GAS_LIMIT,
                gasPrice: process.env.GAS_PRICE
            }
        );

        const index = tx.logs[1].args[1];

        console.log('\t2. Creating Bridge contract');
        await bridgeFactory.createBridge(
            ethCapacity,
            ethMinExchange,
            ethFeePercentage,
            index,
            {
                from:     account,
                gas:      process.env.GAS_LIMIT,
                gasPrice: process.env.GAS_PRICE
            }
        );

        console.log('\t3. Creating PoAGovernment contract');
        await bridgeFactory.createPoA(
            index,
            {
                from:     account,
                gas:      process.env.GAS_LIMIT,
                gasPrice: process.env.GAS_PRICE
            }
        );

        console.log('\t4. Connect contracts...');
        tx = await bridgeFactory.build(validators, index,
            {
                from:     account,
                gas:      process.env.GAS_LIMIT,
                gasPrice: process.env.GAS_PRICE
            }
        );

        const bridgeAddress = tx.logs[0].args[0];

        console.log(`\tDone. Bridge address: ${bridgeAddress}`);
    });
};

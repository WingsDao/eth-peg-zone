'use strict';

/*global artifacts*/
const BridgeFactory   = artifacts.require('BridgeFactory');
const cosmos          = require('cosmos-lib');
const {getHDProvider} = require('../provider');

const MNEMONIC = process.env.MNEMONIC;
const ROPSTEN  = 'ropsten';

module.exports = (deployer) => {
    if (process.env.CONTRACT != 'NewBridge') {
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

        if (!process.env.ETH_ADDRESSES) {
            throw new Error('Provide \'ETH_ADDRESSES\' option via environment, ' +
                'like ETH_ADDRESSES=0x4579...,0x2f39...(comma seperated addresses)');
        }

        if (!process.env.WB_ADDRESSES) {
            throw new Error('Provide \'WB_ADDRESSES\' option via environment, ' +
                'like WB_ADDRESSES=wallets1avmaz...,' +
                'wallets1ghaamx..., (comma seperated addresses)');
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

        if (deployer.network === ROPSTEN) {
          BridgeFactory.setProvider(getHDProvider());
        }

        const account          = process.env.ACCOUNT;
        const ethAddresses     = process.env.ETH_ADDRESSES.split(',');
        let   wbAddresses      = process.env.WB_ADDRESSES.split(',');
        const ethCapacity      = process.env.ETH_CAPACITY;
        const ethMinExchange   = process.env.ETH_MIN_EXCHANGE;
        const ethFeePercentage = process.env.ETH_FEE_PERCENTAGE;

        if (ethAddresses.length != wbAddresses.length) {
            throw new Error('Eth addresses amount should be ' +
                'equal WB addresses amount');
        }

        const bridgeFactory = await BridgeFactory.at(process.env.BRIDGE_FACTORY);

        console.log('\tCreating new Bridge contract...\n');

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

        wbAddresses = wbAddresses.map(a => cosmos.address.getBytes32(a));

        console.log('\t4. Connecting contracts...');
        tx = await bridgeFactory.build(
            ethAddresses,
            wbAddresses,
            index,
            {
                from:     account,
                gas:      process.env.GAS_LIMIT,
                gasPrice: process.env.GAS_PRICE
            }
        );

        const bridgeAddress = tx.logs[0].args[0];
        const args = await bridgeFactory.getInstance(account, index);

        console.log('\tDone.\n');
        console.log(`\tBridge address:      ${bridgeAddress}`);
        console.log(`\tBankStorage address: ${args[1]}`);
        console.log(`\tPoA address:         ${args[2]}`);
    });
};

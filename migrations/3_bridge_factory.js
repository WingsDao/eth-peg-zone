'use strict';

/*global artifacts*/
const BridgeFactory = artifacts.require('BridgeFactory');

module.exports = (deployer) => {
    if (process.env.CONTRACT != 'Bridge') {
        return;
    }

    return deployer.then(async () => {
        if (!process.env.ACCOUNT) {
            throw new Error('Provide \'ACCOUNT\' option via environment, ' +
                'e.g. ACCOUNT=0x2f39...');
        }

        if (!process.env.BANK_STORAGE_FACTORY) {
            throw new Error('Provide \'BANK_STORAGE_FACTORY\' option via environment, ' +
                'e.g. BANK_STORAGE_FACTORY=0x4579...');
        }

        if (!process.env.POA_FACTORY) {
            throw new Error('Provide \'POA_FACTORY\' option via environment, ' +
                'e.g. POA_FACTORY=0xc6C11...');
        }

        const account        = process.env.ACCOUNT;
        const storageFactory = process.env.BANK_STORAGE_FACTORY;
        const poaFactory     = process.env.POA_FACTORY;

        await deployer.deploy(
            BridgeFactory,
            storageFactory,
            poaFactory,
            {
                from:     account,
                gasLimit: process.env.GAS_LIMIT,
                gasPrice: process.env.GAS_PRICE
            }
        );
    });
};

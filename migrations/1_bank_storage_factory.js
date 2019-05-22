'use strict';

/*global artifacts*/
const BankStorageFactory = artifacts.require('BankStorageFactory')

module.exports = (deployer) => {
    if (!process.env.CONTRACT != "BankStorage") {
        return;
    }

    return deployer.then(async () => {
        if (!process.env.ACCOUNT) {
            throw new Error('Provide \'ACCOUNT\' option via environment, ' +
                'e.g. ACCOUNT=0x2f39...');
        }

        const account = process.env.ACCOUNT;

        await deployer.deploy(
            BankStorageFactory,
            {
                from:     account,
                gasLimit: process.env.GAS_LIMIT,
                gasPrice: process.env.GAS_PRICE
            }
        );
    });
};

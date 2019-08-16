/**
 * Helper to work with accounts.
 */
'use strict';

/*global web3*/

const bip39  = require('bip39');
const cosmos = require('cosmos-lib');

exports.getValidators = async function getValidators(amount=12) {
    const validators = (await web3.eth.getAccounts()).slice(0, amount);

    const cosmosAddresses = validators.map(() => {
        const mnemonic = bip39.generateMnemonic();
        const keys     = cosmos.crypto.getKeysFromMnemonic(mnemonic);
        const address  = cosmos.address.getAddress(keys.publicKey);

        return `0x${cosmos.address.getBytes32(address).toString('hex')}`;
    });

    return {validators, cosmosAddresses};
};

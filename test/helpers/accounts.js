/**
 * Helper to work with accounts.
 */
'use strict';

/*global web3*/

const bip39  = require('bip39');
const cosmos = require('cosmos-lib');
const prefix = process.env.WB_PREFIX || 'wallets';

exports.DESTINATION = {
    SELF:   '0',
    TARGET: '1'
};

exports.ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

exports.getValidators = async function getValidators(amount=12) {
    const validators = (await web3.eth.getAccounts()).slice(0, amount);

    const wbAddresses = validators.map(() => {
        const mnemonic = bip39.generateMnemonic();
        const keys     = cosmos.crypto.getKeysFromMnemonic(mnemonic);
        const address  = cosmos.address.getAddress(keys.publicKey, prefix);

        return `0x${cosmos.address.getBytes32(address).toString('hex')}`;
    });

    return {validators, wbAddresses};
};

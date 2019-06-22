/**
 * Helpers to work with Cosmos types
 *
 * @module helpers/cosmos
 */
'use strict';

const bech32 = require('bech32');

/**
 * Convert cosmos address to Buffer
 *
 * @param  {String} address Cosmos address
 * @return {Buffer}         Buffer representation of address
 */
exports.AddressToBytes = function AddressToBytes(address) {
    let decoded = bech32.decode(address);

    return Buffer.from(decoded.words);
};

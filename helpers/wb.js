/**
 * Helpers to work with Cosmos/WB types
 *
 * @module helpers/wb
 */
'use strict';

const bech32 = require('bech32');

/**
 * Convert bech32 address to Buffer
 *
 * @param  {String} address Cosmos/WB address
 * @return {Buffer}         Buffer representation of address
 */
exports.AddressToBytes = function AddressToBytes(address) {
    let decoded = bech32.decode(address);

    return Buffer.from(decoded.words);
};

/**
 * Lib to help to work with contracts abi.
 *
 * @module test/helpers/abi/lib
 */
'use strict';

/*global web3*/

/**
 * Get method ABI from ABI interface.
 *
 * @param  {Object} abiInterface JSON ABI interface of contract.
 * @param  {String} name         ABI item name.
 * @param  {String} type         Type, usually 'function'.
 * @return {Buffer}              Function call signature.
 */
exports.getAbiMethod = function getAbiMethod(abiInterface, name, type='function') {
    return abiInterface.abi.find(el => el.name == name && el.type == type);
};

/**
 * Get tx data hash (mostly for PoA method confirm call).
 *
 * @param  {String} address Address of contract to execute function.
 * @param  {String} data    Data to execute function.
 * @return {Buffer}         Hash.
 */
exports.getDataHash = function txHash(address, data) {
    return web3.utils.soliditySha3({t: 'address', v: address}, {t: 'bytes', v: data});
};

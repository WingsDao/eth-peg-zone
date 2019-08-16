/**
 * Helper to generate abi signatures on functions calls of Bridge contract.
 *
 * @module test/helpers/abi/bridge
 */
'use strict';

/*global web3,artifacts*/

const BridgeInterface             = artifacts.require('Bridge');
const {getAbiMethod} = require('./lib');

exports.withdraw = function withdraw(currencyId, recipient, amount, gas) {
    return web3.eth.abi.encodeFunctionCall(
        getAbiMethod(BridgeInterface, 'withdraw'),
        [currencyId, recipient, amount, gas]
    );
};

exports.pause = function pause() {
    return web3.eth.abi.encodeFunctionCall(getAbiMethod(BridgeInterface, 'pause'), []);
};

exports.resume = function resume() {
    return web3.eth.abi.encodeFunctionCall(getAbiMethod(BridgeInterface, 'resume'), []);
};

exports.changeCapacity = function changeCapacity(currencyId, capacity) {
    return web3.eth.abi.encodeFunctionCall(
        getAbiMethod(BridgeInterface, 'changeCapacity'),
        [currencyId, capacity]
    );
};

exports.changeMinExchange = function changeMinExchange(currencyId, minExchange) {
    return web3.eth.abi.encodeFunctionCall(
        getAbiMethod(BridgeInterface, 'changeMinExchange'),
        [currencyId, minExchange]
    );
};

exports.changeFee = function changeFee(currencyId, newFeePercentage) {
    return web3.eth.abi.encodeFunctionCall(
        getAbiMethod(BridgeInterface, 'changeFee'),
        [currencyId, newFeePercentage]
    );
};

exports.addCurrency = function addCurrency(tokenContract, symbol, decimals, capacity, minExchange, feePercent) {
    return web3.eth.abi.encodeFunctionCall(
        getAbiMethod(BridgeInterface, 'addCurrency'),
        [tokenContract, symbol, decimals, capacity, minExchange, feePercent]
    );
};

exports.migration = function migration(address) {
    return web3.eth.abi.encodeFunctionCall(
        getAbiMethod(BridgeInterface, 'migration'),
        [address]
    );
};

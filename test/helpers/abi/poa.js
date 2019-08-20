'use strict';

/*global web3,artifacts*/
const PoAInterface   = artifacts.require('PoAGovernment');
const {getAbiMethod} = require('./lib');

exports.addValidator = function addValidator(ethAddress, cosmosAddress) {
    return web3.eth.abi.encodeFunctionCall(
        getAbiMethod(PoAInterface, 'addValidator'),
        [ethAddress, cosmosAddress]
    );
};

exports.replaceValidator = function replaceValidator(
    oldEthAddress,
    newEthAddress,
    cosmosAddress
) {
    return web3.eth.abi.encodeFunctionCall(
        getAbiMethod(PoAInterface, 'replaceValidator'),
        [oldEthAddress, newEthAddress, cosmosAddress]
    );
};

exports.removeValidator = function removeValidator(ethAddress) {
    return web3.eth.abi.encodeFunctionCall(
        getAbiMethod(PoAInterface, 'removeValidator'),
        [ethAddress]
    );
};

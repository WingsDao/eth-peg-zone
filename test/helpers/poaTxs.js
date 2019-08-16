/**
 * Helper to work with PoA (multisignature) transactions.
 *
 * @module test/helpers/poaTxs
 */
'use strict';

const abi = require('./abi');

let poa;

exports.setPoA = function setPoA(poaContract) {
    poa = poaContract;
};

exports.sendAndConfirm = async function sendAndConfirm(target, data, options, validators) {
    const txId = await sendTransaction(target, data, options);

    let address;
    if (target != '0') {
        address = await poa.methods.target().call();
    } else {
        address = poa.options.address;
    }

    const hash = abi.lib.getDataHash(address, data);

    return confirmTransaction(poa, validators, txId, hash);
};

async function sendTransaction(target, data, options) {
    const receipt = await poa.methods.submitTransaction(
        target,
        data
    ).send(options);

    return receipt.events.TX_SUBMISSED.returnValues._transactionId;
}

async function confirmTransaction(poa, validators, txId, hash) {
    for (let i = 1; i < validators.length; i++) {
        const isConfirmed = await poa.methods.isConfirmed(txId).call();

        if (isConfirmed) {
            break;
        }

        await poa.methods.confirmTransaction(txId, hash).send({
            from: validators[i],
            gas:  6000000
        });
    }

    const {executed} = await poa.methods.transactions(txId).call();
    return executed;
}

exports.sendTransaction    = sendTransaction;
exports.confirmTransaction = confirmTransaction;

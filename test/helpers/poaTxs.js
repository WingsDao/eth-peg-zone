/**
 * Helper to work with PoA (multisignature) transactions.
 *
 * @module test/helpers/poaTxs
 */
'use strict';

const abi = require('./abi');

exports.confirmTransaction = async function confirmTransaction(poa, validators, txId, hash) {
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
};

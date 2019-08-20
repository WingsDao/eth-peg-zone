/**
 * PoA contract tests.
 * Mostly tests validators logic, as other functional tested in Bridge test.
 *
 * @module contracts/PoAGovernment
 */
'use strict';

/*global web3,artifacts*/
require('chai').should();

const PoAInterface    = artifacts.require('PoAGovernment');
const BSInterface     = artifacts.require('BankStorage');
const {getValidators, ZERO_ADDRESS, DESTINATION} = require('./helpers/accounts');

const abi = require('./helpers/abi');
const poaTxs = require('./helpers/poaTxs');

function getRequired(amount) {
    return web3.utils.toBN(amount).divn(2).addn(1).toString();
}

describe('PoA', () => {
    let owner, validators, otherValidators, cosmosAddresses;
    let bs, poa;

    before(async () => {
        const accounts = await getValidators();

        owner      = accounts.validators.shift();
        validators = accounts.validators.slice(0, 3);
        otherValidators  = accounts.validators.slice(3);
        cosmosAddresses  = accounts.cosmosAddresses.slice(1);

        const BS = new web3.eth.Contract(BSInterface.abi, null, {
            data: BSInterface.bytecode
        });

        bs = await BS.deploy({
            arguments: []
        }).send({
            from: owner,
            gas: 6000000
        });

        const PoA = new web3.eth.Contract(PoAInterface.abi, null, {
            data: PoAInterface.bytecode
        });

        poa = await PoA.deploy({
            arguments: [
                owner,
                bs.options.address
            ]
        }).send({
            from: owner,
            gas: 6000000
        });

        poaTxs.setPoA(poa);

        await bs.methods.setup(poa.options.address, ZERO_ADDRESS).send({
            from: owner,
            gas:  120000
        });

        await poa.methods.setup(
            validators,
            cosmosAddresses.splice(0, 3)
        ).send({
            from: owner,
            gas: 6000000
        });
    });

    it('should return correct confirmations', async () => {
        const required = await poa.methods.required().call();
        const expected = getRequired(validators.length);

        required.should.equal(expected);
    });

    it('should reject add existing validator', async () => {
        const data = abi.poa.addValidator(validators[0], cosmosAddresses[0]);

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.SELF, data, {
            from: validators[0],
            gas:  600000
        }, validators.slice(1));

        isExecuted.should.equal(false);
    });

    it('should add new validator', async () => {
        const newValidator  = otherValidators.splice(0, 1).pop();
        const cosmosAddress = cosmosAddresses.splice(0, 1).pop();

        const data = abi.poa.addValidator(newValidator, cosmosAddress);
        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.SELF, data, {
            from: validators[0],
            gas:  600000
        }, validators.slice(1));

        isExecuted.should.equal(true);
        validators.push(newValidator);

        const addedValidator = await poa.methods.validators(validators.length-1).call();

        addedValidator.ethAddress.should.equal(newValidator);
        addedValidator.cosmosAddress.should.equal(cosmosAddress);
    });

    it('should update required', async () => {
        const required = await poa.methods.required().call();
        const expected = getRequired(validators.length);

        required.should.be.equal(expected);
    });

    it('should replace validator', async () => {
        const toReplace     = validators[0];
        const newValidator  = otherValidators.splice(0, 1).pop();
        const cosmosAddress = cosmosAddresses.splice(0, 1).pop();

        const data = abi.poa.replaceValidator(toReplace, newValidator, cosmosAddress);
        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.SELF, data, {
            from: validators[0],
            gas:  600000
        }, validators.slice(1));

        isExecuted.should.equal(true);

        validators[0] = newValidator;

        const replaced = await poa.methods.validators(0).call();
        replaced.ethAddress.should.equal(validators[0]);
        replaced.cosmosAddress.should.equal(cosmosAddress);
    });

    it('should remove validator', async () => {
        const toRemove = validators[0];

        const data       = abi.poa.removeValidator(toRemove);
        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.SELF, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));

        isExecuted.should.equal(true);
        validators.shift();
    });

    it('should update required after removing', async () => {
        const required = await poa.methods.required().call();
        const expected = getRequired(validators.length);

        required.should.be.equal(expected);
    });
});

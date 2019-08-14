/**
 * Deploy and test bridge functional.
 *
 * @module test/bridge
 */
'use strict';

/*global web3,artifacts*/
require('chai').should();

const bip39  = require('bip39');
const cosmos = require('cosmos-lib');

const BSInterface     = artifacts.require('BankStorage');
const BridgeInterface = artifacts.require('Bridge');
const PoAInterface    = artifacts.require('PoAGovernment');

describe('Bridge', () => {
    const ETH_CAPACITY   = web3.utils.toWei('1000', 'ether');
    const ETH_MIN_AMOUNT = web3.utils.toWei('0.01', 'ether');
    const TO_EXCHANGE    = web3.utils.toWei('1',    'ether');
    const TO_WITHDRAW    = web3.utils.toWei('0.5',  'ether');
    const ETH_FEE_PERCENTAGE = '100';

    let owner, validators, recipient;

    let bridge;
    let poa;

    let ethIndex;

    before(async () => {
        validators = (await web3.eth.getAccounts()).slice(0, 12);
        const cosmosAddresses = validators.map(() => {
            const mnemonic = bip39.generateMnemonic();
            const keys     = cosmos.crypto.getKeysFromMnemonic(mnemonic);

            const address = cosmos.address.getAddress(keys.publicKey);
            return '0x' +  cosmos.address.getBytes32(address).toString('hex');
        });

        recipient = cosmosAddresses.shift();
        owner = validators.shift();

        const BS = new web3.eth.Contract(BSInterface.abi, null, {
            data: BSInterface.bytecode
        });

        const bs = await BS.deploy({
            arguments: []
        }).send({
            from: owner,
            gas: 6000000
        });

        const Bridge = new web3.eth.Contract(BridgeInterface.abi, null, {
            data: BridgeInterface.bytecode
        });

        bridge = await Bridge.deploy({
            arguments: [
                ETH_CAPACITY,
                ETH_MIN_AMOUNT,
                ETH_FEE_PERCENTAGE,
                bs.options.address
            ]
        }).send({
            from: owner,
            gas:  6000000
        });

        const PoA = new web3.eth.Contract(PoAInterface.abi, null, {
            data: PoAInterface.bytecode
        });

        poa = await PoA.deploy({
            arguments: [
                bridge.options.address,
                bs.options.address
            ]
        }).send({
            from: owner,
            gas: 6000000
        });

        const ethTokenAddress = await bridge.methods.getEthTokenAddress().call();

        await bs.methods.setup(poa.options.address, ethTokenAddress).send({
            from: owner,
            gas:  200000
        });

        await bs.methods.transferOwnership(bridge.options.address).send({
            from: owner,
            gas:  100000
        });

        await poa.methods.setup(validators, cosmosAddresses).send({
            from: owner,
            gas:  2000000
        });

        await bridge.methods.transferOwnership(poa.options.address).send({
            from: owner,
            gas:  100000
        });

        ethIndex = await bridge.methods.ethIndex().call();
    });

    it('should deposit bridge', async () => {
        await bridge.methods.exchange(
            ethIndex,
            recipient,
            TO_EXCHANGE
        ).send({
            value: TO_EXCHANGE,
            from: owner,
            gas:  1000000
        });
    });

    it('should withdraw from bridge', async () => {
        const balance = await web3.eth.getBalance(owner);

        const target = '1';
        const data = web3.eth.abi.encodeFunctionCall({
            name: 'withdraw',
            type: 'function',
            inputs: [{
                type: 'uint256',
                name: '_currencyId'
            }, {
                type: 'address',
                name: '_recipient'
            }, {
                type: 'uint256',
                name: '_amount'
            }, {
                type: 'uint256',
                name: '_gas'
            }]
        }, [ethIndex, owner, TO_WITHDRAW, '6000000']);

        await poa.methods.submitTransaction(
            target,
            data
        ).send({
            from: validators[0],
            gas:  6000000
        });

        const txId = '0';
        const hash = web3.utils.soliditySha3({t: 'address', v: bridge.options.address}, {t: 'bytes', v: data});
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

        const newBalance = await web3.eth.getBalance(owner);

        const a = web3.utils.toBN(balance).add(web3.utils.toBN(TO_WITHDRAW));

        a.toString().should.be.equal(newBalance);
    });
});

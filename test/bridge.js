/**
 * Deploy and test bridge functional.
 *
 * @module test/bridge
 */
'use strict';

/*global web3,artifacts,assert*/
require('chai').should();

const BSInterface     = artifacts.require('BankStorage');
const BridgeInterface = artifacts.require('Bridge');
const PoAInterface    = artifacts.require('PoAGovernment');
const ERC20Interface  = require('openzeppelin-solidity/build/contracts/ERC20Mintable');

const abi = require('./helpers/abi');
const {getValidators, ZERO_ADDRESS, DESTINATION} = require('./helpers/accounts');
const poaTxs = require('./helpers/poaTxs');

const MAX_FEE = web3.utils.toBN('9999');

function getFee(amount, feePercent) {
    return web3.utils.toBN(amount)
        .mul(web3.utils.toBN(feePercent))
        .div(MAX_FEE.addn(1))
        .toString();
}

describe('Bridge', () => {
    const ETH_CAPACITY   = web3.utils.toWei('2', 'ether');
    const ETH_MIN_AMOUNT = web3.utils.toWei('0.01', 'ether');
    const TO_EXCHANGE    = web3.utils.toWei('1',    'ether');
    const TO_WITHDRAW    = web3.utils.toWei('0.5',  'ether');
    const TO_EXCHANGE_CAPACITY = web3.utils.toWei('5', 'ether');
    const TO_EXCHANGE_LESS_MIN = '1';
    const ETH_FEE_PERCENTAGE   = '100';
    const ETH_DECIMALS         = '18';

    const ERC_BALANCE  = web3.utils.toWei('100000000', 'ether');
    const ERC_SYMBOL   = 'WINGS';
    const ERC_DECIMALS = '18';
    const ERC_INDEX    = '1';

    let owner, validators, recipient;

    let bridge;
    let poa;
    let erc20;
    let bs;

    let ethIndex;

    before(async () => {
        const accounts = await getValidators();

        recipient = accounts.cosmosAddresses.shift();
        owner     = accounts.validators.shift();
        validators = accounts.validators;

        const ERC20 = new web3.eth.Contract(ERC20Interface.abi, null, {
            data: ERC20Interface.bytecode
        });

        erc20 = await ERC20.deploy().send({
            from: owner,
            gas:  2000000
        });

        await erc20.methods.mint(owner, ERC_BALANCE).send({
            from: owner,
            gas: 120000
        });

        const BS = new web3.eth.Contract(BSInterface.abi, null, {
            data: BSInterface.bytecode
        });

        bs = await BS.deploy({
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

        poaTxs.setPoA(poa);

        const ethTokenAddress = await bridge.methods.getEthTokenAddress().call();

        await bs.methods.setup(poa.options.address, ethTokenAddress).send({
            from: owner,
            gas:  200000
        });

        await bs.methods.transferOwnership(bridge.options.address).send({
            from: owner,
            gas:  100000
        });

        await poa.methods.setup(validators, accounts.cosmosAddresses).send({
            from: owner,
            gas:  2000000
        });

        await bridge.methods.transferOwnership(poa.options.address).send({
            from: owner,
            gas:  100000
        });

        ethIndex = await bridge.methods.ethIndex().call();
    });

    it('should has correct fee for eth', async () => {
        const {feePercentage} = await bridge.methods.currencies(ethIndex).call();
        feePercentage.should.equal(ETH_FEE_PERCENTAGE);
    });

    it('should has correct min exchange', async () => {
        const {minExchange} = await bridge.methods.currencies(ethIndex).call();
        minExchange.should.equal(ETH_MIN_AMOUNT);
    });

    it('should has correct capacity', async () => {
        const {capacity} = await bridge.methods.currencies(ethIndex).call();
        capacity.should.equal(ETH_CAPACITY);
    });

    it('should has correct decimals', async () => {
        const {decimals} = await bridge.methods.currencies(ethIndex).call();
        decimals.should.equal(ETH_DECIMALS);
    });

    it('should pause bridge', async () => {
        const data = abi.bridge.pause();

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  600000
        }, validators.slice(1));

        isExecuted.should.equal(true);

        const isPaused = await bridge.methods.paused().call();
        isPaused.should.equal(true);
    });

    it('should resume bridge', async () => {
        const data = abi.bridge.resume();

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));

        isExecuted.should.equal(true);

        const isPaused = await bridge.methods.paused().call();
        isPaused.should.equal(false);

    });

    it('should deposit bridge', async () => {
        const {feePercentage} = await bridge.methods.currencies(ethIndex).call();
        const exchangeId      = await bridge.methods.exchangeId().call();

        const receipt = await bridge.methods.exchange(
            ethIndex,
            recipient,
            TO_EXCHANGE
        ).send({
            value: TO_EXCHANGE,
            from: owner,
            gas:  1000000
        });

        const realAmount = web3.utils.toBN(TO_EXCHANGE)
            .sub(web3.utils.toBN(getFee(TO_EXCHANGE, feePercentage)))
            .toString();

        receipt.events.should.have.any.keys('CURRENCY_EXCHANGED');

        const values = receipt.events.CURRENCY_EXCHANGED.returnValues;

        values._currencyId.should.equal(ethIndex);
        values._spender.should.equal(owner);
        values._recipient.should.equal(recipient);
        values._id.should.equal(exchangeId);
        values._amount.should.equal(realAmount);

        const brBalance = await web3.eth.getBalance(bridge.options.address);

        brBalance.should.be.equal('0');

        const {balance} = await bridge.methods.currencies(ethIndex).call();
        balance.should.equal(realAmount);
    });

    it('should withdraw from bridge', async () => {
        const balance = await web3.eth.getBalance(owner);
        const data = abi.bridge.withdraw(ethIndex, owner, TO_WITHDRAW, '6000000');

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));

        isExecuted.should.equal(true);

        const newBalance = await web3.eth.getBalance(owner);

        const realBalance = web3.utils.toBN(balance).add(web3.utils.toBN(TO_WITHDRAW));
        realBalance.toString().should.be.equal(newBalance);
    });

    it('should update balance after withdraw', async () => {
        const {feePercentage} = await bridge.methods.currencies(ethIndex).call();

        const realAmount = web3.utils.toBN(TO_EXCHANGE)
            .sub(web3.utils.toBN(getFee(TO_EXCHANGE, feePercentage)))
            .toString();

        const ethBalance  = (await bridge.methods.currencies(ethIndex).call()).balance;
        const diff        = web3.utils.toBN(realAmount).sub(web3.utils.toBN(TO_WITHDRAW)).toString();
        ethBalance.should.equal(diff);
    });

    it('should return correct ETH pseudo token address', async () => {
        const ethTokenAddress = await bridge.methods.getEthTokenAddress().call();

        ethTokenAddress.should.equal(ZERO_ADDRESS);
    });

    it('should return correct fee', async () => {
        const {feePercentage} = await bridge.methods.currencies(ethIndex).call();
        const fee = getFee(TO_EXCHANGE, feePercentage);
        const contractFee = await bridge.methods.getFee(ethIndex, TO_EXCHANGE).call();

        fee.should.equal(contractFee);
    });

    it('should change capacity', async () => {
        const newCapacity = web3.utils.toBN(ETH_CAPACITY).muln(2).toString();

        const data = abi.bridge.changeCapacity(ethIndex, newCapacity);
        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));

        isExecuted.should.equal(true);

        const {capacity} = await bridge.methods.currencies(ethIndex).call();
        capacity.should.be.equal(newCapacity);
    });

    it('should prevent change capacity less then min exchange', async () => {
        const newCapacity = '1'; // 1 wei

        const data = abi.bridge.changeCapacity(ethIndex, newCapacity);
        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET,data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));
        isExecuted.should.equal(false);
    });

    it('should change min exchange', async () => {
        const newMinExchange = '1';
        const data = abi.bridge.changeMinExchange(ethIndex, newMinExchange);

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));

        isExecuted.should.equal(true);

        const {minExchange} = await bridge.methods.currencies(ethIndex).call();
        minExchange.should.equal(newMinExchange);
    });

    it('should prevent change capacity less then balance', async () => {
        const newCapacity = '2';
        const data        = abi.bridge.changeCapacity(ethIndex, newCapacity);

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));
        isExecuted.should.equal(false);
    });

    it('should prevent exchange because of min exchange', async () => {
        const data    = abi.bridge.changeMinExchange(ethIndex, ETH_MIN_AMOUNT);

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));
        isExecuted.should.equal(true);

        return bridge.methods.exchange(
            ethIndex,
            recipient,
            TO_EXCHANGE_LESS_MIN
        ).send({
            value: TO_EXCHANGE_LESS_MIN,
            from: owner,
            gas:  1000000
        }).then(() => {
            throw new Error('Expected reject');
        }).catch(e => e.message.should.contains('Amount should be great or equal then min exchage'));
    });

    it('should prevent exchange because of capacity', async () => {
        return bridge.methods.exchange(
            ethIndex,
            recipient,
            TO_EXCHANGE_CAPACITY
        ).send({
            value: TO_EXCHANGE_CAPACITY,
            from: owner,
            gas:  1000000
        }).then(() => {
            throw new Error('Expected reject');
        }).catch(e => e.message.should.contains('Cant convert ETH/tokens because of capacity'));
    });

    it('should prevent withdraw because of min exchange', async () =>  {
        const data = abi.bridge.withdraw(ethIndex, owner, '1', '6000000');

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));
        isExecuted.should.equal(false);
    });

    it('should change fee', async () => {
        const newFee = web3.utils.toBN(ETH_FEE_PERCENTAGE).muln(2).toString();
        const data   = abi.bridge.changeFee(ethIndex, newFee);

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));
        isExecuted.should.equal(true);

        const {feePercentage} = await bridge.methods.currencies(ethIndex).call();
        feePercentage.should.equal(newFee);
    });

    it('should add new currency as ERC20', async () => {
        const data = abi.bridge.addCurrency(
            erc20.options.address,
            ERC_SYMBOL,
            ERC_DECIMALS,
            ETH_CAPACITY,
            ETH_MIN_AMOUNT,
            ETH_FEE_PERCENTAGE
        );

        const isExecuted = await poaTxs.sendAndConfirm(
            DESTINATION.TARGET,
            data,
            {
                from: validators[0],
                gas:  6000000
            },
            validators.slice(1)
        );

        isExecuted.should.equal(true);

        const token = await bridge.methods.currencies(ERC_INDEX).call();

        token.symbol.should.equal(ERC_SYMBOL);
        token.decimals.should.equal(ERC_DECIMALS);
        token.tokenContract.should.equal(erc20.options.address);
        token.balance.should.equal('0');
        token.capacity.should.equal(ETH_CAPACITY);
        token.minExchange.should.equal(ETH_MIN_AMOUNT);
        token.feePercentage.should.equal(ETH_FEE_PERCENTAGE);
    });

    it('should deposit ERC20', async () => {
        const {feePercentage} = await bridge.methods.currencies(ERC_INDEX).call();
        const  accBalance     = await erc20.methods.balanceOf(owner).call();

        await erc20.methods.approve(bridge.options.address, TO_EXCHANGE).send({
            from: owner,
            gas:  1000000
        });

        await bridge.methods.exchange(
            ERC_INDEX,
            recipient,
            TO_EXCHANGE
        ).send({
            value: TO_EXCHANGE,
            from: owner,
            gas:  1000000
        });

        const newAccBalance = await erc20.methods.balanceOf(owner).call();

        const diff = web3.utils.toBN(accBalance).sub(web3.utils.toBN(TO_EXCHANGE)).toString();
        diff.should.equal(newAccBalance);

        const realAmount = web3.utils.toBN(TO_EXCHANGE)
            .sub(web3.utils.toBN(getFee(TO_EXCHANGE, feePercentage)))
            .toString();

        const {balance} = await bridge.methods.currencies(ERC_INDEX).call();
        balance.should.equal(realAmount);
    });

    it('should withdraw ERC20', async () => {
        const balance = await erc20.methods.balanceOf(owner).call();
        const data    = abi.bridge.withdraw(ERC_INDEX, owner, TO_WITHDRAW, '6000000');

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));
        isExecuted.should.equal(true);

        const newBalance = await erc20.methods.balanceOf(owner).call();
        const diff = web3.utils
            .toBN(balance)
            .add(web3.utils.toBN(TO_WITHDRAW))
            .toString();

        diff.should.equal(newBalance);
    });

    it('should migrate bank storage owner to new one', async () => {
        const data = abi.bridge.migration(owner);

        const isExecuted = await poaTxs.sendAndConfirm(DESTINATION.TARGET, data, {
            from: validators[0],
            gas:  6000000
        }, validators.slice(1));
        isExecuted.should.equal(true);

        const bsOwner = await bs.methods.owner().call();
        bsOwner.should.equal(owner);
    });

    it('should withdraw fee', async () => {
        for (let validator of validators) {
            const balance = await bs.methods.getValidatorFee(validator, ZERO_ADDRESS).call();
            assert(parseInt(balance) > 0, 'fees should be great then zero');
            await bs.methods.withdrawFee(ZERO_ADDRESS, balance, '500000').send({
                from: validator,
                gas:  500000
            });
        }

        for (let validator of validators) {
            const balance = await bs.methods.getValidatorFee(validator, erc20.options.address).call();
            assert(parseInt(balance) > 0, 'token fees should be great then zero');
            await bs.methods.withdrawFee(erc20.options.address, balance, '500000').send({
                from: validator,
                gas:  500000
            });
        }
    });
});

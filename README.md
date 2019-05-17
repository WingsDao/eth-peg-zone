# Peggy Zone Smart Contracts

**WINGS peg zone** smart contracts implementation, based on PoA (Proof of Authority) government model, supports **ETH and any ERC20 approved token**.

Allowing to move ETH/ERC20 tokens between Ethereum
blockchain and **WINGS blockchain**.

Right now security is reached by PoA validators, that inspected by community, later it should be replaced with Proof of Stake (PoS) algorithm to
reach more decentralization.

## Features

This is work in progress, but still general functional already implemented, like:

* **N/2+1** validators needed to reach consensus
* Allowing to remove/add validators by consensus
* Validator takes fees for their support
* Validator can propose to list any [ERC20 token](https://theethereum.wiki/w/index.php/ERC20_Token_Standard)
* Support minimum exchange amount and capacity of any ETH/ERC20 token
* Allowing to lock ETH/ERC20 tokens
* Allowing to withdraw ETH/ERC20 tokens
* Basic migration implemented
* Basic pause/resume function implemented for safe migration

## Motivation

Main motivation to use multiplay native currencies from
different blockchains inside **WINGS** blockchain, that will provide more liquidity for financial derivatives and financial operations in nutshell, and be not limited by one ecosystem. This idea opens new doors for
many of many usages we can bring to blockchain technology, such as defi, swaps, futures, options.

During our development we are going to make a same
solutions for popular blockchains, not only for Ethereum, like: **Bitcoin, EOS, Tron, Lisk, etc**.

## Structure

This repository contains only smart contract part, it doesnt include relay node part, and Cosmos part (module for Cosmos SDK), described initiatives will be announced later.

For easy explanation let's make a small glossary:
* `Currency`  - Any ETH/ERC20 token
* `Validator` - Validator account involved in PoA consensus
* `Peggy`     - Peg zone allowing to move tokens between chains
* `Consensus` - When any action requires validators N/2+1 approve, where N is total amount of PoA validators
* `WETH`      - Example currency, 1:1 to ETH, but exists on Wings blockchain

So let's look at **ETH to WETH UML** as example

![Wings to WETH UML](/uml/images/eth_wei_flow.png?raw=true "Wings to WETH UML")

WETH to ETH conversion going to work in same way, but lock will start at Wings blockchain, and withdraw will happen at Ethereum blockchain.

Current repository contains smart contracts part like:

* [PoAGoverment.sol](/contracts/PoAGoverement.sol) - Implements validators logic and PoA consensus logic on actions during peg zone life cycle
* [Bridge.sol](/contracts/Bridge.sol)      - Implements bridge for lock/withdraw Ethereum and any listed ERC20 token, when user want to move his ETH/tokens to Wings blockchain
* [BankStorage.sol](/contracts/BankStorage.sol)  - Keeps ETH/tokens and split fees between
validators

## PoA multisignature logic

In PoA implementations we have list of validators, maximum is
11 of them, minimum is 3. Each sensitive call
to Bridge done under validation consensus, means any validator
can initiate a transaction to Bridge contract or to itself contract (in case needs to add new validator, remove it, etc),
then once transaction reaches N/2+1 confirmations from the rest of validators, transaction could be executed.

## Fees

Fees splits between all active validators, and if value can't be divided without reminder smart contract will save reminder for next exchange.

To get accrued fees validator should make a call to BankStorage contract with amount and address of currency he wants to withdraw.

## Installation

    TODO

## Tests

    TODO

## Contribution

Current project is still under development and going to evolve together with other parts of Wings blockchain as
**Relay Layer** and Wings blockchain itself, anyway we have
planned things to:

* More tests coverage
* Allow to stop withdraw/deposit of specific currency
* Allow to do migration without reference on previous contract version
* First refactoring
* PoS government implementation instead of PoA

You are ready to contribute, but please, try to follow
solidity [style guide](https://solidity.readthedocs.io/en/v0.5.3/style-guide.html) and leave comments on new functional.

## License

UNLICENSED.

Wings Stiftung Copyright 2019.

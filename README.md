# Peg Zone Smart Contracts

**WINGS Peg Zone** smart contracts implementation, based on PoA (Proof of Authority) government model, supports **ETH and any ERC20 approved token**.

Allowing to move ETH and ERC20 tokens between Ethereum
blockchain and **WINGS Blockchain**.

Right now security is reached by PoA validators, that inspected by WINGS community, later it should be replaced with Proof of Stake (PoS) algorithm to
reach more decentralization.

## Features

This work is in progress, but general functionality is already implemented:

* **N/2+1** validators needed to reach consensus
* Allowing to remove/add validators by consensus
* Validator takes fees for their support
* Validator can propose for a listing any [ERC20 token](https://theethereum.wiki/w/index.php/ERC20_Token_Standard)
* Support of a minimum exchange amount and capacity of any ETH/ERC20 token
* Allowing to lock ETH/ERC20 tokens
* Allowing to withdraw ETH/ERC20 tokens
* Basic migration implemented
* Basic pause/resume function implemented for safe migration

## Motivation

In a nutshell, main motivation to use multiple native currencies from different blockchains inside **WINGS** blockchain, is that it will provide more liquidity for financial derivatives and financial operations  and will not be limited by one ecosystem. This idea opens new doors for a many use cases we can bring to blockchain technology such as DeFi, Swaps, Futures, Options.

During our development we are going to make the same
solutions for popular blockchains, such as **Bitcoin, EOS, Tron, Lisk, etc**.

## Structure

This repository contains only smart contract part, it doesnt include relay node part, and Cosmos part (module for Cosmos SDK), described initiatives will be announced later.

For easy explanation let's make a small glossary:
* `Currency`  - Any ETH/ERC20 token
* `Validator` - Validator account involved in PoA consensus
* `Peggy`     - Peg zone allowing to move tokens between chains
* `Consensus` - When any action requires validators N/2+1 approve, where N is total amount of PoA validators
* `mETH`      - Example currency, 1:1 to ETH, but exists on Wings blockchain

So let's look at **ETH to mETH UML** as example

![Wings to wETH UML](/res/eth_wei_flow.png?raw=true "Wings to WETH UML")

mETH to ETH conversion going to work in the same way, but lock will start at Wings blockchain, and withdraw will happen at Ethereum blockchain.

Current repository contains smart contracts part like:

* [PoAGovernment.sol](/contracts/PoAGovernment.sol) - Implements validators logic and PoA consensus logic on actions during peg zone life cycle
* [Bridge.sol](/contracts/Bridge.sol) - Implements bridge to lock/withdraw Ethereum and any listed ERC20 tokens, when user want to move his ETH or ERC20 tokens to Wings blockchain
* [BankStorage.sol](/contracts/BankStorage.sol)  - Keeps ETH or ERC20 tokens and split fees between validators

## PoA multisignature logic

In PoA implementations we have list of validators, maximum is 11, minimum is 3. Each sensitive call to Bridge done under validation consensus, means any validator can initiate a transaction to Bridge contract or to itself contract (in case if needs to add new validator or remove it and etc), then, once transaction reaches N/2+1 confirmations from the rest of validators, transaction could be executed.

## Fees

Fees splits between all active validators, and if value can't be divided without reminder, smart contract will save reminder for next exchange.

To get accrued fees validator should make a call request to BankStorage contract with the amount and address of currency he wants to withdraw.

## Installation

    TODO

## Tests

    TODO

## Docs

    TODO

## Contribution

Current project is under development and going to evolve together with other parts of Wings blockchain as
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

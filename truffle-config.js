'use strict';

const Web3            = require('web3');
const {getHDProvider} = require('./provider');

module.exports = {
    networks: {
        development: {
            provider: new Web3.providers.HttpProvider('http://127.0.0.1:8545'),
            network_id: '*'
        },
        ropsten: {
          provider: () => {
            return getHDProvider();
          },
          network_id: 3,
          gas: 8000000,
          skipDryRun: true
        },
    },
    mocha: {
        timeout: 100000
    },
    compilers: {
        solc: {
            version: '0.5.9',
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200
                }
            },
        }
    }
};

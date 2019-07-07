'use strict';

const Web3 = require('web3');

module.exports = {

    networks: {

        development: {
            provider: new Web3.providers.HttpProvider('http://127.0.0.1:8545'),
//            host: "testrpc",
//            port: 8545,
            network_id: "*"
        },
    },

    mocha: {
        // timeout: 100000
    },

    // Configure your compilers
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

#!/bin/bash

set -e

# Use variables
# WEB3_URL - Url to testrpc or other RPC
# TESTING - Variable for testing docker-compose

WEB3_URL=${WEB3_URL:-http://127.0.0.1:8545}

function print_use_variables {
    cat << EOF
WEB3_URL: ${WEB3_URL}
TESTING: ${TESTING}
ACCOUNT: ${ACCOUNT}
BANK_STORAGE_FACTORY: ${BANK_STORAGE_FACTORY}
POA_FACTORY: ${POA_FACTORY}
BRIDGE_FACTORY: ${BRIDGE_FACTORY}
ETH_ADDRESSES: ${ETH_ADDRESSES}
WB_ADDRESSES: ${WB_ADDRESSES}
ETH_CAPACITY: ${ETH_CAPACITY}
ETH_MIN_EXCHANGE: ${ETH_MIN_EXCHANGE}
ETH_FEE_PERCENTAGE: ${ETH_FEE_PERCENTAGE}
GAS_LIMIT: ${GAS_LIMIT}
EOF
}

function deploy_contracts {
    print_use_variables
    sed -i "s|http://127.0.0.1:8545|${WEB3_URL}|g" truffle-config.js
    truffle compile

    CONTRACT=BankStorage truffle migrate
    CONTRACT=PoA truffle migrate
    CONTRACT=Bridge truffle migrate
    CONTRACT=NewBridge truffle migrate
}


### Start

if ${TESTING} ; then
    if [[ ! -e /tmp/deploy/true ]]; then
        echo 'Deploy contracts eth-peg-zone'
        deploy_contracts
        touch /tmp/deploy/true
    else
        echo 'Contracts already deploy'
    fi
else
    deploy_contracts
fi

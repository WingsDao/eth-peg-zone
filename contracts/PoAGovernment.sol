pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;

import "./Validators.sol";

/// @title  PoAGovernment contract implements gnosis multisignature implementation and validators mechanics
/// @notice Based on Gnosis multisignature wallet, LGPL v3
/// @dev    Allowing validators to post trasactions and execute them in agreee with other validators
contract PoAGovernment is Validators {
    /// @notice                Happens when transaction confirmed by validator
    /// @param  _sender        Validator who confirmed transaction
    /// @param  _transactionId Id of transaction that confirmed by validator
    event TX_CONFIRMED(address indexed _sender, uint256 indexed _transactionId);

    /// @notice                Happens when confirmation on transaction removed by already confirmed validator
    /// @param  _sender        Validator that revoked confirmation
    /// @param  _transactionId Id of transaction that revoked by validator
    event TX_REVOKED(address indexed _sender, uint256 indexed _transactionId);

    /// @notice                Happens when new transaction submited
    /// @param  _sender        Validator who submited transaction
    /// @param  _transactionId Id of transaction that submited
    /// @param  _hash          Hash of transaction data.
    event TX_SUBMISSED(address indexed _sender, uint256 indexed _transactionId, bytes32 _hash);

    /// @notice                Happens when transaction executed
    /// @param  _transactionId Id of transaction that just executed
    event TX_EXECUTED(uint256 indexed _transactionId);

    /// @notice                 Happens when transaction execution failed
    /// @param  _transactionId  Id of transaction that submited
    event TX_EXECUTION_FAILED(uint256 indexed _transactionId);

    /// @notice Destination of call
    enum Destination {
        SELF,
        TARGET
    }

    /// @notice Trasaction structure that could be posted by validator
    struct Transaction {
        address creator;
        address destination;
        bytes data;
        bool executed;
        bytes32 hash;
    }

    /// @notice Total amount of transactions
    uint256 public transactionCount;

    /// @notice List of transactions by it's count
    mapping(uint256 => Transaction) public transactions;

    /// @notice List of transaction ids by it's data hash.
    mapping(bytes32 => uint256[]) public txsByHash;

    /// @notice Confirmations list for each transaction
    mapping(uint256 => mapping(address => bool)) public confirmations;

    /// @notice Target contract, that will accept trasaction calls from validators
    address public target;

    /// @notice               Check if transaction confirmed by validator
    /// @param _transactionId Id of transaction to verify if it's confirmed
    /// @param _validator     Validator address
    modifier confirmed(uint256 _transactionId, address _validator) {
        require(
            confirmations[_transactionId][_validator],
            "Transaction isnt confirmed"
        );
        _;
    }

    /// @notice                 Check if transaction transaction not confirmed yet by validator
    /// @param  _transactionId  Id of transaction to verify if it's not confirmed
    /// @param  _validator      Validator address
    modifier notConfirmed(uint256 _transactionId, address _validator) {
        require(
            !confirmations[_transactionId][_validator],
            "Transaction is confirmed"
        );
        _;
    }

    /// @notice                Check if transaction not executed yet
    /// @param  _transactionId Id of transaction
    modifier notExecuted(uint256 _transactionId) {
        require(
            !transactions[_transactionId].executed,
            "Transaction executed already"
        );
        _;
    }

    /// @notice                Check if transaction exists by id
    /// @param  _transactionId Id of transaction to check
    modifier transactionExists(uint256 _transactionId) {
        require(
            transactions[_transactionId].creator != address(0),
            "Trasaction doesnt exist"
        );
        _;
    }

    /// @notice                 Check if transaction hashes matches for specific transaction id
    /// @param   _transactionId Id of transaction
    //  @param   _hash          Hash of transaction data to match
    modifier transactionHashMatch(uint256 _transactionId, bytes32 _hash) {
        require(
            transactions[_transactionId].hash == _hash,
            "Trasaction hash doesnt match"
        );
        _;
    }

    /// @notice              Constructor, inherits by validators contract
    /// @param  _target      Target contract of PoA, validators execute this contract functions
    /// @param  _bankStorage Address of BankStorage contract
    constructor(
        address _target,
        address _bankStorage
    )
        Validators(_bankStorage)
        public
    {
        require(_target != address(0), "Target address is empty");

        target = _target;
    }

    /// @notice                  Setup contract initial validators, should be called before usage of contract
    /// @param  _ethAddresses    ETH addresses of initial validators
    /// @param  _cosmosAddresses Cosmos addresses of initial validators
    function setup(
        address[] memory _ethAddresses,
        bytes32[] memory _cosmosAddresses
    )
        public
        onlyOwner()
    {
        super.setup(_ethAddresses, _cosmosAddresses);
    }

    /// @notice       Allows an validator to submit and confirm a transaction
    /// @param  _data Transaction data payload
    /// @return       Returns transaction ID
    function submitTransaction(
        uint256 _destination,
        bytes memory _data
    )
        public
        validatorExists(msg.sender)
        returns (uint256)
    {
        address destinationAddress;
        Destination dest = Destination(_destination);

        if (dest == Destination.TARGET) {
            destinationAddress = target;
        } else {
            destinationAddress = address(this);
        }

        var (transactionId, hash) = addTransaction(destinationAddress, _data);
        emit TX_SUBMISSED(msg.sender, transactionId, hash);

        confirmTransaction(transactionId, hash);

        return transactionId;
    }

    /// @notice                Allows an validator to confirm a transaction
    /// @param  _transactionId Id of transaction
    /// @param  _hash          Hash of transaction data
    /// @return                Returns boolean depends on success
    function confirmTransaction(
        uint256 _transactionId,
        bytes32 _hash
    )
        public
        validatorExists(msg.sender)
        transactionExists(_transactionId)
        transactionHashMatch(_transactionId, _hash)
        notConfirmed(_transactionId, msg.sender)
        returns (bool)
    {
        confirmations[_transactionId][msg.sender] = true;
        emit TX_CONFIRMED(msg.sender, _transactionId);

        executeTransaction(_transactionId, transactions[_transactionId].hash);

        return true;
    }

    /// @notice                Allows an validator to revoke a confirmation for a transaction
    /// @param  _transactionId Transaction ID
    /// @param  _hash          Hash of transaction data
    /// @return                Returns boolean depends on success
    function revokeConfirmation(
        uint256 _transactionId,
        bytes32 _hash
    )
        public
        validatorExists(msg.sender)
        confirmed(_transactionId, msg.sender)
        transactionHashMatch(_transactionId, _hash)
        notExecuted(_transactionId)
        returns (bool)
    {
        confirmations[_transactionId][msg.sender] = false;
        emit TX_REVOKED(msg.sender, _transactionId);

        return true;
    }

    /// @notice                Allows any validator to execute a confirmed transaction
    /// @param  _transactionId Transaction ID
    /// @param  _hash          Hash of transactio data
    /// @return                Returns boolean depends on success
    function executeTransaction(
        uint256 _transactionId,
        bytes32 _hash
    )
        public
        validatorExists(msg.sender)
        confirmed(_transactionId, msg.sender)
        transactionHashMatch(_transactionId, _hash)
        notExecuted(_transactionId)
    {
        if (isConfirmed(_transactionId)) {
            Transaction storage txn = transactions[_transactionId];
            txn.executed = true;
            if (external_call(txn.destination, txn.data.length, txn.data)) {
                emit TX_EXECUTED(_transactionId);
            }
            else {
                emit TX_EXECUTION_FAILED(_transactionId);
                txn.executed = false;
            }
        }
    }

    /// @notice               Doing a call to this contract with data from transaction
    /// @param   _dataLength  Length of data to do a call
    /// @param   _data        Data itself
    /// @return               Boolean depends on success
    function external_call(
        address _destination,
        uint256 _dataLength,
        bytes memory _data
    )
        internal
        returns (bool)
    {
        bool result;

        assembly {
            let x := mload(0x40)   // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
            let d := add(_data, 32) // First 32 bytes are the padded length of data, so exclude that
            result := call(
                sub(gas, 34710),   // 34710 is the value that solidity is currently emitting
                                   // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
                                   // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
                _destination,
                0,
                d,
                _dataLength,        // Size of the input (in bytes) - this is what fixes the padding problem
                x,
                0                  // Output is ignored, therefore the output size is zero
            )
        }
        return result;
    }

    /// @notice        Adds a new transaction to the transaction mapping, if transaction does not exist yet
    /// @param   _data Transaction data payload
    /// @return        Returns transaction ID and hash of data.
    function addTransaction(
        address _destination,
        bytes memory _data
    )
        internal
        returns (uint256, bytes32)
    {
        uint256 transactionId = transactionCount;
        bytes32 hash = keccak256(abi.encodePacked(_destination, _data));

        transactions[transactionId] = Transaction({
            creator: msg.sender,
            data: _data,
            executed: false,
            hash: hash,
            destination: _destination
        });

        txsByHash[hash].push(transactionId);
        transactionCount += 1;

        return (transactionId, hash);
    }

    /// @notice            Returns total number of transactions after filers are applied
    /// @param   _pending  Include pending transactions
    /// @param   _executed Include executed transactions
    /// @return            Total number of transactions after filters are applied
    function getTransactionCount(bool _pending, bool _executed)
        public
        view
        returns (uint256)
    {
        uint256 count = 0;

        for (uint256 i = 0; i < transactionCount; i++)
            if (_pending && !transactions[i].executed
                || _executed && transactions[i].executed)
                count += 1;

        return count;
    }

    /// @notice                 Returns the confirmation status of a transaction
    /// @param   _transactionId Transaction ID
    /// @return                 Confirmation status
    function isConfirmed(uint256 _transactionId)
        public
        view
        returns (bool)
    {
        uint256 count = 0;

        for (uint256 i = 0; i < validators.length; i++) {
            if (confirmations[_transactionId][validators[i].ethAddress])
                count += 1;

            if (count >= required)
                return true;
        }

        return false;
    }

    /// @notice                Returns number of confirmations of a transaction
    /// @param  _transactionId Transaction ID
    /// @return                Number of confirmations
    function getConfirmationCount(uint256 _transactionId)
        public
        view
        returns (uint256)
    {
        uint256 count = 0;

        for (uint i = 0; i < validators.length; i++)
            if (confirmations[_transactionId][validators[i].ethAddress])
                count += 1;

        return count;
    }

    /// @notice        Returns transaction id by hash and index.
    /// @param  _hash  Hash of transaction data.
    /// @param  _index Index of transaction.
    /// @return        Id of transaction.
    function getTxIdByHash(bytes32 _hash, uint256 _index)
        public
        view
        returns (uint256)
    {
        if (txsByHash[_hash].length == 0) {
            revert('Transactions with such hash not found');
        }

        return txsByHash[_hash][_index];
    }
}

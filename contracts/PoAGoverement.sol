pragma solidity ^0.5.8;

import "./Validators.sol";

/// @title  PoAGoverement contract implements gnosis multisignature implementation and validators mechanics
/// @notice Based on Gnosis multisignature wallet, LGPL v3
/// @dev    Allowing validators to post trasactions and execute them in agreee with other validators
contract PoAGoverement is Validators {
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
    event TX_SUBMISSED(address indexed _sender, uint256 indexed _transactionId);

    /// @notice               Happens when transaction executed
    /// @param  _transactionId Id of transaction that just executed
    event TX_EXECUTED(uint256 indexed _transactionId);

    /// @notice                 Happens when transaction execution failed
    /// @param  _transactionId   Id of transaction that submited
    event TX_EXECUTION_FAILED(uint256 indexed _transactionId);

    /// @notice         Happens when amount of validators confirmations changed
    /// @param _required New amount of validators confirmations to execute transaction
    event REQUIREMENT_CHANGED(uint256 _required);

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

    /// @notice Amount of confirmations to execute transaction
    uint256 public required;

    /// @notice Total amount of transactions
    uint256 public transactionCount;

    /// @notice List of transactions by it's count
    mapping(uint256 => Transaction) public transactions;

    /// @notice Confirmations list for each transaction
    mapping(uint256 => mapping(address => bool)) public confirmations;

    /// @notice Target contract, that will accept trasaction calls from validators
    address public target;

    /// @notice               Check if transaction confirmed by validator
    /// @param _transactionId Id of transaction to verify if it's confirmed
    /// @param _validator     Validator address
    modifier confirmed(uint256 _transactionId, address _validator) {
        require(confirmations[_transactionId][_validator]);
        _;
    }

    /// @notice                 Check if transaction transaction not confirmed yet by validator
    /// @param  _transactionId  Id of transaction to verify if it's not confirmed
    /// @param  _validator      Validator address
    modifier notConfirmed(uint256 _transactionId, address _validator) {
        require(!confirmations[_transactionId][_validator]);
        _;
    }

    /// @notice                Check if transaction not executed yet
    /// @param  _transactionId Id of transaction
    modifier notExecuted(uint256 _transactionId) {
        require(!transactions[_transactionId].executed);
        _;
    }

    /// @notice                Check if transaction exists by id
    /// @param  _transactionId Id of transaction to check
    modifier transactionExists(uint256 _transactionId) {
        require(transactions[_transactionId].creator != address(0));
        _;
    }

    /// @notice                 Check if transaction hashes matches for specific transaction id
    /// @param   _transactionId Id of transaction
    //  @param   _hash          Hash of transaction data to match
    modifier transactionHashMatch(uint256 _transactionId, bytes32 _hash) {
        require(transactions[_transactionId].hash == _hash);
        _;
    }

    /// @notice            Constructor, inherits by validators contract
    /// @param _validators Array of validators
    constructor(
        address[] memory _validators,
        address _target,
        address _bankStorage
    )
        Validators(_validators, _bankStorage)
        public
    {
        require(_target != address(0));

        target = _target;

        updateRequirement(_validators.length);
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

        uint256 transactionId = addTransaction(destinationAddress, _data);
        emit TX_SUBMISSED(msg.sender, transactionId);

        confirmTransaction(transactionId, transactions[transactionId].hash);

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
        returns (bool)
    {
        if (isConfirmed(_transactionId)) {
            Transaction storage txn = transactions[_transactionId];
            txn.executed = true;
            if (external_call(txn.destination, txn.data.length, txn.data)) {
                emit TX_EXECUTED(_transactionId);
                return false;
            }
            else {
                emit TX_EXECUTION_FAILED(_transactionId);
                txn.executed = false;
                return false;
            }
        }

        return false;
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
    /// @return        Returns transaction ID
    function addTransaction(
        address _destination,
        bytes memory _data
    )
        internal
        returns (uint256)
    {
        uint256 transactionId = transactionCount;

        transactions[transactionId] = Transaction({
            creator: msg.sender,
            data: _data,
            executed: false,
            hash: keccak256(abi.encodePacked(_destination, _data)),
            destination: _destination
        });

        transactionCount += 1;

        return transactionId;
    }

    /// @notice                  Update amount of required confirmations to confirm transaction
    /// @param  _validatorsCount Validators amount
    function updateRequirement(uint256 _validatorsCount) private {
        required = _validatorsCount / 2 + 1;
        emit REQUIREMENT_CHANGED(required);
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
            if (confirmations[_transactionId][validators[i]])
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
            if (confirmations[_transactionId][validators[i]])
                count += 1;

        return count;
    }
}

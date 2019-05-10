pragma solidity ^0.4.22;

contract Bridge {
  // only this can execute function
  modifier onlyThis() {
      require(msg.sender == address(this));
      _;
  }

  // is transaction confirmed by validator
  modifier confirmed(uint256 _transactionId, address _validator) {
      require(confirmations[_transactionId][_validator]);
      _;
  }

  // is transaction not confirmed
  modifier notConfirmed(uint256 _transactionId, address _validator) {
      require(!confirmations[_transactionId][_validator]);
      _;
  }

  // transaction not executed
  modifier notExecuted(uint256 _transactionId) {
      require(!transactions[_transactionId].executed);
      _;
  }

  // check if validator exists
  modifier validatorExists(address _validator) {
    require(isValidator[_validator]);
    _;
  }

  // check if validator doesn't exists
  modifier validatorDoesntExists(address _validator) {
    require(!isValidator[_validator]);
    _;
  }

  // check if transaction exists
  modifier transactionExists(uint256 _transactionId) {
      require(transactions[_transactionId].destination != 0);
      _;
  }

  uint256 constant MAX_VALIDATORS = 11; // maximum validators
  uint256 constant MIN_VALIDATORS = 3;  // minimum amount of validators

  // Transaction
  struct Transaction {
      bytes data;
      bool executed;
  }

  mapping (uint256 => Transaction) public transactions; // list of transactions
  mapping (uint256 => mapping (address => bool)) public confirmations; // confirmations for transactions
  mapping (address => bool) public isValidator; // check if is validator

  address[] public validators; // max validators
  uint256 public required; // how much confirmations required
  uint256 public transactionCount; // how much transactions total here

  // constructor
  constructor(address[] _validators) public {
     // check if amount of validators is valid
    require(_validators.length >= MIN_VALIDATORS);

    // adding initial validators to smart contract
    for (uint256 i = 0; i < _validators.length; i++) {
      addValidator(_validators[i]);
    }

    // how much signagtures required, due to BFT it's n/2+1
    required = getNewRequired(_validators.length);
  }

  /////
  ///// Transaction logic
  /////

  /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
  /// @param destination Transaction target address.
  /// @param value Transaction ether value.
  /// @param data Transaction data payload.
  /// @return Returns transaction ID.
  function addTransaction(bytes _data)
      internal
      returns (uint256)
  {
      uint256 transactionId = transactionCount;
      transactions[transactionId] = Transaction({
          data: _data,
          executed: false
      });
      transactionCount += 1;

      return transactionId;
  }


  /// @dev Allows an owner to submit and confirm a transaction.
  /// @param destination Transaction target address.
  /// @param value Transaction ether value.
  /// @param data Transaction data payload.
  /// @return Returns transaction ID.
  function submitTransaction(bytes _data)
      public
      validatorExists(msg.sender)
      returns (uint256)
  {
      uint256 transactionId = addTransaction(_data);
      confirmTransaction(transactionId);

      return transactionId;
  }

  /// @dev Allows an owner to confirm a transaction.
  /// @param transactionId Transaction ID.
  function confirmTransaction(uint256 _transactionId)
      public
      transactionExists(_transactionId)
      validatorExists(msg.sender)
      notConfirmed(_transactionId, msg.sender)
  {
      confirmations[_transactionId][msg.sender] = true;

      executeTransaction(_transactionId);
  }

  /// @dev Allows an owner to revoke a confirmation for a transaction.
  /// @param transactionId Transaction ID.
  function revokeConfirmation(uint256 _transactionId)
      public
      ownerExists(msg.sender)
      confirmed(_transactionId, msg.sender)
      notExecuted(_transactionId)
  {
      confirmations[_transactionId][msg.sender] = false;
      Revocation(msg.sender, _transactionId);
  }

  /// @dev Allows anyone to execute a confirmed transaction.
  /// @param transactionId Transaction ID.
  function executeTransaction(uint256 _transactionId)
      public
      ownerExists(msg.sender)
      confirmed(_transactionId, msg.sender)
      notExecuted(_transactionId)
  {
      if (isConfirmed(_transactionId)) {
          Transaction storage txn = transactions[_transactionId];
          txn.executed = true;
          if (external_call(txn.data.length, txn.data))
              Execution(_transactionId);
          else {
              ExecutionFailure(_transactionId);
              txn.executed = false;
          }
      }
  }

  // call has been separated into its own function in order to take advantage
  // of the Solidity's code generator to produce a loop that copies tx.data into memory.
  function external_call(uint256 _dataLength, bytes _data) internal returns (bool) {
      bool result;
      assembly {
          let x := mload(0x40)   // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
          let d := add(_data, 32) // First 32 bytes are the padded length of data, so exclude that
          result := call(
              sub(gas, 34710),   // 34710 is the value that solidity is currently emitting
                                 // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
                                 // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
              address(this),
              0,
              d,
              _dataLength,        // Size of the input (in bytes) - this is what fixes the padding problem
              x,
              0                  // Output is ignored, therefore the output size is zero
          )
      }
      return result;
  }

  /////
  ///// Validators logic
  /////
  /**
    * Adding initial validators to smart contract.
  **/
  function addValidator(address _validator) public onlyThis validatorDoesntExists(_validator) returns (bool) {
    require(_validator != address(0));
    require(validators.length+1 < MAX_VALIDATORS);

    validators.push(validator);
    isValidator[validator] = true;

    updateRequirement(validators.length);

    return true;
  }

  /**
    * Replace validator.
  **/
  function replaceValidator(address _validator, address _newValidator) public onlyThis validatorExists(_validator) validatorDoesntExists(_newValidator) (bool) {
    require(isValidator[_validator]);
    require(!isValidator[_newValidator]);

    for (uint256 i = 0; i < validators.length; i++) {
      if (validators[i] == _validator) {
        validators[i] = _newValidator;
        isValidator[_validator] = false;
        isValidator[_newValidator] = true;
        break;
      }
    }

    return true;
  }

  /**
    * Removing validator.
  **/
  function removeValidator(address _validator) public onlyThis validatorExists(_validator) returns (bool) {
    require(validators.length - 1 > MIN_VALIDATORS);
    require(isValidator[_validator]);

    isValidator[_validator] = false;

    for (uint256 i = 0; i < validators.length - 1; i++) {
        if (validators[i] == _validator) {
            validators[i] = validators[validators.length - 1];
            break;
        }
    }

    validators.length -= 1;
    updateRequirement(validators.length);

    return true;
  }

  /**
    * Returns new required.
  **/
  function updateRequirement(uint256 _validatorsCount) private {
    required = _validatorsCount / 2 + 1;
  }
}

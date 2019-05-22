pragma solidity ^0.5.8;

import "./helpers/SelfExec.sol";
import "./BankStorage.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/// @title  Contract implements validators functional
/// @notice Allowing to add, remove, replace validators, and control validators state
contract Validators is SelfExec, Ownable {
    /// @notice            Happens when new validator added
    /// @param  _validator Validator that just added
    event ADDED_VALIDATOR(address indexed _validator);

    /// @notice               Happens when validator replaced
    /// @param  _oldValidator Validator that replaced with new one
    /// @param  _newValidator Validator that just added
    event REPLACED_VALIDATOR(address indexed _oldValidator, address indexed _newValidator);

    /// @notice             Happens when validator removed from list of validators
    /// @param  _validator  Validator that just removed
    event REMOVED_VALIDATOR(address indexed _validator);

    /// @notice Maximum amount of validators
    uint256 constant MAX_VALIDATORS = 11;

    /// @notice Minimum amount of validators
    uint256 constant MIN_VALIDATORS = 3;

    /// @notice List of active validators
    mapping(address => bool) public isValidator;

    /// @notice Array of all validators and their addressess
    address[] public validators;

    /// @notice Bank storage
    BankStorage public bankStorage;

    /// @notice            Check if validator already exists in smart contract
    /// @param  _validator Address of validator to check
    modifier validatorExists(address _validator) {
        require(isValidator[_validator], "Validator doesnt exist");
        _;
    }

    /// @notice            Check if validator doesn't exist in smart contract
    /// @param  _validator Address of validator to check
    modifier validatorDoesntExist(address _validator) {
        require(!isValidator[_validator], "Validator exists");
        _;
    }

    /// @notice              Initialize validators contract with address of BankStorage
    /// @param  _bankStorage Address of BankStorage contract
    constructor(
        address _bankStorage
    )
        public
    {
        require(_bankStorage != address(0), "BankStorage address is empty");

        bankStorage = BankStorage(_bankStorage);
    }

    /// @notice             Setup initial validators list
    /// @param  _validators Array with initial validators addresses
    function setup(address[] memory _validators) public onlyOwner() {
        require(validators.length  == 0, "Validators already initialized");
        require(
            _validators.length >= MIN_VALIDATORS,
            "Required minimum validators amount for initialization"
        );

        for (uint256 i = 0; i < _validators.length; i++) {
            addValidatorInternal(_validators[i]);
        }
    }

    /// @notice            Adding validator to validators list
    /// @param  _validator Address of validator to add
    /// @dev               Possible to execute only by contract itself
    /// @return            Returns boolean depends on success or fail
    function addValidator(address _validator)
        public
        onlySelf()
        returns (bool)
    {
        return addValidatorInternal(_validator);
    }

    /// @notice Replace current validator with another one
    /// @param  _validator Address of validator to replace
    /// @param  _validator Address of new validator to put
    /// @dev               Possible to execute only by contract itself
    /// @return            Returns boolean depends on success or fail
    function replaceValidator(
        address _validator,
        address _newValidator
    )
        public
        onlySelf()
        validatorExists(_validator)
        validatorDoesntExist(_newValidator)
        returns (bool)
    {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == _validator) {
                validators[i] = _newValidator;
                isValidator[_validator] = false;
                isValidator[_newValidator] = true;

                break;
            }
        }

        bankStorage.removeActiveValidator(address(uint160(_validator)));
        bankStorage.addValidator(address(uint160(_newValidator)));

        emit REPLACED_VALIDATOR(_validator, _newValidator);
        return true;
    }

    /// @notice Remove existing validator
    /// @param  _validator Address of existing validator to remove
    /// @dev               Possible to execute only by contract itself
    /// @return            Returns boolean depends on success or fail
    function removeValidator(address _validator)
        public
        onlySelf()
        validatorExists(_validator)
        returns (bool)
    {
        require(
            validators.length - 1 > MIN_VALIDATORS,
            "Minimum validators amount reached"
        );

        isValidator[_validator] = false;

        for (uint256 i = 0; i < validators.length - 1; i++) {
            if (validators[i] == _validator) {
                validators[i] = validators[validators.length - 1];
                break;
            }
        }

        validators.length -= 1;

        bankStorage.removeActiveValidator(address(uint160(_validator)));

        emit REMOVED_VALIDATOR(_validator);
        return true;
    }

    /// @notice            Internal function for adding validator
    /// @dev               Done to be able to add validators by this contract internal and itself
    /// @param  _validator Address of validator
    /// @return            Returns boolean depends on success or fail
    function addValidatorInternal(
        address _validator
    )
        internal
        validatorDoesntExist(_validator)
        returns (bool)
    {
        require(_validator != address(0), "Validator address is zero");
        require(
            validators.length+1 < MAX_VALIDATORS,
            "Reached maximum validators amount"
        );

        validators.push(_validator);
        isValidator[_validator] = true;

        bankStorage.addValidator(address(uint160(_validator)));

        emit ADDED_VALIDATOR(_validator);
        return true;
    }
}

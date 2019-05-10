pragma solidity ^0.5.1;

import "./SelfExec.sol";

/// @title  Contract implements validators functional
/// @notice Allowing to add, remove, replace validators, and control validators state
contract Validators is SelfExec {
    /// @notice maximum amount of validators
    uint256 constant MAX_VALIDATORS = 11;

    /// @notice minimum amount of validators
    uint256 constant MIN_VALIDATORS = 3;

    /// @notice list of active validators
    mapping(address => bool) public isValidator;

    /// @notice array of all validators and their addressess
    address[] public validators;

    modifier validatorExists(address _validator) {
        require(isValidator[_validator]);
        _;
    }

    modifier validatorDoesntExist(address _validator) {
        require(!isValidator[_validator]);
        _;
    }

    constructor(address[] memory _validators) public {
        require(_validators.length >= MIN_VALIDATORS);

        for (uint256 i = 0; i < _validators.length; i++) {
            addValidator(_validators[i]);
        }
    }

    function addValidator(address _validator)
        public
        onlySelf()
        validatorDoesntExist(_validator)
        returns (bool)
    {
        require(_validator != address(0));
        require(validators.length+1 < MAX_VALIDATORS);

        validators.push(_validator);
        isValidator[_validator] = true;

        return true;
    }

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

    function removeValidator(address _validator)
        public
        onlySelf()
        validatorExists(_validator)
        returns (bool)
    {
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
        return true;
    }
}

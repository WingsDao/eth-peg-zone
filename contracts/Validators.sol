pragma solidity ^0.5.8;
pragma experimental ABIEncoderV2;

import "./helpers/SelfExec.sol";
import "./BankStorage.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/// @title  Contract implements validators functional
/// @notice Allowing to add, remove, replace validators, and control validators state
contract Validators is SelfExec, Ownable {
    /// @notice                Happens when new validator added
    /// @param  _ethAddress    Validator that just added
    /// @param  _cosmosAddress Cosmos address of validator
    event ADDED_VALIDATOR(address indexed _ethAddress, bytes _cosmosAddress);

    /// @notice                Happens when validator replaced
    /// @param  _ethAddress    Validator that replaced with new one
    /// @param  _ethNewAddress Validator that just added
    /// @param  _cosmosAddress Cosmos address of new validator
    event REPLACED_VALIDATOR(
        address indexed _ethAddress,
        address indexed _ethNewAddress,
        bytes           _cosmosAddress
    );

    /// @notice              Happens when validator removed from list of validators
    /// @param  _ethAddress  Validator that just removed
    event REMOVED_VALIDATOR(address indexed _ethAddress);

    /// @notice Maximum amount of validators
    uint256 constant MAX_VALIDATORS = 11;

    /// @notice Minimum amount of validators
    uint256 constant MIN_VALIDATORS = 3;

    /// @notice List of active validators
    mapping(address => bool) public isValidator;

    /// @notice Validators struct
    struct Validator {
        address ethAddress;
        bytes   cosmosAddress;
    }

    /// @notice Array of all validators and their addressess
    Validator[] public validators;

    /// @notice Bank storage
    BankStorage public bankStorage;

    /// @notice             Check if validator already exists in smart contract
    /// @param  _ethAddress Address of validator to check
    modifier validatorExists(address _ethAddress) {
        require(isValidator[_ethAddress], "Validator doesnt exist");
        _;
    }

    /// @notice             Check if validator doesn't exist in smart contract
    /// @param  _ethAddress Address of validator to check
    modifier validatorDoesntExist(address _ethAddress) {
        require(!isValidator[_ethAddress], "Validator exists");
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

    /// @notice                  Setup initial validators list
    /// @param  _ethAddresses    Array with initial eth validators addresses
    /// @param  _cosmosAddresses Array with initial cosmos validators addresses
    function setup(
        address[] memory _ethAddresses,
        bytes[]   memory _cosmosAddresses
    )
        public
        onlyOwner()
    {
        require(_ethAddresses.length == 0, "Validators already initialized");
        require(
            _ethAddresses.length >= MIN_VALIDATORS,
            "Required minimum validators amount for initialization"
        );
        require(
            _ethAddresses.length == _cosmosAddresses.length,
            "Required equal amounts of eth address and cosmos addresses"
        );

        for (uint256 i = 0; i < _ethAddresses.length; i++) {
            addValidatorInternal(_ethAddresses[i], _cosmosAddresses[i]);
        }
    }

    /// @notice                Adding validator to validators list
    /// @param  _ethAddress    Address of validator to add
    /// @param  _cosmosAddress Cosmos address of validator
    /// @dev                   Possible to execute only by contract itself
    /// @return                Returns boolean depends on success or fail
    function addValidator(address _ethAddress, bytes memory _cosmosAddress)
        public
        onlySelf()
        returns (bool)
    {
        return addValidatorInternal(_ethAddress, _cosmosAddress);
    }

    /// @notice                Replace current validator with another one
    /// @param  _ethAddress    Address of validator to replace
    /// @param  _ethNewAddress Address of new validator to put
    /// @param  _cosmosAddress Cosmos address of new validator to put
    /// @dev                   Possible to execute only by contract itself
    /// @return                Returns boolean depends on success or fail
    function replaceValidator(
        address        _ethAddress,
        address        _ethNewAddress,
        bytes   memory _cosmosAddress
    )
        public
        onlySelf()
        validatorExists(_ethAddress)
        validatorDoesntExist(_ethNewAddress)
        returns (bool)
    {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i].ethAddress == _ethAddress) {
                validators[i] = Validator({
                    ethAddress:    _ethNewAddress,
                    cosmosAddress: _cosmosAddress
                });

                isValidator[_ethAddress] = false;
                isValidator[_ethNewAddress] = true;

                break;
            }
        }

        bankStorage.removeActiveValidator(address(uint160(_ethAddress)));
        bankStorage.addValidator(address(uint160(_ethNewAddress)));

        emit REPLACED_VALIDATOR(_ethAddress, _ethNewAddress, _cosmosAddress);
        return true;
    }

    /// @notice             Remove existing validator
    /// @param  _ethAddress Address of existing validator to remove
    /// @dev                Possible to execute only by contract itself
    /// @return             Returns boolean depends on success or fail
    function removeValidator(address _ethAddress)
        public
        onlySelf()
        validatorExists(_ethAddress)
        returns (bool)
    {
        require(
            validators.length - 1 > MIN_VALIDATORS,
            "Minimum validators amount reached"
        );

        isValidator[_ethAddress] = false;

        for (uint256 i = 0; i < validators.length - 1; i++) {
            if (validators[i].ethAddress == _ethAddress) {
                validators[i] = validators[validators.length - 1];
                break;
            }
        }

        validators.length -= 1;

        bankStorage.removeActiveValidator(address(uint160(_ethAddress)));

        emit REMOVED_VALIDATOR(_ethAddress);
        return true;
    }

    /// @notice                Internal function for adding validator
    /// @dev                   Done to be able to add validators by this contract internal and itself
    /// @param  _ethAddress    Address of validator
    /// @param  _cosmosAddress Cosmos address of validator
    /// @return                Returns boolean depends on success or fail
    function addValidatorInternal(
        address        _ethAddress,
        bytes   memory _cosmosAddress
    )
        internal
        validatorDoesntExist(_ethAddress)
        returns (bool)
    {
        require(_ethAddress != address(0),  "Validator address is zero");
        require(_cosmosAddress.length != 0,  "Cosmos address is zero");
        require(
            validators.length+1 < MAX_VALIDATORS,
            "Reached maximum validators amount"
        );

        validators.push(Validator({
            ethAddress:    _ethAddress,
            cosmosAddress: _cosmosAddress
        }));
        isValidator[_ethAddress] = true;

        bankStorage.addValidator(address(uint160(_ethAddress)));

        emit ADDED_VALIDATOR(_ethAddress, _cosmosAddress);
        return true;
    }
}

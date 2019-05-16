pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";

contract BankStorage is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    event ADDED_CURRENCY(address indexed _token);
    event DEPOSIT_CURRENCY(address indexed _token, uint256 _amount, uint256 _fee);
    event WITHDRAW_FEE(address indexed _token, uint256 _fee);

    event ADDED_VALIDATOR(address indexed _validator);
    event REMOVED_ACTIVE_VALIDATOR(address indexed _validator);

    address public goverement;
    address public ethTokenAddress;

    struct Currency  {
        uint256 balance;
        uint256 reminder;
    }

    struct Validator {
        address payable account;

        mapping(address => uint256) balances;
    }

    address[] public activeValidators;
    mapping(address => Validator) allValidators;
    mapping(address => bool) isValidator;

    mapping(address => Currency) currencies;
    mapping(address => bool) isCurrency;

    modifier onlyValidator() {
        require(isValidator[msg.sender]);
        _;
    }

    modifier onlyGoverement() {
        require(goverement == msg.sender);
        _;
    }

    constructor(address _goverement, address _ethTokenAddress) public {
        goverement = _goverement;
        ethTokenAddress = _ethTokenAddress;

        addCurrency(_ethTokenAddress);
    }

    function deposit(address _token, uint256 _amount, uint256 _fee) payable public onlyOwner()  {
        if (!isCurrency[_token]) {
            addCurrency(_token);
        }

        Currency storage currency = currencies[_token];
        uint256 totalAmount = _amount.add(_fee);

        if (_token == ethTokenAddress) {
            require(totalAmount == msg.value);
        } else {
            IERC20 token = IERC20(_token);
            require(token.allowance(msg.sender, address(this)) == totalAmount);
            require(token.transferFrom(msg.sender, address(this), totalAmount));
        }

        uint256 amountToSplit = _fee.add(currency.reminder);

        uint256 validatorFee = amountToSplit.div(activeValidators.length);
        uint256 reminder     = amountToSplit.mod(activeValidators.length);

        for (uint256 i = 0; i < activeValidators.length; i++) {
            address validatorAddress = activeValidators[i];

            allValidators[validatorAddress].balances[_token] =
                allValidators[validatorAddress].balances[_token].add(validatorFee);
        }

        currency.reminder = reminder;
        currency.balance.add(_amount);

        emit DEPOSIT_CURRENCY(_token, _amount, _fee);
    }

    function withdrawFee(address _token, uint256 _amount, uint256 _gas) public onlyValidator() nonReentrant() {
        require(isCurrency[_token]);
        require(_gas > 0);

        require(allValidators[msg.sender].balances[_token] <= _amount);

        if (_token == ethTokenAddress) {
            (bool success,) = allValidators[msg.sender].account.call.value(_amount).gas(_gas)("");
            require(success);
        } else {
            IERC20 token = IERC20(_token);

            require(token.transfer(msg.sender, _amount));
        }

        allValidators[msg.sender].balances[_token] =
            allValidators[msg.sender].balances[_token].sub(_amount);

        emit WITHDRAW_FEE(_token, _amount);
    }

    function addValidator(address payable _validator) public onlyGoverement() {
        require(!isValidator[_validator]);

        activeValidators.push(_validator);
        allValidators[_validator] = Validator({
            account: _validator
        });
        isValidator[_validator] = true;

        emit ADDED_VALIDATOR(_validator);
    }

    function removeActiveValidator(address _validator) public onlyGoverement() {
        require(isValidator[_validator]);

        for (uint256 i = 0; i < activeValidators.length; i++) {
            if (activeValidators[i] == _validator) {
                activeValidators[i] = activeValidators[activeValidators.length - 1];
                break;
            }
        }

        activeValidators.length -= 1;

        emit REMOVED_ACTIVE_VALIDATOR(_validator);
    }

    function addCurrency(address _token) internal {
        currencies[_token] = Currency({
            balance:  0,
            reminder: 0
        });

        isCurrency[_token] = true;

        emit ADDED_CURRENCY(_token);
    }
}

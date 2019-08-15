pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";

/// @title Stores ETH and tokens, pays fees to validators, like low level storage
/// @dev   Bridge should be owner of contract
contract BankStorage is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    /// @notice        Happens when new raw currency added
    /// @param  _token Address of token added
    event ADDED_RAW_CURRENCY(address indexed _token);

    /// @notice         Happens during deposit of new currency
    /// @param  _token  Address of token
    /// @param  _amount Amount of currency deposited
    /// @param  _fee    Amount of currency goes to validator
    event DEPOSIT_RAW_CURRENCY(
        address indexed _token,
        uint256 _amount,
        uint256 _fee
    );

    /// @notice        Happens when validator withdraw fee for himself
    /// @param  _token Address of token
    /// @param  _fee   Amount of fee
    event WITHDRAW_FEE(
        address indexed _token,
        uint256 _fee
    );

    /// @notice            Happens when new validator added
    /// @param  _validator Address of validator
    event ADDED_RAW_VALIDATOR(address indexed _validator);

    /// @notice            Happens when active validator removed
    /// @param  _validator Address of validator
    event REMOVED_ACTIVE_VALIDATOR(address indexed _validator);

    /// @notice            Happens when owner withdraw currency for someone
    /// @param  _token     Address of token
    /// @param  _recipient Address of recipient account, who recieve currency
    /// @param  _amount    Amount of currency
    event WITHDRAW_RAW_CURRENCY(
        address indexed _token,
        address indexed _recipient,
        uint256 _amount
    );

    /// @notice                Happens when government contract changes
    /// @param  _oldGovernment Old government contract
    /// @param  _newGovernment New government contracts
    event GOVERNMENT_CHANGED(
        address _oldGovernment,
        address _newGovernment
    );

    /// @notice government contract address
    address public government;

    /// @notice ETH token reserved address (just for compatibility)
    address public ethTokenAddress;

    /// @notice Raw currency structure, contains balance and reminder balance
    struct Currency  {
        uint256 balance;
        uint256 reminder;
    }

    /// @notice Raw validator with balances and account address
    struct Validator {
        address payable account;
        mapping(address => uint256) balances;
    }

    /// @notice Active validators list
    address[] public activeValidators;

    /// @notice Whole validators list
    mapping(address => Validator) allValidators;

    /// @notice Check if address is validator
    mapping(address => bool) isValidator;

    /// @notice Currencies list by token address
    mapping(address => Currency) currencies;

    /// @notice Check if it's currency by token address
    mapping(address => bool) isCurrency;

    /// @notice Allows only validator to call function
    modifier onlyValidator() {
        require(isValidator[msg.sender], "Isnt validator");
        _;
    }

    /// @notice Allows only goveremet to call function
    modifier onlyGovernment() {
        require(government == msg.sender, "Isnt government");
        _;
    }

    ///@notice Empty constructor function
    constructor() public {}

    /// @notice                  Initializing government contract and ETH token address (for compatibility)
    /// @param  _government      Government address
    /// @param  _ethTokenAddress ETH token address (for compatibility)
    function setup(
        address _government,
        address _ethTokenAddress
    )
        public
        onlyOwner()
    {
        require(government  == address(0), "Government address isnt zero");
        require(_government != address(0), "New government address is zero");

        government = _government;
        ethTokenAddress = _ethTokenAddress;

        addCurrency(_ethTokenAddress);
    }

    /// @notice        Deposit tokens/ETH, only by owner
    /// @param _token  Token address
    /// @param _amount Amount of currency to store on contract
    /// @param _fee    Amount of fee for split between validators
    /// @dev           Split fee between validators, if reminder gt 0,
    ///                keep for next time, amount recieved by function should be equal _fee+_amount
    function deposit(
        address _token,
        uint256 _amount,
        uint256 _fee
    )
        payable
        public
        onlyOwner()
    {
        if (!isCurrency[_token]) {
            addCurrency(_token);
        }

        Currency storage currency = currencies[_token];
        uint256 totalAmount = _amount.add(_fee);

        if (_token == ethTokenAddress) {
            require(
                totalAmount == msg.value,
                "Total amount is not equal transaction value"
            );
        } else {
            IERC20 token = IERC20(_token);
            require(
                token.allowance(msg.sender, address(this)) == totalAmount,
                "Token allowed amount is not equal to expected amount"
            );
            require(
                token.transferFrom(msg.sender, address(this), totalAmount),
                "Cant transfer tokens from contract"
            );
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
        currency.balance  = currency.balance.add(_amount);

        emit DEPOSIT_RAW_CURRENCY(_token, _amount, _fee);
    }

    /// @notice            Withdraw tokens/ETH to recipient
    /// @param  _token     Address of token
    /// @param  _recipient Recipient address
    /// @param  _amount    Amount of currency to send to recipient
    /// @param  _gas       Gas limit fallback function (in case recipient is contract)
    function withdraw(
        address _token,
        address payable _recipient,
        uint256 _amount,
        uint256 _gas
    )
        public
        onlyOwner()
        nonReentrant()
    {
        require(isCurrency[_token], "Wrong token address to withdraw");
        require(
            currencies[_token].balance >= _amount,
            "Balance is less then amount to withdraw"
        );
        currencies[_token].balance = currencies[_token].balance.sub(_amount);

        if (_token == ethTokenAddress) {
            (bool success, ) = _recipient.call.value(_amount).gas(_gas)("");
            require(success, "ETH transfer isnt successful");
        } else {
            IERC20 token = IERC20(_token);
            require(
                token.transfer(_recipient, _amount),
                "Token transfer isnt successful"
            );
        }

        emit WITHDRAW_RAW_CURRENCY(_token, _recipient, _amount);
    }

    /// @notice             Get fees collected by validator
    /// @param   _validator Address of validator.
    /// @param   _token     Token address.
    /// @return             Amount of tokens collected by validator.
    function getValidatorFee(
        address _validator,
        address _token
    ) public view returns(uint256) {
        return allValidators[_validator].balances[_token];
    }

    /// @notice         Withdraw fee by validator
    /// @param  _token  Token address
    /// @param  _amount Amount of currency to withdraw
    /// @param  _gas    Gas limit fallback function (in case recipient is contract)
    function withdrawFee(
        address _token,
        uint256 _amount,
        uint256 _gas
    )
        public
        onlyValidator()
        nonReentrant()
    {
        require(isCurrency[_token], "Wrong token address to withdraw fee");

        require(
            allValidators[msg.sender].balances[_token] >= _amount,
            "Not enought fee balance to withdraw"
        );

        if (_token == ethTokenAddress) {
            (bool success,) = allValidators[msg.sender].account.call.value(_amount).gas(_gas)("");
            require(success, "ETH transfer is not successful");
        } else {
            IERC20 token = IERC20(_token);

            require(
                token.transfer(msg.sender, _amount),
                "Token transfer is not successful"
            );
        }

        allValidators[msg.sender].balances[_token] =
            allValidators[msg.sender].balances[_token].sub(_amount);

        emit WITHDRAW_FEE(_token, _amount);
    }

    /// @notice            Adding new validator to list of validators and active validators
    /// @param  _validator Address of validator
    function addValidator(
        address payable _validator
    )
        public
        onlyGovernment()
    {
        require(!isValidator[_validator], "Address is validator already");

        activeValidators.push(_validator);
        allValidators[_validator] = Validator({
            account: _validator
        });
        isValidator[_validator] = true;

        emit ADDED_RAW_VALIDATOR(_validator);
    }

    /// @notice            Removing active validator from active validators list
    /// @param  _validator Address of validator
    function removeActiveValidator(
        address _validator
    )
        public
        onlyGovernment()
    {
        require(isValidator[_validator], "Address is not a validator");

        for (uint256 i = 0; i < activeValidators.length; i++) {
            if (activeValidators[i] == _validator) {
                activeValidators[i] = activeValidators[activeValidators.length - 1];
                break;
            }
        }

        activeValidators.length -= 1;

        emit REMOVED_ACTIVE_VALIDATOR(_validator);
    }

    /// @notice                Change government contract
    /// @param  _newGovernment Address of new goverment contract
    function transferGovernment(
        address _newGovernment
    )
        public
        onlyGovernment()
    {
        government = _newGovernment;
        emit GOVERNMENT_CHANGED(government, _newGovernment);
    }

    /// @notice        Adding new raw currency to currencies list
    /// @param  _token Address of token
    function addCurrency(
        address _token
    )
        internal
    {
        currencies[_token] = Currency({
            balance:  0,
            reminder: 0
        });

        isCurrency[_token] = true;

        emit ADDED_RAW_CURRENCY(_token);
    }
}

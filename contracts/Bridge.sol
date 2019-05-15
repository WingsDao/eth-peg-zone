pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";

/// @title  Bridge contract allowing to exchange ETH and any listed ERC20 token
/// @notice Using fallback function to exchange ETH and 'exchange' function for tokens
/// @dev    Should has some goverement contract as owner
contract Bridge is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    ///@notice                 Happens when new token listed
    ///@param   _tokenContract Contract of token that listed
    ///@param   _currencyId    Id of currency
    event ADDED_CURRENCY(
        address indexed _tokenContract,
        uint256 _currencyId
    );

    ///@notice Happens whenn capacity of currency changed
    ///@param  _currencyId  Id of currency
    ///@param _newCapacity New capacity of currency
    event CHANGED_CAPACITY(
        uint256 indexed _currencyId,
        uint256 _newCapacity
    );

    ///@notice                  Happens when minimum amount of exchange for currency changed
    ///@param   _currencyId     Id of currency
    ///@param   _newMinExchange New minimum amount of currency to exchange
    event CHANGED_MIN_EXCHANGE(
        uint256 indexed _currencyId,
        uint256 _newMinExchange
    );

    ///@notice                   Happens when fee for convertation changed for currency
    ///@param  _currencyId       Id of currency
    ///@param  _newFeePercentage New fee percentage
    event CHANGED_FEE(
        uint256 indexed _currencyId,
        uint256 _newFeePercentage
    );

    ///@notice             Happens when new convertation of currency happend, e.g. ETH -> WETH
    ///@param  _currencyId Id of currency
    ///@param  _spender    Address of account who convert currency
    ///@param  _amount     Amount of currency that will be converted
    event CURRENCY_EXCHANGED(
        uint256 indexed _currencyId,
        address indexed _spender,
        uint256 _amount
    );

    ///@notice             Happens when goverement withdraw currency for converter
    ///@param  _currencyId Id of currency
    ///@param  _recipient  Address of account who will get currency
    ///@param  _amount     Amount of currency
    event CURRENCY_WITHDRAW(
        uint256 indexed _currencyId,
        address indexed _recipient,
        uint256 _amount
    );

    ///@notice Describing currency structure
    struct Currency {
        address tokenContract;
        uint256 minExchange;
        uint256 capacity;
        uint256 feePercentage;
    }

    ///@notice Maximum fee percentage that validators can set, e.g. s9999=99.99%
    uint256 constant public MAX_FEE = 9999;

    ///@notice Detects is contract paused or not
    bool public paused;

    ///@notice Total currencies counts
    uint256 public currenciesCount;

    ///@notice Reserved index for ETH currency
    uint256 public ethIndex;

    ///@notice All currencies list by index
    mapping(uint256 => Currency) currencies;

    ///@notice Token address to currency list
    mapping(address => uint256) tokenToCurrency;

    ///@notice Check if specific token address is currency
    mapping(address => bool) isCurrency;

    ///@notice Should work only if contract is not paused
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    ///@notice Should work only if contract paused
    modifier whenPaused() {
        require(paused);
        _;
    }

    ///@notice             Check if currency exists by id of currency
    ///@param  _currencyId Id of currency
    modifier currencyExistsById(uint256 _currencyId) {
        if (_currencyId != ethIndex) {
            require(currencies[_currencyId].tokenContract != address(0));
        }
        _;
    }

    ///@notice        Check if currency doesn't exist by address of currency token
    ///@param  _token Address of token currency
    modifier currencyDoesntExist(address _token) {
        require(!isCurrency[_token]);
        _;
    }

    ///@notice                   Constructor with basic parameters for ETH exchange
    ///@param  _ethCapacity      Maximum capacity for ETH exchange
    ///@param  _ethMinAmount     Minimum amount of ETH exchange
    ///@param  _ethFeePercentage Percent fee of ETH exchange
    constructor(
        uint256 _ethCapacity,
        uint256 _ethMinAmount,
        uint256 _ethFeePercentage
    )
        public
        Ownable()
    {
        ethIndex = addCurrency(
            address(0),
            _ethCapacity,
            _ethMinAmount,
            _ethFeePercentage
        );
    }

    ///@notice Payable function for ETH convertation
    function () payable external {
        exchange(ethIndex, msg.value);
    }

    ///@notice             Exchanges ETH or any token
    ///@param  _currencyId Id of currency to exchange
    ///@param  _amount     Amount of currency to exchange
    ///@dev                Works only if contract not paused
    function exchange(
        uint256 _currencyId,
        uint256 _amount
    )
        payable
        public
        whenNotPaused()
        currencyExistsById(_currencyId)
    {
        Currency memory currency = currencies[_currencyId];
        convertation(msg.sender, _amount, currency);
    }

    ///@notice             Withdraw currency to recipient, could be called by owner only (goverement)
    ///@param  _currencyId Id of currency
    ///@param  _recipient  Recipient, who will recieve currency
    ///@param  _amount     Amount to withdraw
    ///@param  _gas        Gas limit fallback function (in case recipient is contract)
    ///@dev                   Could be executed only by owner (goverement)
    function withdraw(
        uint256 _currencyId,
        address payable _recipient,
        uint256 _amount,
        uint256 _gas
    )
        public
        onlyOwner()
        whenNotPaused()
        nonReentrant()
        currencyExistsById(_currencyId)
    {
        require(_gas > 0);
        Currency memory currency = currencies[_currencyId];

        require(_amount >= currency.minExchange);

        if (_currencyId == ethIndex) {
            (bool success,) = _recipient.call.value(_amount).gas(_gas)("");
            require(success);

            emit CURRENCY_WITHDRAW(_currencyId, _recipient, _amount);
        } else {
            IERC20 token = IERC20(currency.tokenContract);
            require(token.transfer(_recipient, _amount));

            emit CURRENCY_WITHDRAW(_currencyId, _recipient, _amount);
        }
    }

    ///@notice                Add currency to currecies list
    ///@param  _tokenContract Contract of token
    ///@param  _minExchange   Minimum amount to exchange in case of this currency
    ///@param  _capacity      Maximum capacity of currency in this contract
    ///@param  _feePercentage Fee percentage that validators take for exchange
    ///@dev                   Could be executed only by owner (goverement)
    ///@return                Return id of just added currency
    function addCurrency(
        address _tokenContract,
        uint256 _minExchange,
        uint256 _capacity,
        uint256 _feePercentage
    )
        public
        onlyOwner()
        currencyDoesntExist(_tokenContract)
        returns (uint256)
    {
        require(_minExchange > 0);
        require(_capacity  > 0);
        require(_capacity  >= _minExchange);
        require(_feePercentage > 0);
        require(_feePercentage < MAX_FEE);
        require(tokenToCurrency[_tokenContract] == 0);

        currencies[currenciesCount] = Currency({
            tokenContract: _tokenContract,
            minExchange:   _minExchange,
            capacity:      _capacity,
            feePercentage: _feePercentage
        });

        tokenToCurrency[_tokenContract] = currenciesCount;
        isCurrency[_tokenContract] = true;

        emit ADDED_CURRENCY(_tokenContract, currenciesCount++);

        return currenciesCount;
    }

    ///@notice              Change capacity for specific owner
    ///@param  _currencyId  Id of currency to change
    ///@param  _newCapacity New capacity for provided currency
    ///@dev                 Could be executed only by owner (goverement)
    function changeCapacity(
        uint256 _currencyId,
        uint256 _newCapacity
    )
        public
        onlyOwner()
        currencyExistsById(_currencyId)
    {
        require(_newCapacity > 0);
        require(_newCapacity >= currencies[_currencyId].minExchange);

        currencies[_currencyId].capacity = _newCapacity;
        emit CHANGED_CAPACITY(_currencyId, _newCapacity);
    }

    ///@notice                Change minimum amount to exchange for specific currency
    ///@param _currencyId     Id of currency to change
    ///@param _newMinExchange New minimum amount of currency to exchange
    ///@dev                   Could be executed only by owner (goverement)
    function changeMinExchange(
        uint256 _currencyId,
        uint256 _newMinExchange
    )
        public
        onlyOwner()
        currencyExistsById(_currencyId)
    {
        require(_newMinExchange > 0);
        require(_newMinExchange <= currencies[_currencyId].capacity);

        currencies[_currencyId].minExchange = _newMinExchange;
        emit CHANGED_MIN_EXCHANGE(_currencyId, _newMinExchange);
    }

    ///@notice                   Change fee percentage for specific currency
    ///@param  _currencyId       Id of currency to change
    ///@param  _newFeePercentage New fee percentage for exchange provided currency
    ///@dev                      Could be executed only by owner (goverement)
    function changeFee(
        uint256 _currencyId,
        uint256 _newFeePercentage
    )
        public
        onlyOwner()
        currencyExistsById(_currencyId)
    {
        require(_newFeePercentage > 0);
        require(_newFeePercentage < MAX_FEE);

        currencies[_currencyId].feePercentage = _newFeePercentage;

        emit CHANGED_FEE(_currencyId, _newFeePercentage);
    }

    ///@notice Pause contract, widthraw and exchange will be paused
    ///@dev    Could be executed only by owner (goverement)
    function pause() public onlyOwner() {
        paused = true;
    }

    ///@notice Resume contract, indeed withdraw and exchange
    ///@dev    Could be executed only by owner (goverement)
    function resume() public onlyOwner() {
        paused = false;
    }

    ///@notice          Convertation function for ETH and tokens
    ///@param _spender  Address of account who spend ETH/tokens
    ///@param _amount   Amount to convert
    ///@param _currency Currency to convert
    ///@dev             Internal function
    function convertation(
        address _spender,
        uint256 _amount,
        Currency memory _currency
    )
        internal
    {
        require(_amount >= _currency.minExchange);
        uint256 currencyId = tokenToCurrency[_currency.tokenContract];

        if (currencyId == ethIndex) {
            require(msg.value == _amount);
            require(address(this).balance.add(_amount) <= _currency.capacity);

            emit CURRENCY_EXCHANGED(currencyId, _spender, _amount);
        } else {
            IERC20 token = IERC20(_currency.tokenContract);

            require(token.balanceOf(address(this)).add(_amount) <= _currency.capacity);
            require(token.allowance(_spender, address(this)) >= _amount);
            require(token.transferFrom(_spender, address(this), _amount));

            emit CURRENCY_EXCHANGED(currencyId, _spender, _amount);
        }
    }
}

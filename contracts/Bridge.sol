pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";

contract Bridge is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    event ADDED_CURRENCY(address indexed _tokenContract, uint256 _currencyId);
    event CHANGED_CAPACITY(uint256 indexed _currencyId, uint256 _newCapacity);
    event CHANGED_MIN_EXCHANGE(uint256 indexed _currencyId, uint256 _newMinExchange);
    event CHANGED_FEE(uint256 indexed _currencyId, uint256 _newFee);

    event CURRENCY_EXCHANGED(uint256 indexed _currencyId, address indexed _spender, uint256 _amount);
    event CURRENCY_WITHDRAW(uint256 indexed _currencyId, address indexed _recipient, uint256 _amount);

    struct Currency {
        address tokenContract;
        uint256 minExchange;
        uint256 capacity;
        uint256 feePercentage;
    }

    uint256 constant public MAX_FEE = 9999;

    bool public paused;

    uint256 public currenciesCount;
    uint256 public ethIndex;

    mapping(uint256 => Currency) currencies;
    mapping(address => uint256)  tokenToCurrency;
    mapping(address => bool) isToken;

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused() {
        require(paused);
        _;
    }

    modifier currencyExistsById(uint256 _currencyId) {
        if (_currencyId != ethIndex) {
            require(currencies[_currencyId].tokenContract != address(0));
        }
        _;
    }

    modifier currencyDoesntExist(address _token) {
        require(!isToken[_token]);
        _;
    }

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

    function () payable external {
        exchange(ethIndex, msg.value);
    }

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
        isToken[_tokenContract] = true;

        emit ADDED_CURRENCY(_tokenContract, currenciesCount++);

        return currenciesCount;
    }

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

    function pause() public onlyOwner() {
        paused = true;
    }

    function resume() public onlyOwner() {
        paused = false;
    }

    function convertation(
        address _spender,
        uint256 _amount,
        Currency memory currency
    )
        internal
    {
        require(_amount >= currency.minExchange);
        uint256 currencyId = tokenToCurrency[currency.tokenContract];

        if (currencyId == ethIndex) {
            require(msg.value == _amount);
            require(address(this).balance.add(_amount) <= currency.capacity);

            emit CURRENCY_EXCHANGED(currencyId, _spender, _amount);
        } else {
            IERC20 token = IERC20(currency.tokenContract);

            require(token.balanceOf(address(this)).add(_amount) <= currency.capacity);
            require(token.allowance(_spender, address(this)) >= _amount);
            require(token.transferFrom(_spender, address(this), _amount));

            emit CURRENCY_EXCHANGED(currencyId, _spender, _amount);
        }
    }
}

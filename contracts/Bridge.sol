pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";

import "./BankStorage.sol";

/// @title  Bridge contract allowing to exchange ETH and any listed ERC20 token. Owner should be government
/// @notice Using fallback function to exchange ETH and 'exchange' function for tokens
/// @dev    Should has some government contract as owner, 0x000... address reserved for ETH
contract Bridge is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    /// @notice                 Happens when new token listed
    /// @param   _tokenContract Contract of token that listed
    /// @param   _currencyId    Id of currency
    /// @param   _decimals      Currency decimals
    /// @param   _symbol        Currency symbol
    event ADDED_CURRENCY(
        address indexed _tokenContract,
        uint256 _currencyId,
        uint8   _decimals,
        string  _symbol
    );

    /// @notice Happens whenn capacity of currency changed
    /// @param  _currencyId  Id of currency
    /// @param _newCapacity New capacity of currency
    event CHANGED_CAPACITY(
        uint256 indexed _currencyId,
        uint256 _newCapacity
    );

    /// @notice                  Happens when minimum amount of exchange for currency changed
    /// @param   _currencyId     Id of currency
    /// @param   _newMinExchange New minimum amount of currency to exchange
    event CHANGED_MIN_EXCHANGE(
        uint256 indexed _currencyId,
        uint256 _newMinExchange
    );

    /// @notice                   Happens when fee for convertation changed for currency
    /// @param  _currencyId       Id of currency
    /// @param  _newFeePercentage New fee percentage
    event CHANGED_FEE(
        uint256 indexed _currencyId,
        uint256 _newFeePercentage
    );

    /// @notice             Happens when new convertation of currency happend, e.g. ETH -> WETH
    /// @param  _currencyId Id of currency
    /// @param  _spender    Address of account who convert currency
    /// @param  _id         Id of exchange
    /// @param  _amount     Amount of currency that will be converted
    event CURRENCY_EXCHANGED(
        uint256 indexed _currencyId,
        address indexed _spender,
        bytes32 indexed _recipient,
        uint256 _id,
        uint256 _amount
    );

    /// @notice             Happens when government withdraw currency for converter
    /// @param  _currencyId Id of currency
    /// @param  _recipient  Address of account who will get currency
    /// @param  _sender     Account who initiated withdraw in WB.
    /// @param  _withdrawId Id of withdraw.
    /// @param  _amount     Amount of currency
    event CURRENCY_WITHDRAW(
        uint256 indexed _currencyId,
        address indexed _recipient,
        bytes32 _sender,
        uint256 _withdrawId,
        uint256 _amount
    );

    /// @notice Describing currency structure
    struct Currency {
        address tokenContract;
        string  symbol;
        uint256 minExchange;
        uint256 capacity;
        uint256 feePercentage;
        uint256 balance;
        uint8   decimals;
    }

    /// @notice Withdraw struct describes all withdraws.
    struct Withdraw {
        uint256 currencyId;
        address recipient;
        bytes32 sender;
        uint256 withdrawId;
        uint256 amount;
    }

    /// @notice Bank storage address
    BankStorage public bankStorage;

    /// @notice Maximum fee percentage that validators can set, e.g. 9999=99.99%
    uint256 constant public MAX_FEE = 9999;

    /// @notice Detects is contract paused or not
    bool public paused;

    /// @notice Exchange id
    uint256 public exchangeId;

    /// @notice Total currencies counts
    uint256 public currenciesCount;

    /// @notice Reserved index for ETH currency
    uint256 public ethIndex;

    /// @notice All currencies list by index
    mapping(uint256 => Currency) public currencies;

    /// @notice Token address to currency list
    mapping(address => uint256) public tokenToCurrency;

    /// @notice Check if specific token address is currency
    mapping(address => bool) public isCurrency;

    /// @notice Withdraws by ids.
    mapping(uint256 => Withdraw) public withdraws;

    /// @notice Is it exist withdraw.
    mapping(uint256 => bool) public isWithdraw;

    /// @notice Should work only if contract is not paused
    modifier whenNotPaused() {
        require(!paused, "Contract isnt paused");
        _;
    }

    /// @notice Should work only if contract paused
    modifier whenPaused() {
        require(paused, "Contract is paused");
        _;
    }

    /// @notice             Check if currency exists by id of currency
    /// @param  _currencyId Id of currency
    modifier currencyExistsById(uint256 _currencyId) {
        if (_currencyId != ethIndex) {
            require(
                currencies[_currencyId].tokenContract != address(0),
                "Currency doesnt exist if check by id"
            );
        }
        _;
    }

    /// @notice        Check if currency doesn't exist by address of currency token
    /// @param  _token Address of token currency
    modifier currencyDoesntExist(address _token) {
        require(
            !isCurrency[_token],
            "Currency doesnt exist"
        );
        _;
    }

    /// @notice                   Constructor with basic parameters for ETH exchange
    /// @param  _ethCapacity      Maximum capacity for ETH exchange
    /// @param  _ethMinAmount     Minimum amount of ETH exchange
    /// @param  _ethFeePercentage Percent fee of ETH exchange
    /// @param  _bankStorage      Address of bank storage contract
    /// @dev                      Move bank storage owner to this contract after initialization
    constructor(
        uint256 _ethCapacity,
        uint256 _ethMinAmount,
        uint256 _ethFeePercentage,
        address _bankStorage
    )
        public
    {
        require(_bankStorage != address(0), "Empty bank storage");

        bankStorage = BankStorage(_bankStorage);

        ethIndex = addCurrency(
            address(0),
            "eth",
            18,
            _ethCapacity,
            _ethMinAmount,
            _ethFeePercentage
        );
    }

    /// @notice             Exchanges ETH or any token
    /// @param  _currencyId Id of currency to exchange
    /// @param  _recipient  Cosmos address to recieve currency
    /// @param  _amount     Amount of currency to exchange
    /// @dev                Works only if contract not paused
    function exchange(
        uint256 _currencyId,
        bytes32 _recipient,
        uint256 _amount
    )
        payable
        public
        whenNotPaused()
        currencyExistsById(_currencyId)
    {
        Currency storage currency = currencies[_currencyId];
        convertation(msg.sender, _recipient, _amount, currency);
    }

    /// @notice             Withdraw currency to recipient, could be called by owner only (government)
    /// @param  _currencyId Id of currency
    /// @param  _withdrawId Id of withdraw.
    /// @param  _sender     Account who initiated withdraw in WB.
    /// @param  _recipient  Recipient, who will recieve currency
    /// @param  _amount     Amount to withdraw
    /// @param  _gas        Gas limit fallback function (in case recipient is contract)
    function withdraw(
        uint256 _currencyId,
        uint256 _withdrawId,
        bytes32 _sender,
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
        Currency storage currency = currencies[_currencyId];

        require(_amount >= currency.minExchange, "Amount should be great or equal then min exchange");
        require(!isWithdraw[_withdrawId], "Withdraw already initiated");

        currency.balance = currency.balance.sub(_amount);
        bankStorage.withdraw(currency.tokenContract, _recipient, _amount, _gas);

        withdraws[_withdrawId] = Withdraw({
            currencyId: _currencyId,
            recipient:  _recipient,
            sender:     _sender,
            withdrawId: _withdrawId,
            amount:     _amount
        });
        isWithdraw[_withdrawId] = true;

        emit CURRENCY_WITHDRAW(_currencyId, _recipient, _sender, _withdrawId, _amount);
    }

    /// @notice           We migrate bank storage to new owner
    /// @param  _newOwner Address of new owner for bank storage
    /// @dev              This is very basic migration, allowing to change owner of bank storage
    function migration(address _newOwner) public onlyOwner() {
        bankStorage.transferOwnership(_newOwner);
    }

    /// @notice                Add currency to currecies list
    /// @param  _tokenContract Contract of token
    /// @param  _symbol        Currency symbol
    /// @param  _minExchange   Minimum amount to exchange in case of this currency
    /// @param  _capacity      Maximum capacity of currency in this contract
    /// @param  _feePercentage Fee percentage that validators take for exchange
    /// @return                Return id of just added currency
    function addCurrency(
        address        _tokenContract,
        string  memory _symbol,
        uint8          _decimals,
        uint256        _capacity,
        uint256        _minExchange,
        uint256        _feePercentage
    )
        public
        onlyOwner()
        currencyDoesntExist(_tokenContract)
        returns (uint256)
    {
        require(_minExchange > 0, "Min exchange equal 0");
        require(_capacity  > 0, "Capacity equal 0");
        require(_capacity  >= _minExchange, "Min exchange great or equal then capacity");
        require(_feePercentage > 0, "Fee equal 0");
        require(_feePercentage < MAX_FEE, "Fee great then max fee");
        require(bytes(_symbol).length > 0, "Symbol is empty");

        uint256 index = currenciesCount;
        currencies[index] = Currency({
            tokenContract: _tokenContract,
            symbol:        _symbol,
            minExchange:   _minExchange,
            capacity:      _capacity,
            feePercentage: _feePercentage,
            balance:       0,
            decimals:      _decimals
        });

        tokenToCurrency[_tokenContract] = currenciesCount;
        isCurrency[_tokenContract] = true;

        emit ADDED_CURRENCY(_tokenContract, index, _decimals, _symbol);

        currenciesCount++;
        return index;
    }

    /// @notice              Change capacity for specific owner
    /// @param  _currencyId  Id of currency to change
    /// @param  _newCapacity New capacity for provided currency
    function changeCapacity(
        uint256 _currencyId,
        uint256 _newCapacity
    )
        public
        onlyOwner()
        currencyExistsById(_currencyId)
    {
        require(_newCapacity > 0, "New capacity should be great then 0");
        require(
            _newCapacity >= currencies[_currencyId].minExchange,
            "New capacity should be great or equal then min exchange"
        );
        require(
            _newCapacity >= currencies[_currencyId].balance,
            "Capacity cant be great then current balance"
        );

        currencies[_currencyId].capacity = _newCapacity;
        emit CHANGED_CAPACITY(_currencyId, _newCapacity);
    }

    /// @notice                Change minimum amount to exchange for specific currency
    /// @param _currencyId     Id of currency to change
    /// @param _newMinExchange New minimum amount of currency to exchange
    function changeMinExchange(
        uint256 _currencyId,
        uint256 _newMinExchange
    )
        public
        onlyOwner()
        currencyExistsById(_currencyId)
    {
        require(_newMinExchange > 0, "Min exchange should be great then 0");
        require(
            _newMinExchange <= currencies[_currencyId].capacity,
            "Min exchange should be less or equal then capacity"
        );

        currencies[_currencyId].minExchange = _newMinExchange;
        emit CHANGED_MIN_EXCHANGE(_currencyId, _newMinExchange);
    }

    /// @notice                   Change fee percentage for specific currency
    /// @param  _currencyId       Id of currency to change
    /// @param  _newFeePercentage New fee percentage for exchange provided currency
    function changeFee(
        uint256 _currencyId,
        uint256 _newFeePercentage
    )
        public
        onlyOwner()
        currencyExistsById(_currencyId)
    {
        require(_newFeePercentage > 0, "Fee percentage should be great then 0");
        require(
            _newFeePercentage < MAX_FEE,
            "Fee percentage should be less then max fee"
        );

        currencies[_currencyId].feePercentage = _newFeePercentage;

        emit CHANGED_FEE(_currencyId, _newFeePercentage);
    }

    /// @notice Pause contract, widthraw and exchange will be paused
    function pause() public onlyOwner() {
        paused = true;
    }

    /// @notice Resume contract, indeed withdraw and exchange
    function resume() public onlyOwner() {
        paused = false;
    }

    /// @notice              Get fee for specific currency and amount
    /// @param  _currencyId  Id of currency
    /// @param  _amount      Amount of currency to calculate fee
    /// @return             Fee amount
    function getFee(
        uint256 _currencyId,
        uint256 _amount
    )
        public
        view
        returns (uint256)
    {
        uint256 feePercentage = currencies[_currencyId].feePercentage;
        return _amount * feePercentage / (MAX_FEE+1);
    }

    /// @notice Returns ETH fake token address (e.g. 0x0000...), just for compatibility
    /// @return ETH token address
    function getEthTokenAddress()
        public
        view
        returns (address)
    {
        return currencies[ethIndex].tokenContract;
    }

    /// @notice           Convertation function for ETH and tokens
    /// @param _spender   Address of account who spend ETH/token
    /// @param _recipient Recipient address (bech32)
    /// @param _amount    Amount to convert
    /// @param _currency  Currency to convert
    /// @dev              Internal function
    function convertation(
        address _spender,
        bytes32 _recipient,
        uint256 _amount,
        Currency storage _currency
    )
        internal
    {
        uint256 currencyId = tokenToCurrency[_currency.tokenContract];

        uint256 fee = getFee(currencyId, _amount);
        uint256 realValue = _amount.sub(fee);

        require(
            realValue >= _currency.minExchange,
            "Amount should be great or equal then min exchage"
        );

        require(
            _currency.balance.add(realValue) <= _currency.capacity,
            "Cant convert ETH/tokens because of capacity"
        );

        _currency.balance = _currency.balance.add(realValue);

        if (currencyId == ethIndex) {
            require(msg.value == _amount, "Amount not equal to ETH value");

            (bool success, ) = address(bankStorage)
                .call
                .value(_amount)
                .gas(600000)(
                    abi.encodeWithSignature(
                        "deposit(address,uint256,uint256)",
                        _currency.tokenContract,
                        realValue,
                        fee
                    )
                );

            require(success, "ETH transfer is not successful");
        } else {
            IERC20 token = IERC20(_currency.tokenContract);

            require(
                token.allowance(_spender, address(this)) >= _amount,
                "Token allowed amount is not equal to expected amount"
            );

            require(
                token.transferFrom(_spender, address(this), _amount),
                "Token transfer is not successful"
            );

            require(
                token.approve(address(bankStorage), _amount),
                "Cant approve approve transfer of tokens for BankStorage"
            );

            bankStorage.deposit(
                _currency.tokenContract,
                realValue,
                fee
            );
        }

        emit CURRENCY_EXCHANGED(currencyId, _spender, _recipient, exchangeId++, realValue);
    }
}

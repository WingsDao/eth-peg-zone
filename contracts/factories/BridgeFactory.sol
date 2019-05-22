pragma solidity ^0.5.8;

import "./IFactory.sol";
import "./BankStorageFactory.sol";
import "./PoAGovernmentFactory.sol";
import "../Bridge.sol";

/// @title  Factory to create new Bridge with PoAGoverment and BankStorage
/// @notice Using this factory to create Bridge and the rest of contracts
/// @dev    Created & using to split contracts creations and save gas limits
contract BridgeFactory is IFactory {
    /// @notice          Happens when new BankStorage contract created for instance
    //  @param  _owner   Owner of instance
    /// @param  _index   Index of just created instance
    /// @param  _storage Storage address
    event NEW_STORAGE(
        address indexed _owner,
        uint256 _index,
        address _storage
    );

    /// @notice          Happens when new PoA contract created for instance
    //  @param  _owner   Owner of instance
    /// @param  _index   Index of instance
    /// @param  _poa     PoA Government address
    event NEW_POA(
        address indexed _owner,
        uint256 _index,
        address _poa
    );

    /// @notice          Happens when new Bridge contract created for instance
    //  @param  _owner   Owner of instance
    /// @param  _index   Index of just created instance
    /// @param  _bridge  Bridge address
    event NEW_BRIDGE(
        address indexed _owner,
        uint256 _index,
        address _bridge
    );

    /// @notice Address of BankStorage factory
    BankStorageFactory   public storageFactory;

    /// @notice Address of PoA Government factory
    PoAGovernmentFactory public poaFactory;

    /// @notice Struct for new Bridge instances
    struct Instance {
        address poa;
        address bankStorage;
        address bridge;

        bool ready;
    }

    /// @notice Mapping of all new instances by owner and by index
    mapping(address => mapping(uint256 => Instance)) instances;

    /// @notice Amount of instances per user
    mapping(address => uint256) byUser;

    /// @notice        Check if instance already exists by owner and index
    /// @param  _owner Owner of exchange
    /// @param  _index Index of exchange
    modifier instanceExists(address _owner, uint256 _index) {
        require(
            instances[_owner][_index].bankStorage != address(0),
            "Instance doesnt exist"
        );
        _;
    }

    /// @notice                 Constructor of factory, initialize required factories
    /// @param  _storageFactory Address of BankStorage factory
    /// @param  _poaFactory     Address of PoA Government factory
    constructor(
        address _storageFactory,
        address _poaFactory
    )
        public
    {
        storageFactory = BankStorageFactory(_storageFactory);
        poaFactory     = PoAGovernmentFactory(_poaFactory);
    }

    /// @notice Create bank storage and new instance
    /// @dev    Should be done as first call to create initial instance before we create PoA & Bridge
    /// @return Returns index of new created exchange and address of bank storage contract
    function createBankStorage() public returns (uint256, address) {
        address storageAddress = storageFactory.create(address(this));

        instances[msg.sender][++byUser[msg.sender]] = Instance({
            bankStorage: storageAddress,
            poa:         address(0),
            bridge:      address(0),
            ready:       false
        });

        emit NEW_STORAGE(msg.sender, byUser[msg.sender], storageAddress);
        return (byUser[msg.sender], storageAddress);
    }

    /// @notice                   Create bridge contract for bridge new instance
    /// @dev                      Step 2, should be executed after bank storage creation
    /// @param  _ethCapacity      Maximum ETH capacity for Bridge
    /// @param  _ethMinAmount     Minimum ETH amount to exchange
    /// @param  _ethFeePercentage Validator fee percentage for ETH currency
    /// @return                   Address of created bridge contract
    function createBridge(
        uint256 _ethCapacity,
        uint256 _ethMinAmount,
        uint256 _ethFeePercentage,
        uint256 _index
    )
        public
        instanceExists(msg.sender, _index)
        returns (address)
    {
        require(
            instances[msg.sender][_index].bridge == address(0),
            "Bridge contract already initialized"
        );

        Bridge bridge = new Bridge(
            _ethCapacity,
            _ethMinAmount,
            _ethFeePercentage,
            instances[msg.sender][_index].bankStorage
        );

        instances[msg.sender][_index].bridge = address(bridge);

        emit NEW_BRIDGE(msg.sender, _index, address(bridge));

        return address(0);
    }

    /// @notice         Create PoA contract for new bridge instance
    /// @dev            Step 3, should be executed after Bridge creation
    /// @param   _index Index of instance
    /// @return         Address of POA Government contract
    function createPoA(
        uint256 _index
    )
        public
        instanceExists(msg.sender, _index)
        returns (address)
    {
        require(
            instances[msg.sender][_index].poa == address(0),
            "PoA contract already created"
        );

        address poaAddress = poaFactory.create(
            address(this),
            instances[msg.sender][_index].bridge,
            instances[msg.sender][_index].bankStorage
        );

        instances[msg.sender][_index].poa = poaAddress;

        emit NEW_POA(msg.sender, _index, poaAddress);

        return poaAddress;
    }

    /// @notice              Building and connecting all created contracts to make it work
    /// @dev                 Stage 4, should be executed after all contracts created
    /// @param   _validators List of validators for PoA Government
    /// @param  _index       Index of instance
    /// @return              Address of Brdige contract
    function build(
        address[] memory _validators,
        uint256 _index
    )
        public
        instanceExists(msg.sender, _index)
    {
        Instance storage instance = instances[msg.sender][_index];
        require(!instance.ready, "Instance already initialized");

        PoAGovernment government = PoAGovernment(instance.poa);
        BankStorage bankStorage  = BankStorage(instance.bankStorage);
        Bridge bridge            = Bridge(address(uint160(instance.bridge)));

        bankStorage.setup(address(government), bridge.getEthTokenAddress());
        bankStorage.transferOwnership(address(bridge));

        government.setup(_validators);
        bridge.transferOwnership(address(government));

        instance.ready = true;

        emit NEW_INSTANCE(address(bridge));
    }

    /// @notice        Get instances amount by owner address
    /// @param  _owner Address of instances owner
    /// @return        Amount of instances created by owner
    function getCount(address _owner) public view returns (uint256) {
        return byUser[_owner];
    }

    /// @notice        Get instance by owner address and index
    /// @param  _owner Address of owner
    /// @param  _index Index of instance
    /// @return        Return address of bridge, bank storage and poa contracts
    function getInstance(
        address _owner,
        uint256 _index
    )
        public
        view
        returns (address, address, address, bool)
    {
        Instance memory instance = instances[_owner][_index];

        return (
            instance.bridge,
            instance.bankStorage,
            instance.poa,
            instance.ready
        );
    }
}

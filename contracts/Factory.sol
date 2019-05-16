pragma solidity ^0.5.8;

import "./PoAGoverement.sol";
import "./BankStorage.sol";
import "./Bridge.sol";

/// @title Factory to create new bridge with PoAGoverment
contract Factory {
    /// @notice             Happens when new instance of storage, goverement and bridge created
    /// @param  _bridge     Address of created Bridge contract
    /// @param  _goverement Address of created PoAGoverment contract
    /// @param  _storage    Address of created storage contract
    event NEW_INSTANCE(
        address _bridge,
        address _goverement,
        address _storage
    );

    /// @notice                   Create new bridge with PoA
    /// @param  _validators       List of validators
    /// @param  _ethCapacity      Maximum capacity for ETH exchange
    /// @param  _ethMinAmount     Minimum amount of ETH exchange
    /// @param  _ethFeePercentage Percent fee of ETH exchange
    function createBridgeWithPoA(
        address[] memory _validators,
        uint256 _ethCapacity,
        uint256 _ethMinAmount,
        uint256 _ethFeePercentage
    )
        public
    {
        BankStorage store = new BankStorage();
        Bridge bridge = new Bridge(
            _ethCapacity,
            _ethMinAmount,
            _ethFeePercentage,
            address(store)
        );

        PoAGoverement goverement = new PoAGoverement(
            _validators,
            address(bridge),
            address(store)
        );

        store.setup(address(goverement), bridge.getEthTokenAddress());
        store.transferOwnership(address(bridge));

        bridge.transferOwnership(address(goverement));

        emit NEW_INSTANCE(address(bridge), address(goverement), address(store));
    }
}

pragma solidity ^0.5.8;

import "./IFactory.sol";
import "../PoAGovernment.sol";

/// @title Factory for PoA Government creation
contract PoAGovernmentFactory is IFactory {
    /// @notice              Create PoA Goverement instance
    /// @param  _owner       Address of owner of new instance
    /// @param  _target      Target address for PoA
    /// @param  _bankStorage Address of BankStorage contract instance
    /// @return              Address of new PoAGovernment instance
    function create(
        address _owner,
        address _target,
        address _bankStorage
    )
        public
        returns (address)
    {
        PoAGovernment poa = new PoAGovernment(
            _target,
            _bankStorage
        );

        poa.transferOwnership(_owner);

        emit NEW_INSTANCE(address(poa));

        return address(poa);
    }
}

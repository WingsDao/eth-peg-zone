pragma solidity ^0.5.8;

import "./IFactory.sol";
import "../BankStorage.sol";

/// @title Factory for bank storage creation
contract BankStorageFactory is IFactory {
    /// @notice        Create new BankStorage instance
    /// @param  _owner Owner address of new contract
    /// @return        Address of new BankStorage instance
    function create(
        address _owner
    )
        public
        returns (address)
    {
        BankStorage bankStorage = new BankStorage();
        bankStorage.transferOwnership(_owner);

        emit NEW_INSTANCE(address(bankStorage));

        return address(bankStorage);
    }
}

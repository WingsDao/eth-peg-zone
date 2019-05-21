pragma solidity ^0.5.8;

/// @title Base iterface for factories
interface IFactory {
    /// @notice           Happens when new instance created
    /// @param  _instance Instance address
    event NEW_INSTANCE(
        address _instance
    );
}

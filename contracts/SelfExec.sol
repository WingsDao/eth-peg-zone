pragma solidity ^0.5.1;

/// @title  Helper to allow call functions only by contract itself
/// @notice Use if you want to allow execute function only by contract itself
/// @dev    Inherit this interface to contract
contract SelfExec {
    modifier onlySelf() {
        require(msg.sender == address(this));
        _;
    }
}

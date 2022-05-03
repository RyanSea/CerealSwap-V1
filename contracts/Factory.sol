//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

import {Exchange} from "./Exchange.sol";

contract Factory {
    /// @notice token address => exchange address
    mapping(address => address) public exchange;

    function createExchange(address token) public returns (address _exchange) {
        require(token != address(0), "INVALID_TOKEN_ADDRESS!");
        require(exchange[token] == address(0), "EXCHANGE_EXISTS!");

        _exchange = address(new Exchange(ERC20(token)));

        exchange[token] = _exchange;
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./Exchange.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Factory {

    /// @notice token address => exchange address
    mapping(address => address) public exchange;

    function createExchange(ERC20 token) public returns (address exchange_address) {
        address token_address = address(token);
        // Check that token is a valid address and it has no exchange
        require(token_address != address(0), "INVALID_ADDRESS");
        require(exchange[token_address] == address(0), "EXCHANGE_EXISTS");

        Exchange _exchange = new Exchange(token);
        exchange_address = address(_exchange);
        exchange[token_address] = exchange_address;
    }

    function getExchange(address token_address) public view returns (address exchange_address) {
        require(token_address != address(0), "INVALID_ADDRESS");
        exchange_address = exchange[token_address];
    }

}
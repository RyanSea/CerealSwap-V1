//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract Token is ERC20 {

    constructor(string memory _name, string memory _symbol) ERC20 (
        _name,
        _symbol, 
        18
    ) {
        _mint(msg.sender, 10000000 * 10 ** 18);
    }

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }

}
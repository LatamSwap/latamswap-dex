// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_, decimals_) {
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }       
}
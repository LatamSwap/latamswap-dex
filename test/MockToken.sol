// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "Mock", 18) {}

    function test() public { /* to remove from coverage */ }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}

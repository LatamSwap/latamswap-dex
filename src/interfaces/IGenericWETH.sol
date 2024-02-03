// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

interface IGenericWETH {
    function withdraw(uint256 amount) external;
    function deposit() external payable;
}

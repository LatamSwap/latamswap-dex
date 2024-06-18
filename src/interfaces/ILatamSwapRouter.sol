// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {IUniswapV2Router02} from "./IUniswapV2Router02.sol";

interface ILatamSwapRouter is IUniswapV2Router02 {
    error ErrExpired();
    error ErrInsufficientQuoteA();
    error ErrInsufficientAmountA();
    error ErrInsufficientAmountB();
    error ErrInsufficientOutputAmount();
    error ErrExcessiveInputAmount();
    error ErrInvalidPath();

    function NATIVO() external returns (address);

    function addLiquidityTokenA(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

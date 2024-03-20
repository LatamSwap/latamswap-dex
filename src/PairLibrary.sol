// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {CREATE3} from "solady/utils/CREATE3.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {PairV2} from "./PairV2.sol";

library PairLibrary {
    using FixedPointMathLib for uint256;

    error ErrZeroAddress();
    error ErrIdenticalAddress();
    error ErrInsufficientAmount();
    error ErrInsufficientLiquidity();
    error ErrInsufficientInputAmount();
    error ErrInsufficientOutputAmount();
    error ErrInvalidPath();

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert ErrIdenticalAddress();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ErrZeroAddress();
    }

    // calculates the CREATE3 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (tokenA, tokenB) = sortTokens(tokenA, tokenB);

        pair = CREATE3.getDeployed(keccak256(abi.encodePacked(tokenA, tokenB)), factory);
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        IUniswapV2Pair pair = IUniswapV2Pair(CREATE3.getDeployed(keccak256(abi.encodePacked(token0, token1)), factory));
        (uint112 _reserve0, uint112 _reserve1,) = pair.getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
    }

    // fetches and sorts the reserves for a pair
    function getReservesAndPair(address factory, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB, address pair)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        pair = CREATE3.getDeployed(keccak256(abi.encodePacked(token0, token1)), factory);
        (uint112 _reserve0, uint112 _reserve1,) = IUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
    }

    // fetches and sorts the reserves for a pair
    function getReservesPair(address pair, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        (uint112 _reserve0, uint112 _reserve1,) = IUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        if (amountA == 0) revert ErrInsufficientAmount();
        if (reserveB == 0) revert ErrInsufficientLiquidity();

        amountB = amountA.mulDiv(reserveB, reserveA);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ErrInsufficientInputAmount();
        if (reserveIn == 0 || reserveOut == 0) revert ErrInsufficientLiquidity();
        uint256 amountInWithFee = amountIn * 997;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = reserveOut.mulDiv(amountInWithFee, denominator);
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        if (amountOut == 0) revert ErrInsufficientOutputAmount();
        if (reserveIn == 0 || reserveOut == 0) revert ErrInsufficientLiquidity();

        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = reserveIn.mulDiv(amountOut * 1000, denominator) + 1;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint256 amountIn, address[] calldata path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (path.length < 2) revert ErrInvalidPath();
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        unchecked {
            uint256 pathLengthSub1 = path.length - 1;
            for (uint256 i; i < pathLengthSub1; ++i) {
                (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i], path[i + 1]);
                amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
            }
        }
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOutAndPairs(address factory, uint256 amountIn, address[] calldata path)
        internal
        view
        returns (uint256[] memory amounts, address[] memory pairs)
    {
        if (path.length < 2) revert ErrInvalidPath();
        amounts = new uint256[](path.length);
        pairs = new address[](path.length);
        amounts[0] = amountIn;
        unchecked {
            uint256 pathLengthSub1 = path.length - 1;
            pairs[0] = pairFor(factory, path[0], path[1]);
            for (uint256 i; i < pathLengthSub1; ++i) {
                (uint256 reserveIn, uint256 reserveOut, address pair) = getReservesAndPair(factory, path[i], path[i + 1]);
                amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
                pairs[i + 1] = pair;
            }
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint256 amountOut, address[] calldata path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (path.length < 2) revert ErrInvalidPath();
        amounts = new uint256[](path.length);
        unchecked {
            amounts[amounts.length - 1] = amountOut;
            address pair = pairFor(factory, path[path.length - 2], path[path.length - 1]);
            for (uint256 i = path.length - 1; i > 0; --i) {
                (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i - 1], path[i]);
                amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
            }
        }
    }
}

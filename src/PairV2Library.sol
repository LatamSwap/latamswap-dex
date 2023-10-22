pragma solidity ^0.8.0;

import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {Create2} from "openzeppelin/utils/Create2.sol";

import {PairV2} from "./PairV2.sol";

library PairV2Library {
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Library: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    // @dev token must be sorted!
    function pairFor(address factory, address token0, address token1) internal pure returns (address pair) {
        (token0, token1) = PairV2Library.sortTokens(token0, token1);
        bytes memory params = abi.encode(token0, token1);
        bytes memory bytecode = abi.encodePacked(type(PairV2).creationCode, params);

        pair = Create2.computeAddress(keccak256(params), keccak256(bytecode), factory);
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        (uint112 _reserve0, uint112 _reserve1,) = IUniswapV2Pair(pairFor(factory, token0, token1)).getReserves();
        (reserveA, reserveB) =
            tokenA == token0 ? (uint256(_reserve0), uint256(_reserve1)) : (uint256(_reserve1), uint256(_reserve0));
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, "INSUFFICIENT_AMOUNT");
        amountB = amountA * reserveB / reserveA;
        require(reserveB > 0, "INSUFFICIENT_LIQUIDITY");
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * (reserveOut);
        uint256 denominator = reserveIn * 1000 + (amountInWithFee);
        unchecked {
            amountOut = numerator / denominator;
        }
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * (amountOut) * (1000);
        uint256 denominator = (reserveOut - amountOut) * (997);
        unchecked {
            amountIn = (numerator / denominator) + 1;
        }
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint256 amountIn, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        require(path.length > 1, "INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        unchecked {
            for (uint256 i; i < path.length - 1; ++i) {
                (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i], path[i + 1]);
                amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
            }
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint256 amountOut, address[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        require(path.length > 1, "Library: INVALID_PATH");
        amounts = new uint256[](path.length);
        unchecked {
            amounts[amounts.length - 1] = amountOut;
            for (uint256 i = path.length - 1; i > 0; --i) {
                (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i - 1], path[i]);
                amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {PairV2} from "src/PairV2.sol";
import {Create2} from "openzeppelin/utils/Create2.sol";
import {PairV2Library} from "src/PairV2Library.sol";
import {LatamswapFactory} from "src/Factory.sol";

contract LibTest is Test {
    LatamswapFactory factory;
    IUniswapV2Pair pair;

    function setUp() public virtual {
        vm.roll(1);
        vm.warp(1);

        factory = new LatamswapFactory(address(this));
    }

    function testSort(address tokenA, address tokenB) public {
        if (tokenA == address(0) || tokenB == address(0)) {
            vm.expectRevert();
            PairV2Library.sortTokens(tokenA, tokenB);
        } else if (tokenA == tokenB) {
            vm.expectRevert();
            PairV2Library.sortTokens(tokenA, tokenB);
        } else {
            (address token0, address token1) = PairV2Library.sortTokens(tokenA, tokenB);

            if (tokenA < tokenB) {
                assertEq(token0, tokenA);
                assertEq(token1, tokenB);
            } else {
                assertEq(token0, tokenB);
                assertEq(token1, tokenA);
            }
        }
    }

    function testReal(address tokenA, address tokenB) public {
        vm.assume(tokenA != address(0) && tokenA != tokenB && tokenB != address(0));
        (address token0, address token1) = PairV2Library.sortTokens(tokenA, tokenB);

        // token addresses are sorted
        address predicted = PairV2Library.pairFor(address(factory), token0, token1);

        pair = IUniswapV2Pair(factory.createPair(token0, token1));
        assertEq(pair.token0(), token0, "wrong token0");
        assertEq(pair.token1(), token1, "wrong token1");

        assertEq(predicted, address(pair));
    }
}

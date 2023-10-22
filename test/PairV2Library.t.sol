// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {LatamswapFactory} from "src/Factory.sol";
import {PairV2} from "src/PairV2.sol";
import {MockToken} from "./MockToken.sol";

import {PairV2Library} from "src/PairV2Library.sol";

contract PairV2LibraryTest is Test {
    address factory;

    address tokenA = address(10);
    address tokenB = address(11);
    address pairAB;

    function setUp() public virtual {
        vm.etch(tokenA, address(new MockToken()).code);
        vm.etch(tokenB, address(new MockToken()).code);

        factory = address(new LatamswapFactory(address(this)));

        pairAB = LatamswapFactory(factory).createPair(tokenA, tokenB);
    }

    // Function: sortTokens

    function test_sortTokens_sorted() public {
        (address token0, address token1) = PairV2Library.sortTokens(tokenA, tokenB);

        assertEq(tokenA, token0, "Fail sort tokenA");
        assertEq(tokenB, token1, "Fail sort tokenB");
    }

    function test_sortTokens_notSorted() public {
        (address token0, address token1) = PairV2Library.sortTokens(tokenB, tokenA);

        assertEq(tokenA, token0, "Fail sort tokenA");
        assertEq(tokenB, token1, "Fail sort tokenB");
    }

    function testTry_sortTokens_IdenticalAddress() public {
        vm.expectRevert(PairV2Library.ErrIdenticalAddress.selector);
        PairV2Library.sortTokens(tokenA, tokenA);
    }

    function testTry_sortTokens_ZeroAddress() public {
        vm.expectRevert(PairV2Library.ErrZeroAddress.selector);
        PairV2Library.sortTokens(tokenA, address(0));
    }

    // Function: pairFor

    function test_pairFor_sorted() public {
        address pair = PairV2Library.pairFor(factory, tokenA, tokenB);

        assertEq(pair, pairAB, "Fail pairAB");
    }

    function test_pairFor_notSorted() public {
        address pair = PairV2Library.pairFor(factory, tokenB, tokenA);

        assertEq(pair, pairAB, "Fail pairAB");
    }

    // Function: getReserves

    function test_getReserves_sorted() public {
        deal(tokenA, pairAB, 1);
        deal(tokenB, pairAB, 2);
        PairV2(pairAB).sync();
        (uint256 reserveA, uint256 reserveB) = PairV2Library.getReserves(factory, tokenA, tokenB);

        assertEq(reserveA, 1, "Fail reserveA");
        assertEq(reserveB, 2, "Fail reserveB");
    }

    function test_getReserves_notSorted() public {
        deal(tokenB, pairAB, 2);
        deal(tokenA, pairAB, 1);
        PairV2(pairAB).sync();
        (uint256 reserveA, uint256 reserveB) = PairV2Library.getReserves(factory, tokenB, tokenA);

        assertEq(reserveB, 1, "Fail reserveA");
        assertEq(reserveA, 2, "Fail reserveB");
    }

    // Function: quote

    function test_quote() public {
        uint256 amountB = PairV2Library.quote(1 ether, 3 ether, 2 ether);

        // Dummy test...
        // 1 ether * 2 ether / 3 ether
        assertEq(amountB, 666666666666666666);
    }

    function testTry_quote_InsufficientAmount() public {
        vm.expectRevert(PairV2Library.ErrInsufficientAmount.selector);
        PairV2Library.quote(0, 1, 1);
    }

    function testTry_quote_InsufficientLiquidity() public {
        vm.expectRevert(PairV2Library.ErrInsufficientLiquidity.selector);
        PairV2Library.quote(1, 1, 0);
    }

    function testTry_quote_reserveAZero() public {
        vm.expectRevert(stdError.divisionError);
        PairV2Library.quote(1, 0, 1);
    }

    // Function: getAmountOut

    function test_getAmountOut() public {
        uint256 amountOut = PairV2Library.getAmountOut(1 ether, 3 ether, 2 ether);

        // Dummy test...
        assertEq(amountOut, 498874155616712534);
    }

    function testTry_getAmountOut_InsufficientInputAmount() public {
        vm.expectRevert(PairV2Library.ErrInsufficientInputAmount.selector);
        PairV2Library.getAmountOut(0, 1, 1);
    }

    function testTry_getAmountOut_InsufficientLiquidity() public {
        vm.expectRevert(PairV2Library.ErrInsufficientLiquidity.selector);
        PairV2Library.getAmountOut(1, 1, 0);

        vm.expectRevert(PairV2Library.ErrInsufficientLiquidity.selector);
        PairV2Library.getAmountOut(1, 1, 0);
    }

    // Function: getAmountIn

    function test_getAmountIn() public {
        uint256 amountIn = PairV2Library.getAmountIn(1 ether, 3 ether, 2 ether);

        // Dummy test...
        assertEq(amountIn, 3009027081243731194);
    }

    function testTry_getAmountIn_InsufficientOutputAmount() public {
        vm.expectRevert(PairV2Library.ErrInsufficientOutputAmount.selector);
        PairV2Library.getAmountIn(0, 1, 1);
    }

    function testTry_getAmountIn_InsufficientLiquidity() public {
        vm.expectRevert(PairV2Library.ErrInsufficientLiquidity.selector);
        PairV2Library.getAmountIn(1, 1, 0);

        vm.expectRevert(PairV2Library.ErrInsufficientLiquidity.selector);
        PairV2Library.getAmountIn(1, 1, 0);
    }

    // Function: getAmountsOut

    // TODO

    // Function: getAmountsIn

    // TODO

    // Others

    function testSort(address _tokenA, address _tokenB) public {
        if (_tokenA == address(0) || _tokenB == address(0)) {
            vm.expectRevert();
            PairV2Library.sortTokens(_tokenA, _tokenB);
        } else if (_tokenA == _tokenB) {
            vm.expectRevert();
            PairV2Library.sortTokens(_tokenA, _tokenB);
        } else {
            (address token0, address token1) = PairV2Library.sortTokens(_tokenA, _tokenB);

            if (_tokenA < _tokenB) {
                assertEq(token0, _tokenA);
                assertEq(token1, _tokenB);
            } else {
                assertEq(token0, _tokenB);
                assertEq(token1, _tokenA);
            }
        }
    }

    function testReal(address _tokenA, address _tokenB) public {
        vm.assume(_tokenA != address(0) && _tokenA != _tokenB && _tokenB != address(0));
        (address token0, address token1) = PairV2Library.sortTokens(_tokenA, _tokenB);

        // token addresses are sorted
        address predicted = PairV2Library.pairFor(factory, token0, token1);

        PairV2 pair = PairV2(LatamswapFactory(factory).createPair(token0, token1));
        assertEq(pair.token0(), token0, "wrong token0");
        assertEq(pair.token1(), token1, "wrong token1");

        assertEq(predicted, address(pair));
    }
}

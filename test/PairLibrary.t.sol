// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {LatamswapFactory} from "../src/Factory.sol";
import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {MockToken} from "./MockToken.sol";

import {PairLibrary} from "../src/PairLibrary.sol";

import {Nativo} from "nativo/Nativo.sol";
import {WETH} from "solady/tokens/WETH.sol";

contract PairLibraryTest is Test {
    address factory;

    address tokenA = address(10);
    address tokenB = address(11);
    address pairAB;

    function setUp() public virtual {
        vm.etch(tokenA, address(new MockToken()).code);
        vm.etch(tokenB, address(new MockToken()).code);

        address nativo = address(new Nativo("Nativo", "NETH", makeAddr("nativoOwner"), makeAddr("nativoOwner")));

        factory = address(new LatamswapFactory(address(this), address(0), nativo));

        pairAB = LatamswapFactory(factory).createPair(tokenA, tokenB);
    }

    // Function: sortTokens

    function test_sortTokens_sorted() public {
        (address token0, address token1) = PairLibrary.sortTokens(tokenA, tokenB);

        assertEq(tokenA, token0, "Fail sort tokenA");
        assertEq(tokenB, token1, "Fail sort tokenB");
    }

    function test_sortTokens_notSorted() public {
        (address token0, address token1) = PairLibrary.sortTokens(tokenB, tokenA);

        assertEq(tokenA, token0, "Fail sort tokenA");
        assertEq(tokenB, token1, "Fail sort tokenB");
    }

    function testTry_sortTokens_IdenticalAddress() public {
        vm.expectRevert(PairLibrary.ErrIdenticalAddress.selector);
        PairLibrary.sortTokens(tokenA, tokenA);
    }

    function testTry_sortTokens_ZeroAddress() public {
        vm.expectRevert(PairLibrary.ErrZeroAddress.selector);
        PairLibrary.sortTokens(tokenA, address(0));
    }

    // Function: pairFor

    function test_pairFor_sorted() public {
        address pair = PairLibrary.pairFor(factory, tokenA, tokenB);

        assertEq(pair, pairAB, "Fail pairAB");
    }

    function test_pairFor_notSorted() public {
        address pair = PairLibrary.pairFor(factory, tokenB, tokenA);

        assertEq(pair, pairAB, "Fail pairAB");
    }

    // Function: getReserves

    function test_getReserves_sorted() public {
        deal(tokenA, pairAB, 1);
        deal(tokenB, pairAB, 2);
        IUniswapV2Pair(pairAB).sync();
        (uint256 reserveA, uint256 reserveB) = PairLibrary.getReserves(factory, tokenA, tokenB);

        assertEq(reserveA, 1, "Fail reserveA");
        assertEq(reserveB, 2, "Fail reserveB");
    }

    function test_getReserves_notSorted() public {
        deal(tokenB, pairAB, 2);
        deal(tokenA, pairAB, 1);
        IUniswapV2Pair(pairAB).sync();
        (uint256 reserveA, uint256 reserveB) = PairLibrary.getReserves(factory, tokenB, tokenA);

        assertEq(reserveB, 1, "Fail reserveA");
        assertEq(reserveA, 2, "Fail reserveB");
    }

    // Function: quote

    function test_quote() public {
        uint256 amountB = PairLibrary.quote(1 ether, 3 ether, 2 ether);

        // Dummy test...
        // 1 ether * 2 ether / 3 ether
        assertEq(amountB, 666666666666666666);
    }

    function testTry_quote_InsufficientAmount() public {
        vm.expectRevert(PairLibrary.ErrInsufficientAmount.selector);
        PairLibrary.quote(0, 1, 1);
    }

    function testTry_quote_InsufficientLiquidity() public {
        vm.expectRevert(PairLibrary.ErrInsufficientLiquidity.selector);
        PairLibrary.quote(1, 1, 0);
    }

    function testTry_quote_reserveAZero() public {
        vm.expectRevert(bytes4(keccak256("MulDivFailed()")));
        PairLibrary.quote(1, 0, 1);
    }

    // Function: getAmountOut

    function test_getAmountOut() public {
        uint256 amountOut = PairLibrary.getAmountOut(1 ether, 3 ether, 2 ether);

        // Dummy test...
        assertEq(amountOut, 498874155616712534);
    }

    function testTry_getAmountOut_InsufficientInputAmount() public {
        vm.expectRevert(PairLibrary.ErrInsufficientInputAmount.selector);
        PairLibrary.getAmountOut(0, 1, 1);
    }

    function testTry_getAmountOut_InsufficientLiquidity() public {
        vm.expectRevert(PairLibrary.ErrInsufficientLiquidity.selector);
        PairLibrary.getAmountOut(1, 1, 0);

        vm.expectRevert(PairLibrary.ErrInsufficientLiquidity.selector);
        PairLibrary.getAmountOut(1, 1, 0);
    }

    // Function: getAmountIn

    function test_getAmountIn() public {
        uint256 amountIn = PairLibrary.getAmountIn(1 ether, 3 ether, 2 ether);

        // Dummy test...
        assertEq(amountIn, 3009027081243731194);
    }

    function testTry_getAmountIn_InsufficientOutputAmount() public {
        vm.expectRevert(PairLibrary.ErrInsufficientOutputAmount.selector);
        PairLibrary.getAmountIn(0, 1, 1);
    }

    function testTry_getAmountIn_InsufficientLiquidity() public {
        vm.expectRevert(PairLibrary.ErrInsufficientLiquidity.selector);
        PairLibrary.getAmountIn(1, 1, 0);

        vm.expectRevert(PairLibrary.ErrInsufficientLiquidity.selector);
        PairLibrary.getAmountIn(1, 1, 0);
    }

    // Function: getAmountsOut

    // TODO

    // Function: getAmountsIn

    // TODO

    // Others

    function testSort(address _tokenA, address _tokenB) public {
        if (_tokenA == address(0) || _tokenB == address(0)) {
            vm.expectRevert();
            PairLibrary.sortTokens(_tokenA, _tokenB);
        } else if (_tokenA == _tokenB) {
            vm.expectRevert();
            PairLibrary.sortTokens(_tokenA, _tokenB);
        } else {
            (address token0, address token1) = PairLibrary.sortTokens(_tokenA, _tokenB);

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
        (address token0, address token1) = PairLibrary.sortTokens(_tokenA, _tokenB);

        // token addresses are sorted
        address predicted = PairLibrary.pairFor(factory, token0, token1);

        IUniswapV2Pair pair = IUniswapV2Pair(LatamswapFactory(factory).createPair(token0, token1));
        assertEq(pair.token0(), token0, "wrong token0");
        assertEq(pair.token1(), token1, "wrong token1");

        assertEq(predicted, address(pair));
    }
}

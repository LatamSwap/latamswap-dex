// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {LatamswapFactory} from "src/Factory.sol";
import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {MockToken} from "../MockToken.sol";

import {PairLibrary} from "src/PairLibrary.sol";

contract PairLibraryUnitTest is Test {
    address factory;

    address tokenA = address(10);
    address tokenB = address(11);
    address pair;

    MockPairLibrary pairLibraryMock = new MockPairLibrary();

    function setUp() public virtual {
        vm.etch(tokenA, address(new MockToken()).code);
        vm.etch(tokenB, address(new MockToken()).code);

        factory = address(new LatamswapFactory(address(this)));

        pair = LatamswapFactory(factory).createPair(tokenA, tokenB);
    }

    function addLiquidity(address token0, address token1, uint256 amount0, uint256 amount1) private {
        address _pair = PairLibrary.pairFor(factory, token0, token1);

        MockToken(token0).mint(address(this), amount0);
        MockToken(token0).transfer(_pair, amount0);
        MockToken(token1).mint(address(this), amount1);
        MockToken(token1).transfer(_pair, amount1);
        IUniswapV2Pair(_pair).mint(address(this));
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
        address _pair = PairLibrary.pairFor(factory, tokenA, tokenB);

        assertEq(_pair, pair, "Fail pair");
    }

    function test_pairFor_notSorted() public {
        address _pair = PairLibrary.pairFor(factory, tokenB, tokenA);

        assertEq(_pair, pair, "Fail pair");
    }

    // Function: getReserves

    function test_getReserves_sorted() public {
        deal(tokenA, pair, 1);
        deal(tokenB, pair, 2);
        IUniswapV2Pair(pair).sync();
        (uint256 reserveA, uint256 reserveB) = PairLibrary.getReserves(factory, tokenA, tokenB);

        assertEq(reserveA, 1, "Fail reserveA");
        assertEq(reserveB, 2, "Fail reserveB");
    }

    function test_getReserves_notSorted() public {
        deal(tokenB, pair, 2);
        deal(tokenA, pair, 1);
        IUniswapV2Pair(pair).sync();
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
        vm.expectRevert(stdError.divisionError);
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

    function test_getAmountsOut_TwoLength() public {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        addLiquidity(tokenA, tokenB, 1 ether, 5 ether);

        // Dummy test...
        uint256[] memory amounts = pairLibraryMock.getAmountsOut(factory, 1 ether, path);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 1 ether);
        assertEq(amounts[1], 2496244366549824737);
    }

    function test_getAmountsOut_ThreeLength() public {
        address tokenC = address(12);
        vm.etch(tokenC, address(new MockToken()).code);
        LatamswapFactory(factory).createPair(tokenB, tokenC);

        address[] memory path = new address[](3);
        path[0] = tokenA;
        path[1] = tokenB;
        path[2] = tokenC;
        addLiquidity(tokenA, tokenB, 1 ether, 5 ether);
        addLiquidity(tokenB, tokenC, 1 ether, 5 ether);

        // Dummy test...
        uint256[] memory amounts = pairLibraryMock.getAmountsOut(factory, 1 ether, path);
        assertEq(amounts.length, 3);
        assertEq(amounts[0], 1 ether);
        assertEq(amounts[1], 2496244366549824737);
        assertEq(amounts[2], 3566824241841411961);
    }

    function testTry_getAmountsOut_InvalidPath() public {
        vm.expectRevert(PairLibrary.ErrInvalidPath.selector);
        pairLibraryMock.getAmountsOut(factory, 0, new address[](0));
        vm.expectRevert(PairLibrary.ErrInvalidPath.selector);
        pairLibraryMock.getAmountsOut(factory, 0, new address[](1));
    }

    // Function: getAmountsIn

    function test_getAmountsIn_TwoLength() public {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        addLiquidity(tokenA, tokenB, 1 ether, 5 ether);

        // Dummy test...
        uint256[] memory amounts = pairLibraryMock.getAmountsIn(factory, 1 ether, path);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 250752256770310933);
        assertEq(amounts[1], 1 ether);
    }

    function test_getAmountsIn_ThreeLength() public {
        address tokenC = address(12);
        vm.etch(tokenC, address(new MockToken()).code);
        LatamswapFactory(factory).createPair(tokenB, tokenC);

        address[] memory path = new address[](3);
        path[0] = tokenA;
        path[1] = tokenB;
        path[2] = tokenC;
        addLiquidity(tokenA, tokenB, 1 ether, 5 ether);
        addLiquidity(tokenB, tokenC, 1 ether, 5 ether);

        // Dummy test...
        uint256[] memory amounts = pairLibraryMock.getAmountsIn(factory, 1 ether, path);
        assertEq(amounts.length, 3);
        assertEq(amounts[0], 52957182000065667);
        assertEq(amounts[1], 250752256770310933);
        assertEq(amounts[2], 1 ether);
    }

    function testTry_getAmountsIn_InvalidPath() public {
        vm.expectRevert(PairLibrary.ErrInvalidPath.selector);
        pairLibraryMock.getAmountsIn(factory, 0, new address[](0));
        vm.expectRevert(PairLibrary.ErrInvalidPath.selector);
        pairLibraryMock.getAmountsIn(factory, 0, new address[](1));
    }
}

contract MockPairLibrary {
    function getAmountsOut(
        address factory, uint256 amountIn, address[] calldata path
    ) external view returns (uint256[] memory amounts){
        return PairLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(
        address factory, uint256 amountOut, address[] calldata path
    ) external view returns (uint256[] memory amounts){
        return PairLibrary.getAmountsIn(factory, amountOut, path);
    }
}
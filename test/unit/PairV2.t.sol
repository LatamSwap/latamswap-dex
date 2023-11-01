// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {IPairLatamSwap} from "../../src/interfaces/IPairLatamSwap.sol";
import {PairV2} from "../../src/PairV2.sol";

contract PairV2Test is Test {
    address factory = makeAddr("factory");
    MockERC20 tokenA;
    MockERC20 tokenB;
    PairV2 pair;

    function setUp() public {
        tokenA = new MockERC20("Token A", "tknA", 18);
        tokenB = new MockERC20("Token B", "tknB", 18);

        pair = new PairV2(address(tokenA), address(tokenB), factory);
    }

    function _addLiquidity(uint256 amountA, uint256 amountB) private {
        tokenA.mint(address(this), amountA);
        tokenA.transfer(address(pair), amountA);
        tokenB.mint(address(this), amountB);
        tokenB.transfer(address(pair), amountB);
        pair.mint(address(this));
    }

    // Constructor

    function test_constructor() public {
        assertEq(pair.MINIMUM_LIQUIDITY(), 1e3);
        assertEq(pair.factory(), factory);
        assertEq(pair.token0(), address(tokenA));
        assertEq(pair.token1(), address(tokenB));
        assertEq(pair.price0CumulativeLast(), 0);
        assertEq(pair.price1CumulativeLast(), 0);
        assertEq(pair.kLast(), 0);
        assertEq(pair.name(), "LatamSwap PairV2");
        assertEq(pair.symbol(), "LATAMSWAP-V2");

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        assertEq(blockTimestampLast, 0);
    }

    // Function: _update, sync

    function testTry__update_LatamswapOverflow_balance0() public {
        tokenA.mint(address(this), uint256(type(uint112).max) + 1);
        tokenA.transfer(address(pair), uint256(type(uint112).max) + 1);
        vm.expectRevert(IPairLatamSwap.ErrLatamswapOverflow.selector);
        pair.sync();
    }

    function testTry__update_LatamswapOverflow_balance1() public {
        tokenB.mint(address(this), uint256(type(uint112).max) + 1);
        tokenB.transfer(address(pair), uint256(type(uint112).max) + 1);
        vm.expectRevert(IPairLatamSwap.ErrLatamswapOverflow.selector);
        pair.sync();
    }

    // Function: _mintFee

    // Function: mint

    function testTry_mint_InsufficientLiquidity_MINIMUM_LIQUIDITY() public {
        tokenA.mint(address(this), 1001);
        tokenA.transfer(address(pair), 1001);
        tokenB.mint(address(this), 1001 - 1);
        tokenB.transfer(address(pair), 1001 - 1);

        vm.expectRevert(IPairLatamSwap.ErrLatamswapInsufficientLiquidity.selector);
        pair.mint(address(0));
    }

    function testTry_mint_InsufficientLiquidity_liquidityZero() public {
        tokenA.mint(address(this), 1001);
        tokenA.transfer(address(pair), 1001);
        tokenB.mint(address(this), 1001);
        tokenB.transfer(address(pair), 1001);
        pair.mint(address(0));

        vm.expectRevert(IPairLatamSwap.ErrLatamswapInsufficientLiquidity.selector);
        pair.mint(address(0));
    }

    // Function: burn

    function testTry_burn_InsufficientLiquidityBurned_amount0() public {
        tokenA.mint(address(this), 1001);
        tokenA.transfer(address(pair), 1001);
        tokenB.mint(address(this), 1001);
        tokenB.transfer(address(pair), 1001);
        pair.mint(address(0));

        vm.expectRevert(IPairLatamSwap.ErrLatamswapInsufficientLiquidityBurned.selector);
        pair.burn(address(0));
    }

    function testTry_burn_InsufficientLiquidityBurned_amount1() public {
        tokenA.mint(address(this), 1001);
        tokenA.transfer(address(pair), 1001);
        tokenB.mint(address(this), 1001);
        tokenB.transfer(address(pair), 1001);
        pair.mint(address(this));
        pair.transfer(address(pair), pair.balanceOf(address(this)));
        deal(address(tokenB), address(pair), 0);

        vm.expectRevert(IPairLatamSwap.ErrLatamswapInsufficientLiquidityBurned.selector);
        pair.burn(address(0));
    }

    // Function: swap

    function testTry_swap_InsufficientOutputAmount() public {
        vm.expectRevert(IPairLatamSwap.ErrLatamswapInsufficientOutputAmount.selector);
        pair.swap(0, 0, address(0), '');
    }

    function testTry_swap_InsufficientLiquidity_amount0Out() public {
        vm.expectRevert(IPairLatamSwap.ErrLatamswapInsufficientLiquidity.selector);
        pair.swap(1, 0, address(0), '');
    }

    function testTry_swap_InsufficientLiquidity_amount1Out() public {
        vm.expectRevert(IPairLatamSwap.ErrLatamswapInsufficientLiquidity.selector);
        pair.swap(0, 1, address(0), '');
    }

    function testTry_swap_InvalidTo_token0() public {
        _addLiquidity(1 ether, 1 ether);

        vm.expectRevert(IPairLatamSwap.ErrLatamswapInvalidTo.selector);
        pair.swap(1, 1, address(tokenA), '');
    }

    function testTry_swap_InvalidTo_token1() public {
        _addLiquidity(1 ether, 1 ether);

        vm.expectRevert(IPairLatamSwap.ErrLatamswapInvalidTo.selector);
        pair.swap(1, 1, address(tokenB), '');
    }

    function testTry_swap_InsufficientInputAmount() public {
        _addLiquidity(1 ether, 1 ether);

        vm.expectRevert(IPairLatamSwap.ErrLatamswapInsufficientInputAmount.selector);
        pair.swap(0.5 ether, 0.5 ether, address(0), '');
    }

    // Function: skim
}
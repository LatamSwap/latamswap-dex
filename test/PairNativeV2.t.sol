// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import "./helper/BasePairTest.sol";

import {PairV2Native} from "src/PairV2-NATIVO-WETH.sol";
import {PairLibrary} from "src/PairLibrary.sol";
import {Nativo} from "lib/Nativo/src/Nativo.sol";
import {WETH} from "solady/tokens/WETH.sol";

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract PairNativeV2Test is Test {
    using SafeTransferLib for address;

    error ErrFunctionDisabled();

    address factory = makeAddr("factory");

    Nativo tokenNativo = new Nativo("Nativo", "NETH", makeAddr("nativoOwner"), makeAddr("nativoOwner"));
    WETH tokenWeth = new WETH();

    address token0;
    address token1;

    // events for test
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Sync(uint96 reserve0, uint96 reserve1);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);

    PairV2Native pair;

    uint256 constant BALANCE = type(uint112).max;

    function setUp() public {
        (token0, token1) = PairLibrary.sortTokens(address(tokenNativo), address(tokenWeth));

        vm.deal(address(this), BALANCE);
        tokenWeth.deposit{value: BALANCE}();
        vm.deal(address(this), BALANCE);
        tokenNativo.deposit{value: BALANCE}();

        pair = new PairV2Native(token0, token1, factory);
    }

    function addLiquidity(uint256 token0Amount, uint256 token1Amount) internal {
        MockERC20(token0).transfer(address(pair), token0Amount);
        MockERC20(token1).transfer(address(pair), token1Amount);
        vm.expectRevert(ErrFunctionDisabled.selector);
        pair.mint(address(this));
    }

    function test_Mint() public {
        // user should send funds to mint, is impossible to mint shares
        MockERC20(token0).transfer(address(pair), 1 ether);
        MockERC20(token1).transfer(address(pair), 4 ether);

        vm.expectRevert(ErrFunctionDisabled.selector);
        pair.mint(address(this));

        assertEq(pair.totalSupply(), type(uint256).max, "supply is always max");

        assertEq(MockERC20(token0).balanceOf(address(pair)), 1 ether);
        assertEq(MockERC20(token1).balanceOf(address(pair)), 4 ether);
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        assertEq(reserve0, type(uint112).max);
        assertEq(reserve1, type(uint112).max);

        pair.skim(address(this));
        assertEq(MockERC20(token0).balanceOf(address(pair)), 0);
        assertEq(MockERC20(token1).balanceOf(address(pair)), 0);
    }

    function test_Skim(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 0, 100 ether);
        amount1 = bound(amount1, 0, 100 ether);

        tokenWeth.transfer(address(pair), amount0);
        tokenNativo.transfer(address(pair), amount1);

        address skimmer = makeAddr("skimmer");
        pair.skim(skimmer);
        assertEq(tokenWeth.balanceOf(skimmer), amount0);
        assertEq(tokenNativo.balanceOf(skimmer), amount1);
    }

    function test_MintLiquidity(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 0, BALANCE);
        amount1 = bound(amount1, 0, BALANCE);

        token0.safeTransfer(address(pair), amount0);
        token1.safeTransfer(address(pair), amount1);

        vm.expectRevert(ErrFunctionDisabled.selector);
        pair.mint(address(this));

        address skimmer = makeAddr("skimmer");
        pair.skim(skimmer);
        assertEq(tokenWeth.balanceOf(skimmer), amount0);
        assertEq(tokenNativo.balanceOf(skimmer), amount1);
    }

    function test_SwapToken0() public {
        uint256 swapAmount = 1 ether;
        uint256 expectedOutputAmount = 1 ether;

        MockERC20(token0).transfer(address(pair), swapAmount);
        address swapper = makeAddr("swapper");
        pair.swap(0, expectedOutputAmount, swapper, "");

        assertEq(token0.balanceOf(swapper), 0);
        assertEq(token1.balanceOf(swapper), swapAmount);
    }

    function test_SwapToken1() public {
        uint256 swapAmount = 1 ether;
        uint256 expectedOutputAmount = 1 ether;

        MockERC20(token1).transfer(address(pair), swapAmount);
        address swapper = makeAddr("swapper");
        pair.swap(expectedOutputAmount, 0, swapper, "");

        assertEq(token0.balanceOf(swapper), swapAmount);
        assertEq(token1.balanceOf(swapper), 0);
    }

    function test_Burn() public {
        vm.expectRevert(ErrFunctionDisabled.selector);
        pair.burn(address(this));
    }

    function encodePrice(uint256 reserve0, uint256 reserve1) internal pure returns (uint256 a, uint256 b) {
        a = reserve1 * (2 ** 112) / reserve0;
        b = reserve0 * (2 ** 112) / reserve1;
    }

    function test_CumulativePrice() public {
        (,, uint256 blockTimestamp) = pair.getReserves();
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        vm.expectRevert(ErrFunctionDisabled.selector);
        pair.sync();
    }

    function runSwapCase(uint256 swapAmount, uint256 token0Amount, uint256 token1Amount, uint256 expectedOutputAmount)
        internal
    {
        token0.safeTransfer(address(pair), swapAmount);
        vm.expectRevert();
        pair.swap(0, expectedOutputAmount + 100, address(this), "");
        pair.swap(0, expectedOutputAmount, address(this), "");
    }

    function test_swap1(uint256 swapAmount) public {
        swapAmount = bound(swapAmount, 1, BALANCE - 100);
        token0.safeTransfer(address(pair), swapAmount);
        vm.expectRevert();
        pair.swap(0, swapAmount + 100, address(this), "");
        pair.swap(0, swapAmount, address(this), "");
    }

    function test_swap2(uint256 swapAmount) public {
        swapAmount = bound(swapAmount, 1, BALANCE - 100);
        token1.safeTransfer(address(pair), swapAmount);
        vm.expectRevert();
        pair.swap(swapAmount + 100, 0, address(this), "");
        pair.swap(swapAmount, 0, address(this), "");
    }

    /*






    ].map(a => a.map(n => (typeof n === 'string' ? bigNumberify(n) : expandTo18Decimals(n))))
    swapTestCases.forEach((swapTestCase, i) => {
    it(`getInputPrice:${i}`, async () => {
      const [swapAmount, token0Amount, token1Amount, expectedOutputAmount] = swapTestCase
      await addLiquidity(token0Amount, token1Amount)
      await token0.transfer(pair.address, swapAmount)
      await expect(pair.swap(0, expectedOutputAmount.add(1), wallet.address, '0x', overrides)).to.be.revertedWith(
        'UniswapV2: K'
      )
      await pair.swap(0, expectedOutputAmount, wallet.address, '0x', overrides)
    })
    })
    */
}
/*

    console.log("totalSupply", pair.totalSupply());


    tokenWeth.transfer(address(pair), 1 ether);
    pair.swap(0.5 ether, 0, address(this), "");
    pair.skim(address(this));
    console.log("totalSupply", pair.totalSupply());

    tokenWeth.transfer(address(pair), 100);
    tokenNativo.transfer(address(pair), 100);
    pair.mint(address(0xbeef));
    pair.skim(address(this));

    console.log("beef", pair.balanceOf(address(0xbeef)));
    console.log("totalSupply", pair.totalSupply());


    tokenWeth.transfer(address(pair), 100);
    tokenNativo.transfer(address(pair), 100);
    pair.mint(address(0xbeef));
    pair.skim(address(this));

    console.log("totan A", tokenNativo.balanceOf(address(this)));
    tokenWeth.transfer(address(pair), 1 ether);
    pair.swap(0, 0.5 ether, address(this), "");
    pair.skim(address(this));
console.log("totan A", tokenNativo.balanceOf(address(this)));

    console.log("beef", pair.balanceOf(address(0xbeef)));
    console.log("totalSupply", pair.totalSupply());*/

/*
import chai, { expect } from 'chai'
import { Contract } from 'ethers'
import { solidity, MockProvider, createFixtureLoader } from 'ethereum-waffle'
import { BigNumber, bigNumberify } from 'ethers/utils'

import { expandTo18Decimals, mineBlock, encodePrice } from './shared/utilities'
import { pairFixture } from './shared/fixtures'
import { AddressZero } from 'ethers/constants'



chai.use(solidity)

const overrides = {
  gasLimit: 9999999
}



  const swapTestCases: BigNumber[][] = [
    [1, 5, 10, '1662497915624478906'],
    [1, 10, 5, '453305446940074565'],

    [2, 5, 10, '2851015155847869602'],
    [2, 10, 5, '831248957812239453'],

    [1, 10, 10, '906610893880149131'],
    [1, 100, 100, '987158034397061298'],
    [1, 1000, 1000, '996006981039903216']
  ].map(a => a.map(n => (typeof n === 'string' ? bigNumberify(n) : expandTo18Decimals(n))))
  swapTestCases.forEach((swapTestCase, i) => {
    it(`getInputPrice:${i}`, async () => {
      const [swapAmount, token0Amount, token1Amount, expectedOutputAmount] = swapTestCase
      await addLiquidity(token0Amount, token1Amount)
      await token0.transfer(pair.address, swapAmount)
      await expect(pair.swap(0, expectedOutputAmount.add(1), wallet.address, '0x', overrides)).to.be.revertedWith(
        'UniswapV2: K'
      )
      await pair.swap(0, expectedOutputAmount, wallet.address, '0x', overrides)
    })
  })

  const optimisticTestCases: BigNumber[][] = [
    ['997000000000000000', 5, 10, 1], // given amountIn, amountOut = floor(amountIn * .997)
    ['997000000000000000', 10, 5, 1],
    ['997000000000000000', 5, 5, 1],
    [1, 5, 5, '1003009027081243732'] // given amountOut, amountIn = ceiling(amountOut / .997)
  ].map(a => a.map(n => (typeof n === 'string' ? bigNumberify(n) : expandTo18Decimals(n))))
  optimisticTestCases.forEach((optimisticTestCase, i) => {
    it(`optimistic:${i}`, async () => {
      const [outputAmount, token0Amount, token1Amount, inputAmount] = optimisticTestCase
      await addLiquidity(token0Amount, token1Amount)
      await token0.transfer(pair.address, inputAmount)
      await expect(pair.swap(outputAmount.add(1), 0, wallet.address, '0x', overrides)).to.be.revertedWith(
        'UniswapV2: K'
      )
      await pair.swap(outputAmount, 0, wallet.address, '0x', overrides)
    })
  })



})
*/

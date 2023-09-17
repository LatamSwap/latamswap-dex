// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import "./helper/BasePairTest.sol";

import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {PairV2} from "src/PairV2.sol";
import {PairV2Library} from "src/PairV2Library.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract PairV2Test is Test {
    using SafeTransferLib for address;

    address factory = makeAddr("factory");

    MockERC20 tokenA;
    MockERC20 tokenB;
    address token0;
    address token1;

    MockERC20 unitokenA;
    MockERC20 unitokenB;
    address unitoken0;
    address unitoken1;

    // events for test
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Sync(uint112 reserve0, uint112 reserve1);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);

    PairV2 pair;
    IUniswapV2Pair uniPair;

    uint256 MINIMUM_LIQUIDITY;

    function setUp() public {
        tokenA = new MockERC20("Token A", "tknA", 18);
        tokenB = new MockERC20("Token B", "tknB", 18);
        (token0, token1) = PairV2Library.sortTokens(address(tokenA), address(tokenB));

        tokenA.mint(address(this), 1001 ether);
        tokenB.mint(address(this), 1001 ether);

        unitokenA = new MockERC20("Token A", "tknA", 18);
        unitokenB = new MockERC20("Token B", "tknB", 18);
        (unitoken0, unitoken1) = PairV2Library.sortTokens(address(unitokenA), address(unitokenB));

        unitokenA.mint(address(this), 1001 ether);
        unitokenB.mint(address(this), 1001 ether);

        vm.prank(factory);
        pair = new PairV2(token0, token1);

        MINIMUM_LIQUIDITY = pair.MINIMUM_LIQUIDITY();

        MockFactory uniFactory = new MockFactory(makeAddr("uni"));
        uniFactory.setFeeTo(makeAddr("uni"));
        vm.prank(address(uniFactory));
        address uniswapV2Pair = address(deployCode("test/univ2/UniswapV2Pair.json"));
        vm.label(uniswapV2Pair, "uniPair");
        uniPair = IUniswapV2Pair(uniswapV2Pair);

        vm.prank(address(uniFactory));
        uniPair.initialize(unitoken0, unitoken1);
    }

    function addLiquidity(uint256 token0Amount, uint256 token1Amount) internal {
        MockERC20(token0).transfer(address(pair), token0Amount);
        MockERC20(token1).transfer(address(pair), token1Amount);
        pair.mint(address(this));
    }

    function test_Mint() public {
        MockERC20(token0).transfer(address(pair), 1 ether);
        MockERC20(token1).transfer(address(pair), 4 ether);

        vm.expectEmit(true, true, true, false, address(pair));
        emit Transfer(address(0), address(0), MINIMUM_LIQUIDITY);
        vm.expectEmit(true, true, true, false, address(pair));
        emit Transfer(address(0), address(this), 2 ether - MINIMUM_LIQUIDITY);
        vm.expectEmit(true, true, false, false, address(pair));
        emit Sync(1 ether, 4 ether);
        pair.mint(address(this));

        assertEq(pair.MINIMUM_LIQUIDITY(), 1e3);
        assertEq(pair.totalSupply(), 2 ether, "Expected liquidity not match");
        assertEq(pair.balanceOf(address(this)), 2 ether - MINIMUM_LIQUIDITY);

        assertEq(MockERC20(token0).balanceOf(address(pair)), 1 ether);
        assertEq(MockERC20(token1).balanceOf(address(pair)), 4 ether);
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        assertEq(reserve0, 1 ether);
        assertEq(reserve1, 4 ether);
    }

    function test_Skim() public {
        address skimmer = makeAddr("skimmer");

        tokenA.transfer(address(pair), 10);
        pair.skim(skimmer);
        assertEq(tokenA.balanceOf(skimmer), 10);

        tokenB.transfer(address(pair), 10);
        pair.skim(skimmer);
        assertEq(tokenB.balanceOf(skimmer), 10);

        tokenA.transfer(address(pair), 10);
        tokenB.transfer(address(pair), 10);
        pair.skim(skimmer);
        assertEq(tokenA.balanceOf(skimmer), 20);
        assertEq(tokenB.balanceOf(skimmer), 20);
    }

    function test_MintLiquidity(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 0, 100 ether);
        amount1 = bound(amount1, 0, 100 ether);

        token0.safeTransfer(address(pair), amount0);
        token1.safeTransfer(address(pair), amount1);

        unitoken0.safeTransfer(address(uniPair), amount0);
        unitoken1.safeTransfer(address(uniPair), amount1);

        try uniPair.mint(address(this)) {}
        catch Error(string memory reason) {
            vm.expectRevert();
            pair.mint(address(this));
            return;
        }

        pair.mint(address(this));
        assertEq(pair.totalSupply(), uniPair.totalSupply());
    }

    function test_SwapToken0() public {
        uint256 token0Amount = 5 ether;
        uint256 token1Amount = 10 ether;
        addLiquidity(token0Amount, token1Amount);

        uint256 swapAmount = 1 ether;
        uint256 expectedOutputAmount = 1662497915624478906;
        MockERC20(token0).transfer(address(pair), swapAmount);

        vm.expectEmit(true, true, true, false, address(token1));
        emit Transfer(address(pair), address(this), expectedOutputAmount);

        vm.expectEmit(true, true, false, false, address(pair));
        emit Sync(uint112(token0Amount + 1 ether), uint112(token1Amount - expectedOutputAmount));

        vm.expectEmit(true, true, true, true, address(pair));
        emit Swap(address(this), swapAmount, 0, 0, expectedOutputAmount, address(this));

        pair.swap(0, expectedOutputAmount, address(this), "");

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, token0Amount + swapAmount);
        assertEq(reserve1, token1Amount - expectedOutputAmount);

        assertEq(token0.balanceOf(address(pair)), token0Amount + swapAmount);
        assertEq(token1.balanceOf(address(pair)), token1Amount - expectedOutputAmount);

        uint256 totalSupplyToken0 = MockERC20(token0).totalSupply();
        uint256 totalSupplyToken1 = MockERC20(token1).totalSupply();
        assertEq(token0.balanceOf(address(this)), totalSupplyToken0 - token0Amount - swapAmount);
        assertEq(token1.balanceOf(address(this)), totalSupplyToken1 - token1Amount + expectedOutputAmount);
    }

    function test_SwapToken1() public {
        uint256 token0Amount = 5 ether;
        uint256 token1Amount = 10 ether;
        addLiquidity(token0Amount, token1Amount);

        uint256 swapAmount = 1 ether;
        uint256 expectedOutputAmount = 453305446940074565;
        token1.safeTransfer(address(pair), swapAmount);

        vm.expectEmit(true, true, true, false, address(token0));
        emit Transfer(address(pair), address(this), expectedOutputAmount);

        vm.expectEmit(true, true, false, false, address(pair));
        emit Sync(uint112(token0Amount - expectedOutputAmount), uint112(token1Amount + swapAmount));

        vm.expectEmit(true, true, true, true, address(pair));
        emit Swap(address(this), 0, swapAmount, expectedOutputAmount, 0, address(this));

        pair.swap(expectedOutputAmount, 0, address(this), "");

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, token0Amount - expectedOutputAmount);
        assertEq(reserve1, token1Amount + swapAmount);

        assertEq(token0.balanceOf(address(pair)), token0Amount - expectedOutputAmount);
        assertEq(token1.balanceOf(address(pair)), token1Amount + swapAmount);

        uint256 totalSupplyToken0 = MockERC20(token0).totalSupply();
        uint256 totalSupplyToken1 = MockERC20(token1).totalSupply();
        assertEq(token0.balanceOf(address(this)), totalSupplyToken0 - token0Amount + expectedOutputAmount);
        assertEq(token1.balanceOf(address(this)), totalSupplyToken1 - token1Amount - swapAmount);
    }

    function test_Burn() public {
        uint256 token0Amount = 3 ether;
        uint256 token1Amount = 3 ether;
        addLiquidity(token0Amount, token1Amount);

        uint256 expectedLiquidity = 3 ether;
        pair.transfer(address(pair), expectedLiquidity - MINIMUM_LIQUIDITY);

        vm.expectEmit(true, true, true, false, address(pair));
        emit Transfer(address(pair), address(0), expectedLiquidity - MINIMUM_LIQUIDITY);

        vm.expectEmit(true, true, true, false, token0);
        emit Transfer(address(pair), address(this), token0Amount - 1000);

        vm.expectEmit(true, true, true, false, token1);
        emit Transfer(address(pair), address(this), token1Amount - 1000);

        vm.expectEmit(true, true, false, false, address(pair));
        emit Sync(1000, 1000);

        vm.expectEmit(true, true, true, true, address(pair));
        emit Burn(address(this), token0Amount - 1000, token1Amount - 1000, address(this));

        pair.burn(address(this));

        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.totalSupply(), MINIMUM_LIQUIDITY);
        assertEq(token0.balanceOf(address(pair)), 1000);
        assertEq(token1.balanceOf(address(pair)), 1000);
        
    uint256 totalSupplyToken0 = MockERC20(token0).totalSupply();
    uint256 totalSupplyToken1 =  MockERC20(token1).totalSupply();

    assertEq(token0.balanceOf(address(this)), totalSupplyToken0 - 1000);
    assertEq(token1.balanceOf(address(this)), totalSupplyToken1 - 1000);
    
    }

    function test_Fees() public {
      
     uint256 token0Amount =1000 ether;
    uint256 token1Amount =1000 ether;
     addLiquidity(token0Amount, token1Amount);

    uint256 swapAmount =1 ether;
    uint256 expectedOutputAmount =996006981039903216;
    token1.safeTransfer(address(pair), swapAmount);
    pair.swap(expectedOutputAmount, 0, address(this), "");

    uint256 expectedLiquidity =1000 ether;
    pair.transfer(address(pair), expectedLiquidity - MINIMUM_LIQUIDITY);
    pair.burn(address(this));
    
    assertEq(pair.totalSupply(), MINIMUM_LIQUIDITY + 249750499251388);

    assertEq(pair.balanceOf(address(factory)), 249750499251388, "Expected factory fee not match");

    // using 1000 here instead of the symbolic MINIMUM_LIQUIDITY because the amounts only happen to be equal...
    // ...because the initial liquidity amounts were equal
    assertEq(token0.balanceOf(address(pair)), 1000 + 249501683697445, "Expected liquidity not match");
    //expect(await token1.balanceOf(pair.address)).to.eq(bigNumberify(1000).add('250000187312969'))
    }


    function test_Fees2() public {
      
     uint256 token0Amount =1000 ether;
    uint256 token1Amount =1000 ether;
      MockERC20(unitoken0).transfer(address(uniPair), token0Amount);
        MockERC20(unitoken1).transfer(address(uniPair), token1Amount);
        uniPair.mint(address(this));

    uint256 swapAmount =1 ether;
    uint256 expectedOutputAmount =996006981039903216;
    unitoken1.safeTransfer(address(uniPair), swapAmount);
    uniPair.swap(expectedOutputAmount, 0, address(this), "");

    uint256 expectedLiquidity =1000 ether;
    uniPair.transfer(address(uniPair), expectedLiquidity - MINIMUM_LIQUIDITY);
    uniPair.burn(address(this));
    
    assertEq(uniPair.totalSupply(), MINIMUM_LIQUIDITY + 249750499251388);

    assertEq(uniPair.balanceOf(address(factory)), 249750499251388, "Expected factory fee not match");

    // using 1000 here instead of the symbolic MINIMUM_LIQUIDITY because the amounts only happen to be equal...
    // ...because the initial liquidity amounts were equal
    assertEq(token0.balanceOf(address(pair)), 1000 + 249501683697445, "Expected liquidity not match");
    //expect(await token1.balanceOf(pair.address)).to.eq(bigNumberify(1000).add('250000187312969'))
    }
}
/*

    console.log("totalSupply", pair.totalSupply());

    
    tokenA.transfer(address(pair), 1 ether);
    pair.swap(0.5 ether, 0, address(this), "");
    pair.skim(address(this));
    console.log("totalSupply", pair.totalSupply());
    
    tokenA.transfer(address(pair), 100);
    tokenB.transfer(address(pair), 100);
    pair.mint(address(0xbeef));
    pair.skim(address(this));

    console.log("beef", pair.balanceOf(address(0xbeef)));
    console.log("totalSupply", pair.totalSupply());


    tokenA.transfer(address(pair), 100);
    tokenB.transfer(address(pair), 100);
    pair.mint(address(0xbeef));
    pair.skim(address(this));

    console.log("totan A", tokenB.balanceOf(address(this)));
    tokenA.transfer(address(pair), 1 ether);
    pair.swap(0, 0.5 ether, address(this), "");
    pair.skim(address(this));
console.log("totan A", tokenB.balanceOf(address(this)));
    
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



  it('price{0,1}CumulativeLast', async () => {
    const token0Amount = expandTo18Decimals(3)
    const token1Amount = expandTo18Decimals(3)
    await addLiquidity(token0Amount, token1Amount)

    const blockTimestamp = (await pair.getReserves())[2]
    await mineBlock(provider, blockTimestamp + 1)
    await pair.sync(overrides)

    const initialPrice = encodePrice(token0Amount, token1Amount)
    expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0])
    expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1])
    expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 1)

    const swapAmount = expandTo18Decimals(3)
    await token0.transfer(pair.address, swapAmount)
    await mineBlock(provider, blockTimestamp + 10)
    // swap to a new price eagerly instead of syncing
    await pair.swap(0, expandTo18Decimals(1), wallet.address, '0x', overrides) // make the price nice

    expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0].mul(10))
    expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1].mul(10))
    expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 10)

    await mineBlock(provider, blockTimestamp + 20)
    await pair.sync(overrides)

    const newPrice = encodePrice(expandTo18Decimals(6), expandTo18Decimals(2))
    expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0].mul(10).add(newPrice[0].mul(10)))
    expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1].mul(10).add(newPrice[1].mul(10)))
    expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 20)
  })

  it('feeTo:on', async () => {
    
  })
})
*/

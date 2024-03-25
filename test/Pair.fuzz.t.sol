// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {ERC20} from "solady/tokens/ERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {UQ112x112} from "src/utils/UQ112x112.sol";
import {PairV2} from "src/PairV2.sol";
import {PairLibrary} from "src/PairLibrary.sol";


contract MockFactory {
    address public feeTo;

    constructor(address _feeTo) {
        feeTo = _feeTo;
    }

    function setFeeTo(address _feeTo) public {
        feeTo = _feeTo;
    }
}

contract MockUser {
    function addLiquidity(address pair, address _token0, address _token1, uint256 _amount0, uint256 _amount1)
        public
        returns (uint256 liquidity)
    {
        ERC20(_token0).transfer(pair, _amount0);
        ERC20(_token1).transfer(pair, _amount1);

        liquidity = IUniswapV2Pair(pair).mint(address(this));
    }

    function removeLiquidity(address pair, uint256 liquidity) public returns (uint256 a, uint256 b) {
        IUniswapV2Pair(pair).transfer(pair, liquidity);

        (a, b) = IUniswapV2Pair(pair).burn(address(this));
    }
}

contract PairFuzzTest is Test {
    MockERC20 public token0 = new MockERC20("UnifapToken0", "UT0", 18);
    MockERC20 public token1 = new MockERC20("UnifapToken1", "UT1", 18);
    MockERC20 public token2 = new MockERC20("UnifapToken0", "UT0", 18);
    MockERC20 public token3 = new MockERC20("UnifapToken1", "UT1", 18);
    IUniswapV2Pair public pairUni;
    PairV2 public pairLatam;
    MockUser public userUni = new MockUser();
    MockUser public userLatam = new MockUser();
    address factory;

    function setUp() public virtual {
        vm.roll(1);
        vm.warp(1);

        factory = address(new MockFactory(address(this)));
        IUniswapV2Factory(factory).setFeeTo(address(this));

        vm.prank(address(factory));
        address uniswapV2Pair = address(deployCode("test/univ2/UniswapV2Pair.json"));
        pairUni = IUniswapV2Pair(uniswapV2Pair);

        vm.prank(address(factory));
        pairUni.initialize(address(token0), address(token1));

        //(token0, token1) = PairLibrary.sortTokens(address(tokenA), address(tokenB));
        pairLatam = new PairV2(address(token2), address(token3), factory);
    }

    function test_addLiquidity() public {
        uint256 amount0 = 1000e18;
        uint256 amount1 = 1000e18;
        uint256 amount2 = 1000e18;
        uint256 amount3 = 1000e18;

        deal(address(token0), address(userUni), amount0);
        deal(address(token1), address(userUni), amount1);
        deal(address(token2), address(userLatam), amount2);
        deal(address(token3), address(userLatam), amount3);

        userUni.addLiquidity(address(pairUni), address(token0), address(token1), amount0, amount1);
        userLatam.addLiquidity(address(pairLatam), address(token2), address(token3), amount2, amount3);

        assertEq(token0.balanceOf(address(pairUni)), amount0);
        assertEq(token1.balanceOf(address(pairUni)), amount1);
        assertEq(token2.balanceOf(address(pairLatam)), amount2);
        assertEq(token3.balanceOf(address(pairLatam)), amount3);
        assertEq(pairUni.balanceOf(address(userUni)), pairLatam.balanceOf(address(userLatam)));
    }
}

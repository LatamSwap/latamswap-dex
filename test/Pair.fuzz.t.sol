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
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract MockFactory {
    address public feeTo;

    function test() public { /* to remove from coverage */ }

    constructor(address _feeTo) {
        feeTo = _feeTo;
    }

    function setFeeTo(address _feeTo) public {
        feeTo = _feeTo;
    }
}

contract MockUser {
    function test() public { /* to remove from coverage */ }

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
    using SafeTransferLib for address;

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

    function test() public { /* to remove from coverage */ }

    function test_addLiquidity(uint256 amountA, uint256 amountB, bool invert) public {
        (address tokenUniA, address tokenUniB) = PairLibrary.sortTokens(address(token0), address(token1));
        (address tokenLatamA, address tokenLatamB) = PairLibrary.sortTokens(address(token2), address(token3));

        deal(address(tokenUniA), address(userUni), amountA);
        deal(address(tokenUniB), address(userUni), amountB);
        deal(address(tokenLatamA), address(userLatam), amountA);
        deal(address(tokenLatamB), address(userLatam), amountB);

        try userUni.addLiquidity(address(pairUni), address(token0), address(token1), amountA, amountB) {}
        catch {
            vm.expectRevert();
            userLatam.addLiquidity(address(pairLatam), address(token2), address(token3), amountA, amountB);
            return;
        }

        if (invert) {
            userLatam.addLiquidity(address(pairLatam), address(token3), address(token2), amountA, amountB);
        } else {
            userLatam.addLiquidity(address(pairLatam), address(token2), address(token3), amountA, amountB);
        }
        assertEq(tokenUniA.balanceOf(address(pairUni)), tokenLatamA.balanceOf(address(pairLatam)));
        assertEq(tokenUniB.balanceOf(address(pairUni)), tokenLatamB.balanceOf(address(pairLatam)));
        assertEq(pairUni.balanceOf(address(userUni)), pairLatam.balanceOf(address(userLatam)));

        (, bytes memory r1) = address(pairUni).call(abi.encodeWithSelector(pairUni.getReserves.selector));
        (, bytes memory r2) = address(pairLatam).call(abi.encodeWithSelector(pairUni.getReserves.selector));
        assertEq(abi.encodePacked(r1), abi.encodePacked(r2));

        deal(address(tokenUniA), address(userUni), amountA);
        deal(address(tokenUniB), address(userUni), amountB);
        deal(address(tokenLatamA), address(userLatam), amountA);
        deal(address(tokenLatamB), address(userLatam), amountB);

        userUni.addLiquidity(address(pairUni), address(token0), address(token1), amountA, amountB);

        if (!invert) {
            userLatam.addLiquidity(address(pairLatam), address(token3), address(token2), amountA, amountB);
        } else {
            userLatam.addLiquidity(address(pairLatam), address(token2), address(token3), amountA, amountB);
        }
        assertEq(tokenUniA.balanceOf(address(pairUni)), tokenLatamA.balanceOf(address(pairLatam)));
        assertEq(tokenUniB.balanceOf(address(pairUni)), tokenLatamB.balanceOf(address(pairLatam)));
        assertEq(pairUni.balanceOf(address(userUni)), pairLatam.balanceOf(address(userLatam)));

        (, r1) = address(pairUni).call(abi.encodeWithSelector(pairUni.getReserves.selector));
        (, r2) = address(pairLatam).call(abi.encodeWithSelector(pairUni.getReserves.selector));
        assertEq(abi.encodePacked(r1), abi.encodePacked(r2));
    }
}

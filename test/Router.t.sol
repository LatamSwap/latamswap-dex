// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {PairV2} from "src/PairV2.sol";
import {PairLibrary} from "src/PairLibrary.sol";
import {LatamswapFactory} from "src/Factory.sol";
import {LatamswapRouter} from "src/Router.sol";
import {Nativo} from "lib/nativo/src/Nativo.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {MockToken} from "./MockToken.sol";

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract RouterLatamSwapTest is Test {
    using SafeTransferLib for address;

    LatamswapFactory factory;
    address router;
    address tokenA;
    address tokenB;
    address pairAB;
    address nativo;
    address weth;

    address deployer = makeAddr("deployer");

    function setUp() public {
        nativo = address(new Nativo("Nativo", "NETH", makeAddr("nativoOwner"), makeAddr("nativoOwner")));
        weth = address(new WETH());

        factory = new LatamswapFactory(deployer, address(weth), address(nativo));
        router = address(new LatamswapRouter(address(factory), nativo));

        tokenA = address(new MockToken());
        tokenB = address(new MockToken());
        vm.label(tokenA, "tokenA");
        vm.label(tokenB, "tokenB");

        deal(tokenA, address(this), 1000 ether);
        deal(tokenB, address(this), 1000 ether);

        tokenA.safeApprove(address(router), type(uint256).max);
        tokenB.safeApprove(address(router), type(uint256).max);
    }

    function testAddLiquidity(bool createPair) public {
        if (createPair) factory.createPair(tokenA, tokenB);
        LatamswapRouter(router).addLiquidity(
            tokenA, tokenB, 1 ether, 1 ether, 0, 0, address(this), block.timestamp + 1000
        );

        address pair = factory.getPair(tokenA, tokenB);

        assertEq(tokenA.balanceOf(pair), 1 ether);
        assertEq(tokenB.balanceOf(pair), 1 ether);
    }

    function testAddLiquidityETH(bool createPair) public {
        if (createPair) factory.createPair(tokenA, nativo);
        LatamswapRouter(router).addLiquidityETH{value: 1 ether}(
            tokenA, 1 ether, 0, 0, address(this), block.timestamp + 1000
        );

        address pair = factory.getPair(tokenA, nativo);

        assertEq(tokenA.balanceOf(pair), 1 ether);
        assertEq(nativo.balanceOf(pair), 1 ether);
    }

    function testRemoveLiquidity(bool createPair) public {
        if (createPair) factory.createPair(tokenA, tokenB);
        LatamswapRouter(router).addLiquidity(
            tokenA, tokenB, 1 ether, 1 ether, 0, 0, address(this), block.timestamp + 1000
        );

        address pair = factory.getPair(tokenA, tokenB);

        assertEq(tokenA.balanceOf(pair), 1 ether);
        assertEq(tokenB.balanceOf(pair), 1 ether);

        uint256 balance = pair.balanceOf(address(this));
        PairV2(pair).transferAndCall(
            router,
            balance / 2,
            abi.encode(
                bytes4(keccak256("removeLiquidity()")),
                tokenA,
                tokenB,
                uint256(0),
                uint256(0),
                address(this),
                block.timestamp + 1000
            )
        );

        uint256 newBalance = pair.balanceOf(address(this));
        assertEq(newBalance, balance / 2);

        // + 500 is the minimum liquidity
        assertEq(tokenA.balanceOf(pair), 0.5 ether + 500);
        assertEq(tokenB.balanceOf(pair), 0.5 ether + 500);
    }

    function testSimple() public {
        LatamswapRouter(router).addLiquidity(
            tokenA, tokenB, 100 ether, 100 ether, 0, 0, address(this), block.timestamp + 1000
        );

        address pair = factory.getPair(tokenA, tokenB);

        assertEq(tokenA.balanceOf(pair), 100 ether);
        assertEq(tokenB.balanceOf(pair), 100 ether);

        address receiver = makeAddr("receiver");

        vm.expectRevert();
        LatamswapRouter(router).addLiquidityTokenA(
            tokenA, tokenB, 1 ether, 0.5 ether, makeAddr("receiver"), block.timestamp + 1000
        );

        (uint256 amountA, uint256 amountB, uint256 liquidity) = LatamswapRouter(router).addLiquidityTokenA(
            tokenA, tokenB, 1 ether, 0, makeAddr("receiver"), block.timestamp + 1000
        );

        assertEq(tokenA.balanceOf(pair), 101 ether);
        assertEq(tokenB.balanceOf(pair), 100 ether);

        assertGt(PairV2(pair).balanceOf(receiver), 0);
        assertEq(PairV2(pair).balanceOf(receiver), liquidity);
    }

    function testImbalanced() public {
        LatamswapRouter(router).addLiquidity(
            tokenA, tokenB, 10 ether, 100 ether, 0, 0, address(this), block.timestamp + 1000
        );

        address pair = factory.getPair(tokenA, tokenB);

        assertEq(tokenA.balanceOf(pair), 10 ether);
        assertEq(tokenB.balanceOf(pair), 100 ether);

        address receiver = makeAddr("receiver");

        vm.expectRevert();
        LatamswapRouter(router).addLiquidityTokenA(
            tokenA, tokenB, 1 ether, 9 ether, makeAddr("receiver"), block.timestamp + 1000
        );

        (uint256 amountA, uint256 amountB, uint256 liquidity) =
            LatamswapRouter(router).addLiquidityTokenA(tokenA, tokenB, 1 ether, 0, receiver, block.timestamp + 1000);
        assertEq(tokenA.balanceOf(pair), 11 ether);
        assertEq(tokenB.balanceOf(pair), 100 ether);

        assertEq(PairV2(pair).balanceOf(receiver), liquidity);

        address receiver2 = makeAddr("receiver2");

        (amountA, amountB, liquidity) =
            LatamswapRouter(router).addLiquidityTokenA(tokenB, tokenA, 1 ether, 0, receiver2, block.timestamp + 1000);
        assertEq(tokenA.balanceOf(pair), 11 ether);
        assertEq(tokenB.balanceOf(pair), 101 ether);

        assertEq(PairV2(pair).balanceOf(receiver2), liquidity);
    }
}

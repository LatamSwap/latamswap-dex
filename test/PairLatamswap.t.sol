// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";

import {PairV2} from "src/PairV2.sol";

import "./helper/BasePairTest.sol";

contract LatamPair2Test is BasePairTest {
    function setUp() public override {
        super.setUp();

        factory = address(new MockFactory(address(this)));
        IUniswapV2Factory(factory).setFeeTo(address(this));

        vm.prank(address(factory));
        pair = IUniswapV2Pair(
            address(
                new PairV2(
                address(token0),
                address(token1)
                )
            )
        );
    }

    function testMetadata() public {
        assertEq(pair.name(), "LatamSwap PairV2");
        assertEq(pair.symbol(), "LATAMSWAP-V2");
        assertEq(pair.decimals(), 18);
    }
}

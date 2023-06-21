// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";

import {LatamSwapPairV2} from "src/LatamSwapPairV2.sol";

import "./helper/BasePairTest.sol";

contract LatamPair2Test is BasePairTest {
    function setUp() public override {
        super.setUp();
        
        factory = address(new MockFactory(address(this)));
        IUniswapV2Factory(factory).setFeeTo(address(this));

        vm.prank(address(factory));
        pair = IUniswapV2Pair(
            address(
                new LatamSwapPairV2(
                address(token0),
                address(token1)
                )
            )
        );
    }
}
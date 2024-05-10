// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import "./helper/BasePairTest.sol";

contract PairUniV2Test is BasePairTest {
    function test() public override { /* to remove from coverage */ }

    function setUp() public override {
        super.setUp();

        factory = address(new MockFactory(address(this)));
        IUniswapV2Factory(factory).setFeeTo(address(this));

        vm.prank(address(factory));
        address uniswapV2Pair = address(deployCode("test/univ2/UniswapV2Pair.json"));
        pair = IUniswapV2Pair(uniswapV2Pair);

        vm.prank(address(factory));
        pair.initialize(address(token0), address(token1));
    }
}

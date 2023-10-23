// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {LatamswapFactory} from "src/Factory.sol";
import {LatamswapV2Router02} from "src/Router.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";


contract CounterScript is Script {
    address WLAC = 0xdcb679Ac6C72d438e66D39f3FB3364dED7254FC9;

    function setUp() public {}

    function run() public returns(address factory, address router) {
        vm.broadcast();
        LatamswapFactory _factory = new LatamswapFactory(address(this));
        LatamswapV2Router02 _router = new LatamswapV2Router02(address(_factory), WLAC);

        factory = address(_factory);
        router = address(_router);

        MockERC20 usdc = new MockERC20("USDC", "USDC", 18);

        usdc.mint(address(this), 10 ether);
        usdc.approve(router, 10 ether);


        _router.addLiquidityETH{value: 1 ether}(
            address(usdc),
            1 ether,
            1 ether,
            1 ether,
            address(this),
            block.timestamp
        );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {LatamswapFactory} from "src/Factory.sol";
import {LatamswapRouter} from "src/Router.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {Multicall2, Build} from "./multicall.sol";

import {Nativo} from "nativo/Nativo.sol";

contract CounterScript is Script {
    function setUp() public {
        // anvil
        // forge script script/Counter.s.sol -vv --rpc-url=http://127.0.0.1:8545 --broadcast --private-key=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    }

    function run()
        public
        returns (
            address factory,
            address router,
            address nativo,
            address multicallAddress,
            address token,
            address p1,
            address p2
        )
    {
        address ORIGIN = tx.origin;

        vm.broadcast();
        nativo = address(new Nativo("Nativo Wrapper Ether", "nETH", address(0), address(0)));

        vm.broadcast();
        LatamswapFactory _factory = new LatamswapFactory(ORIGIN, address(0), address(0));
        vm.broadcast();
        LatamswapRouter _router = new LatamswapRouter(address(_factory), nativo);

        factory = address(_factory);
        router = address(_router);

        vm.broadcast();
        MockERC20 usdc = new MockERC20("USDC", "USDC", 18);

        token = address(usdc);

        vm.startBroadcast();
        usdc.mint(ORIGIN, 10000 ether);
        usdc.mint(ORIGIN, 2000 ether);
        usdc.approve(address(router), 10000 ether);
        _router.addLiquidityETH{value: 1 ether}(address(usdc), 1 ether, 0, 0, ORIGIN, block.timestamp + 60);

        multicallAddress = address(new Multicall2());

        p1 = _factory.getPair(address(usdc), _router.WETH());
        p2 = _factory.getPair(address(usdc), address(nativo));

        vm.stopBroadcast();
    }
}

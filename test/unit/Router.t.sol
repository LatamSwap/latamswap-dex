// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {LatamswapFactory} from "src/Factory.sol";
import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {Nativo} from "nativo/Nativo.sol";

import {ILatamSwapRouter} from "../../src/interfaces/ILatamSwapRouter.sol";
import {LatamswapRouter} from "../../src/Router.sol";

contract PairLibraryUnitTest is Test {
    Nativo nativo = new Nativo("", "", address(0), address(0));
    address factory = address(new LatamswapFactory(address(this)));

    LatamswapRouter router;

    function setUp() public virtual {
        router = new LatamswapRouter(factory, address(nativo));
    }

    // Function: addLiquidity

    function test_addLiquidity_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.addLiquidity(address(0), address(0), 0, 0, 0, 0, address(0), block.timestamp - 1);
    }

    // Function: addLiquidityETH

    function test_addLiquidityETH_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.addLiquidityETH(address(0), 0, 0, 0, address(0), block.timestamp - 1);
    }

    // Function: removeLiquidity

    function test_removeLiquidity_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.removeLiquidity(address(0), address(0), 0, 0, 0, address(0), block.timestamp - 1);
    }

    // Function: removeLiquidityETH

    function test_removeLiquidityETH_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.removeLiquidityETH(address(0), 0, 0, 0, address(0), block.timestamp - 1);
    }

    // Function: removeLiquidityETH

    // Function: removeLiquidityETHWithPermit

    // Function: removeLiquidityETHSupportingFeeOnTransferTokens

    function test_removeLiquidityETHSupportingFeeOnTransferTokens_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.removeLiquidityETHSupportingFeeOnTransferTokens(address(0), 0, 0, 0, address(0), block.timestamp - 1);
    }

    // Function: swapExactTokensForTokens

    function test_swapExactTokensForTokens_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.swapExactTokensForTokens(0, 0, new address[](0), address(0), block.timestamp - 1);
    }

    // Function: swapTokensForExactTokens

    function test_swapTokensForExactTokens_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.swapTokensForExactTokens(0, 0, new address[](0), address(0), block.timestamp - 1);
    }

    // Function: swapExactETHForTokens

    function test_swapExactETHForTokens_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.swapExactETHForTokens(0, new address[](0), address(0), block.timestamp - 1);
    }

    // Function: swapTokensForExactETH

    function test_swapTokensForExactETH_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.swapTokensForExactETH(0, 0, new address[](0), address(0), block.timestamp - 1);
    }

    // Function: swapExactTokensForETH

    function test_swapExactTokensForETH_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.swapExactTokensForETH(0, 0, new address[](0), address(0), block.timestamp - 1);
    }

    // Function: swapETHForExactTokens

    function test_swapETHForExactTokens_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.swapETHForExactTokens(0, new address[](0), address(0), block.timestamp - 1);
    }

    // Function: swapExactTokensForTokensSupportingFeeOnTransferTokens

    function test_swapExactTokensForTokensSupportingFeeOnTransferTokens_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(0, 0, new address[](0), address(0), block.timestamp - 1);
    }

    // Function: swapExactETHForTokensSupportingFeeOnTransferTokens

    function test_swapExactETHForTokensSupportingFeeOnTransferTokens_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens(0, new address[](0), address(0), block.timestamp - 1);
    }

    // Function: swapExactTokensForETHSupportingFeeOnTransferTokens

    function test_swapExactTokensForETHSupportingFeeOnTransferTokens_Expired() public {
        vm.expectRevert(ILatamSwapRouter.ErrExpired.selector);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(0, 0, new address[](0), address(0), block.timestamp - 1);
    }


}
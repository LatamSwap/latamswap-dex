// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {LatamSwapPairV2} from "src/LatamSwapPairV2.sol";
import {Create2} from "openzeppelin/utils/Create2.sol";
import {LatamSwapV2Library} from "src/LatamSwapV2Library.sol";

contract MockFactory {
    address public feeTo;

    constructor(address _feeTo) {
        feeTo = _feeTo;
    }

    function setFeeAddress(address _feeTo) public {
        feeTo = _feeTo;
    }
}

contract LibTest is Test {
    address factory;
    IUniswapV2Pair pair;

    function setUp() public virtual {
        vm.roll(1);
        vm.warp(1);

        factory = address(new MockFactory(address(this)));
    }

    function testSort(address tokenA, address tokenB) public {
        if (tokenA == address(0) || tokenB == address(0)) {
            vm.expectRevert();
            LatamSwapV2Library.sortTokens(tokenA, tokenB);
        } else if (tokenA == tokenB) {
            vm.expectRevert();
            LatamSwapV2Library.sortTokens(tokenA, tokenB);
        } else {
            (address token0, address token1) = LatamSwapV2Library.sortTokens(tokenA, tokenB);

            if (tokenA < tokenB) {
                assertEq(token0, tokenA);
                assertEq(token1, tokenB);
            } else {
                assertEq(token0, tokenB);
                assertEq(token1, tokenA);
            }
        }
    }

    function testReal() public {
        address token0 = address(0x1);
        address token1 = address(0x2);

        bytes32 _salt = keccak256(abi.encodePacked(uint256(uint160(token0)), uint256(uint160(token1))));

        address predicted = LatamSwapV2Library.pairFor(factory, token0, token1);
        vm.prank(address(factory));
        pair = IUniswapV2Pair(
            address(
                new LatamSwapPairV2{salt: _salt}(
                address(token0),
                address(token1)
                )
            )
        );

        assertEq(predicted, address(pair));
    }
}

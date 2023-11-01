// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockToken} from "../MockToken.sol";

import {LatamswapFactory} from "src/Factory.sol";

contract FactoryUnitTest is Test {
    // Pair factory
    LatamswapFactory factory;
    MockToken tokenMock;

    address deployer = makeAddr("deployer");

    // expected errors
    error ErrZeroAddress();
    error ErrIdenticalAddress();
    error ErrPairExists();
    error Unauthorized();

    // constants
    uint256 constant AMOUNT_STUCK = 1000;

    function setUp() public {
        factory = new LatamswapFactory(deployer);
        tokenMock = new MockToken();
        tokenMock.mint(address(factory), AMOUNT_STUCK);
    }

    // Function: createPair

    function test_addDuplicatePair() public {
        address token0 = makeAddr("token0");
        address token1 = makeAddr("token1");
        factory.createPair(token0, token1);

        assertEq(factory.allPairsLength(), 1);

        vm.expectRevert(ErrPairExists.selector);
        factory.createPair(token0, token1);
        vm.expectRevert(ErrPairExists.selector);
        factory.createPair(token1, token0);
    }

    function test_addressZero() public {
        address token0 = address(0);
        address token1 = makeAddr("token1");

        vm.expectRevert(ErrZeroAddress.selector);
        factory.createPair(token0, token1);
        vm.expectRevert(ErrZeroAddress.selector);
        factory.createPair(token1, token0);
    }

    function test_sameAddress() public {
        address token0 = makeAddr("token0");

        vm.expectRevert(ErrIdenticalAddress.selector);
        factory.createPair(token0, token0);
    }

    // Function: withdraw(address,address)

    function test_withdrawStuck() public {
        address account = makeAddr("account");

        assertEq(tokenMock.balanceOf(address(factory)), AMOUNT_STUCK);

        vm.expectRevert(Unauthorized.selector);
        factory.withdraw(address(tokenMock), account);

        vm.prank(deployer);
        factory.withdraw(address(tokenMock), account);

        assertEq(tokenMock.balanceOf(address(factory)), 0);
        assertEq(tokenMock.balanceOf(account), AMOUNT_STUCK);
    }

    // Function: withdraw(address,address,uint256)

    function test_withdrawAmountStuck() public {
        address account = makeAddr("account");

        assertEq(tokenMock.balanceOf(address(factory)), AMOUNT_STUCK);

        uint256 withdrawAmount = AMOUNT_STUCK / 4;

        vm.expectRevert(Unauthorized.selector);
        factory.withdraw(address(tokenMock), account, withdrawAmount);

        vm.prank(deployer);
        factory.withdraw(address(tokenMock), account, withdrawAmount);

        assertEq(tokenMock.balanceOf(address(factory)), AMOUNT_STUCK - withdrawAmount);
        assertEq(tokenMock.balanceOf(account), withdrawAmount);
    }
}

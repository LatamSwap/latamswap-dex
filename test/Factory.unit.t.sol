// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

// Test Helpers, Mock Tokens
import "forge-std/Test.sol";

// Pair factory and Pair
import {LatamswapFactory} from "src/Factory.sol";
import {MockToken} from "./MockToken.sol";
import {Nativo} from "lib/nativo/src/Nativo.sol";
import {WETH} from "solady/tokens/WETH.sol";

contract FactoryUnitTest is Test {
    // Pair factory and Pair
    LatamswapFactory factory;
    MockToken tokenMock;

    address deployer = makeAddr("deployer");

    // expected errors
    error ErrZeroAddress();
    error ErrIdenticalAddress();
    error ErrPairExists();
    error Unauthorized();
    error ErrNativoMustBeDeployed();

    // constants
    uint256 constant AMOUNT_STUCK = 1000;

    function setUp() public {
        address nativo = address(new Nativo("Nativo", "NETH", makeAddr("nativoOwner"), makeAddr("nativoOwner")));
        address weth = address(new WETH());

        factory = new LatamswapFactory(deployer, weth, nativo);
        tokenMock = new MockToken();
    }

    function testNoNativo() public {
        vm.expectRevert(ErrNativoMustBeDeployed.selector);
        factory = new LatamswapFactory(deployer, address(0), address(0));
        vm.expectRevert(ErrNativoMustBeDeployed.selector);
        factory = new LatamswapFactory(deployer, address(1), address(0));

        // factory will work but wont create stable pair WETH-NATIVO
        factory = new LatamswapFactory(deployer, address(1), address(1));
        vm.expectRevert();
        factory.allPairs(0);

        // this should work but wont create stable pair WETH-NATIVO
        factory = new LatamswapFactory(deployer, address(0), address(1));
        vm.expectRevert();
        factory.allPairs(0);

        // this should work and create stable pair
        factory = new LatamswapFactory(deployer, address(2), address(1));
        assertEq(factory.allPairs(0), factory.getPair(address(1), address(2)));
        assertEq(factory.allPairs(0), factory.getPair(address(2), address(1)));
    }

    function test_addDuplicatePair() public {
        address token0 = makeAddr("token0");
        address token1 = makeAddr("token1");
        factory.createPair(token0, token1);

        // 2 because the first pair should be the WETH-NATIVO
        assertEq(factory.allPairsLength(), 2);
        assertEq(factory.getPair(token1, token0), factory.allPairs(1));
        assertEq(factory.getPair(token0, token1), factory.allPairs(1));

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

    function test_withdrawStuck() public {
        tokenMock.mint(address(factory), AMOUNT_STUCK);

        address account = makeAddr("account");

        assertEq(tokenMock.balanceOf(address(factory)), AMOUNT_STUCK);

        vm.expectRevert(Unauthorized.selector);
        factory.withdraw(address(tokenMock), account);

        vm.prank(deployer);
        factory.withdraw(address(tokenMock), account);

        assertEq(tokenMock.balanceOf(address(factory)), 0);
        assertEq(tokenMock.balanceOf(account), AMOUNT_STUCK);
    }

    function test_withdrawAmountStuck() public {
        tokenMock.mint(address(factory), AMOUNT_STUCK);

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

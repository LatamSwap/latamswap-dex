// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

// Test Helpers, Mock Tokens
import "forge-std/Test.sol";


// Pair factory and Pair
import {LatamswapFactory} from "src/Factory.sol";

contract FactoryUnitTest is Test {
    // Pair factory and Pair
    LatamswapFactory factory;

    // expected errors
    error ErrZeroAddress();
    error ErrIdenticalAddress();
    error ErrPairExists();

    function setUp() public {
        factory = new LatamswapFactory(address(this));
    }
    
    function test_addDuplicatePair() public { 
      address token0 = makeAddr("token0");
      address token1 = makeAddr("token1");
      factory.createPair(token0, token1);

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
}

// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

// Test Helpers, Mock Tokens
import "forge-std/Test.sol";

import {DeflatingERC20} from "./DeflatingERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";

import {ERC20} from "solady/tokens/ERC20.sol";
import {Nativo} from "nativo/Nativo.sol";

// Pair factory and Pair
import {LatamswapFactory} from "src/Factory.sol";
import {PairV2} from "src/PairV2.sol";
import {PairLibrary} from "src/PairLibrary.sol";
// Routerss
import {LatamswapRouter} from "src/Router.sol";

contract TestCore is Test {
    uint256 MAX = type(uint256).max;

    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    // Mock Tokens
    MockERC20 usdc;
    MockERC20 usdt;
    DeflatingERC20 feeToken;
    WETH weth;
    Nativo nativo;

    // Pair factory and Pair
    PairV2 testStablePair;
    LatamswapFactory testFactory;
    PairV2 testWethPair;
    PairV2 testFeeWethPair;
    PairV2 testFeePair;
    PairV2 testNativoPair;
    PairV2 testFeeNativoPair;

    // Routers
    LatamswapRouter testRouter02;

    address owner;
    uint256 privateKey;

    function setUp() public {
        (owner, privateKey) = makeAddrAndKey("owner");

        vm.label(address(this), "THE_FUZZANATOR");

        // Deploy tokens
        usdc = new MockERC20("USDC", "USDC", 18);
        vm.label(address(usdc), "USDC");

        usdt = new MockERC20("USDT", "USDT", 6);
        vm.label(address(usdt), "USDT");

        feeToken = new DeflatingERC20(0);
        vm.label(address(feeToken), "FEE_TOKEN");

        weth = new WETH();
        vm.label(address(weth), "WETH");

        vm.prank(0xC0dE429aA384a6641fDc0Af4e6bcfb04054535b8);
        vm.setNonce(0xC0dE429aA384a6641fDc0Af4e6bcfb04054535b8, 131644038);
        nativo = new Nativo("Nativo Wrapper Ether", "nETH", address(0), address(0));
        vm.label(address(nativo), "NATIVO");
        assertEq(address(nativo), 0x0000000B81F7260fA5add246b9C23bb2D89dDB20);

        // Deploy factory and Pairs
        testFactory = new LatamswapFactory(address(this), address(weth), address(nativo));
        vm.label(address(testFactory), "FACTORY");

        testStablePair = PairV2(testFactory.createPair(address(usdc), address(usdt)));
        vm.label(address(testStablePair), "STABLE_PAIR");

        testWethPair = PairV2(testFactory.createPair(address(usdc), address(weth)));
        vm.label(address(testWethPair), "WETH_PAIR");

        testNativoPair = PairV2(testFactory.createPair(address(usdc), address(nativo)));
        vm.label(address(testNativoPair), "NATIVO_PAIR");

        testFeeWethPair = PairV2(testFactory.createPair(address(weth), address(feeToken)));
        vm.label(address(testFeeWethPair), "FEEWETH_PAIR");

        testFeeNativoPair = PairV2(testFactory.createPair(address(nativo), address(feeToken)));
        vm.label(address(testFeeWethPair), "FEENATIVO_PAIR");

        testFeePair = PairV2(testFactory.createPair(address(feeToken), address(usdc)));
        vm.label(address(testFeeWethPair), "FEE_PAIR");

        // Deploy Router
        testRouter02 = new LatamswapRouter(address(testFactory), address(nativo));
        vm.label(address(testRouter02), "ROUTER");

        // Approve Router
        usdc.approve(address(testRouter02), MAX);
        usdt.approve(address(testRouter02), MAX);
        feeToken.approve(address(testRouter02), MAX);
        weth.approve(address(testRouter02), MAX);
    }

    /* INVARIANT: Adding liquidity to a pair should:
     * Increase reserves
     * Increase address to balance
     * Increase totalSupply
     * Increase K
    */
    function testFuzz_AddLiq(uint256 amount1, uint256 amount2) public {
        // PRECONDTION:
        uint256 _amount1 = bound(amount1, (10 ** 3), MAX);
        uint256 _amount2 = bound(amount2, (10 ** 3), MAX);
        if (!setStable) {
            _init(_amount1, _amount2);
        }

        (uint256 reserveABefore, uint256 reserveBBefore,) = testStablePair.getReserves();
        (uint256 totalSupplyBefore) = testStablePair.totalSupply();
        (uint256 userBalBefore) = testStablePair.balanceOf(address(this));
        uint256 kBefore = reserveABefore * reserveBBefore;

        // ACTION:
        try testRouter02.addLiquidity(address(usdc), address(usdt), _amount1, _amount2, 0, 0, address(this), MAX) {
            // POSTCONDTION:
            (uint256 reserveAAfter, uint256 reserveBAfter,) = testStablePair.getReserves();
            (uint256 totalSupplyAfter) = testStablePair.totalSupply();
            (uint256 userBalAfter) = testStablePair.balanceOf(address(this));
            uint256 kAfter = reserveAAfter * reserveBAfter;

            assertGt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
            assertGt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
            assertGt(kAfter, kBefore, "K CHECK");
            assertGt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
            assertGt(userBalAfter, userBalBefore, "USER BAL CHECK");
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Adding ETH liquidity to a pair should:
     * Increase reserves
     * Increase address to balance
     * Increase totalSupply
     * Increase K
    */
    function testFuzz_ETHAddLiq(uint256 amount) public {
        // PRECONDTION:
        amount = bound(amount, (10 ** 3), MAX);

        if (!setETH) {
            _initETH(amount);
        }

        (uint256 reserveABefore, uint256 reserveBBefore,) = testWethPair.getReserves();
        (uint256 totalSupplyBefore) = testNativoPair.totalSupply();
        (uint256 userBalBefore) = testNativoPair.balanceOf(address(this));
        uint256 kBefore = reserveABefore * reserveBBefore;

        // ACTION:
        try testRouter02.addLiquidityETH{value: amount}(address(usdc), amount, 0, 0, address(this), MAX) {
            // POSTCONDTION:
            (uint256 reserveAAfter, uint256 reserveBAfter,) = testNativoPair.getReserves();
            (uint256 totalSupplyAfter) = testNativoPair.totalSupply();
            (uint256 userBalAfter) = testNativoPair.balanceOf(address(this));
            uint256 kAfter = reserveAAfter * reserveBAfter;

            assertGt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
            assertGt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
            assertGt(kAfter, kBefore, "K CHECK");
        
            assertGt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
            assertGt(userBalAfter, userBalBefore, "USER BAL CHECK");
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Removing liquidity from a pair should:
     * Keep reserves the same
     * Keep the address to balance the same
     * Keep totalSupply the same
     * Keep K the same
    */
    function testFuzz_RemoveLiq(uint256 amount1, uint256 amount2) public {
        // PRECONDTION:
        uint256 _amount1 = bound(amount1, (10 ** 3), MAX);
        uint256 _amount2 = bound(amount2, (10 ** 3), MAX);
        if (!setStable) {
            _init(_amount1, _amount2);
        }

        try testRouter02.addLiquidity(address(usdc), address(usdt), _amount1, _amount2, 0, 0, address(this), MAX)
        returns (uint256, uint256, uint256 liquidity) {
            (uint256 reserveABefore, uint256 reserveBBefore,) = testStablePair.getReserves();
            (uint256 totalSupplyBefore) = testStablePair.totalSupply();
            (uint256 userBalBefore) = testStablePair.balanceOf(address(this));
            uint256 kBefore = reserveABefore * reserveBBefore;

            // ACTION:
            try testRouter02.removeLiquidity(address(usdc), address(usdt), liquidity, 0, 0, address(this), MAX) {
                // POSTCONDTION:
                (uint256 reserveAAfter, uint256 reserveBAfter,) = testStablePair.getReserves();
                (uint256 totalSupplyAfter) = testStablePair.totalSupply();
                (uint256 userBalAfter) = testStablePair.balanceOf(address(this));
                uint256 kAfter = reserveAAfter * reserveBAfter;

                assertLe(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                assertLe(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                assertLt(kAfter, kBefore, "K CHECK");
                assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            } catch { /*assert(false)*/ } // overflow
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Removing ETH liquidity from a pair should:
     * Keep reserves the same
     * Keep the address to balance the same
     * Keep totalSupply the same
     * Keep K the same
    */
    function testFuzz_ETHRemoveLiq(uint256 amount) public {
        // PRECONDTION:
        uint256 _amount = bound(amount, (10 ** 3), MAX);

        if (!setETH) {
            _initETH(_amount);
        }

        try testRouter02.addLiquidityETH{value: _amount}(address(usdc), _amount, 0, 0, address(this), MAX) returns (
            uint256, uint256, uint256 liquidity
        ) {
            (uint256 reserveABefore, uint256 reserveBBefore,) = testWethPair.getReserves();
            (uint256 totalSupplyBefore) = testWethPair.totalSupply();
            (uint256 userBalBefore) = testWethPair.balanceOf(address(this));
            uint256 kBefore = reserveABefore * reserveBBefore;

            // ACTION:
            try testRouter02.removeLiquidityETH(address(usdc), liquidity, 0, 0, address(this), MAX) {
                // POSTCONDTION:
                (uint256 reserveAAfter, uint256 reserveBAfter,) = testWethPair.getReserves();
                (uint256 totalSupplyAfter) = testWethPair.totalSupply();
                (uint256 userBalAfter) = testWethPair.balanceOf(address(this));
                uint256 kAfter = reserveAAfter * reserveBAfter;

                assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                assertLt(kAfter, kBefore, "K CHECK");
                assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            } catch { /*assert(false)*/ } // overflow
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Removing liquidity from a pair should:
     * Decrease reserves
     * Decrease address to balance
     * Decrease totalSupply
     * Decrease K
    */
    function testFuzz_removeLiqWithPermit(uint256 amount1, uint256 amount2, bool approveMax) public {
        // PRECONDTION:
        uint256 _amount1 = bound(amount1, (10 ** 3), MAX);
        uint256 _amount2 = bound(amount2, (10 ** 3), MAX);

        if (!setPermit) {
            _initPermit(owner, _amount1, _amount2);
            vm.startPrank(owner);
            usdc.approve(address(testRouter02), _amount1);
            usdt.approve(address(testRouter02), _amount2);
        }

        try testRouter02.addLiquidity(address(usdc), address(usdt), _amount1, _amount2, 0, 0, owner, MAX) returns (
            uint256, uint256, uint256 liquidity
        ) {
            (uint256 reserveABefore, uint256 reserveBBefore,) = testStablePair.getReserves();
            (uint256 totalSupplyBefore) = testStablePair.totalSupply();
            (uint256 userBalBefore) = testStablePair.balanceOf(address(owner));
            uint256 kBefore = reserveABefore * reserveBBefore;

            if (approveMax) {
                liquidity = type(uint256).max;
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    privateKey,
                    keccak256(
                        abi.encodePacked(
                            "\x19\x01",
                            testStablePair.DOMAIN_SEPARATOR(),
                            keccak256(
                                abi.encode(PERMIT_TYPEHASH, owner, address(testRouter02), liquidity, 0, block.timestamp)
                            )
                        )
                    )
                );

                // ACTION:
                try testRouter02.removeLiquidityWithPermit(
                    address(usdc), address(usdt), liquidity, 0, 0, owner, MAX, true, v, r, s
                ) {
                    // POSTCONDTION:
                    (uint256 reserveAAfter, uint256 reserveBAfter,) = testStablePair.getReserves();
                    (uint256 totalSupplyAfter) = testStablePair.totalSupply();
                    (uint256 userBalAfter) = testStablePair.balanceOf(address(this));
                    uint256 kAfter = reserveAAfter * reserveBAfter;

                    assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                    assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                    assertLt(kAfter, kBefore, "K CHECK");
                    assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                    assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
                } catch { /*assert(false)*/ } // overflow
            } else {
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    privateKey,
                    keccak256(
                        abi.encodePacked(
                            "\x19\x01",
                            testStablePair.DOMAIN_SEPARATOR(),
                            keccak256(
                                abi.encode(PERMIT_TYPEHASH, owner, address(testRouter02), liquidity, 0, block.timestamp)
                            )
                        )
                    )
                );

                // ACTION:
                try testRouter02.removeLiquidityWithPermit(
                    address(usdc), address(usdt), liquidity, 0, 0, owner, MAX, true, v, r, s
                ) {
                    // POSTCONDTION:
                    (uint256 reserveAAfter, uint256 reserveBAfter,) = testStablePair.getReserves();
                    (uint256 totalSupplyAfter) = testStablePair.totalSupply();
                    (uint256 userBalAfter) = testStablePair.balanceOf(address(this));
                    uint256 kAfter = reserveAAfter * reserveBAfter;

                    assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                    assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                    assertLt(kAfter, kBefore, "K CHECK");
                    assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                    assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
                } catch { /*assert(false)*/ } // overflow
            }
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Removing liquidity from a pair should:
     * Decrease reserves
     * Decrease address to balance
     * Decrease totalSupply
     * Decrease K
    */
    function testFuzz_removeLiqETHWithPermit(uint256 amount) public {
        // PRECONDTION:
        amount = bound(amount, (10 ** 3), MAX);

        if (!setPermitETHFee) {
            _initPermitETH(owner, amount);
            vm.startPrank(owner);
            weth.approve(address(testRouter02), amount);
            usdc.approve(address(testRouter02), amount);
        }

        try testRouter02.addLiquidityETH{value: amount}(address(usdc), amount, 0, 0, owner, MAX) returns (
            uint256, uint256, uint256 liquidity
        ) {
            (uint256 reserveABefore, uint256 reserveBBefore,) = testWethPair.getReserves();
            (uint256 totalSupplyBefore) = testWethPair.totalSupply();
            (uint256 userBalBefore) = testWethPair.balanceOf(address(this));
            uint256 kBefore = reserveABefore * reserveBBefore;

            //if (approveMax) {
            liquidity = type(uint256).max;
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                privateKey,
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        testStablePair.DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(PERMIT_TYPEHASH, owner, address(testRouter02), liquidity, 0, block.timestamp + 1)
                        )
                    )
                )
            );

            // ACTION:
            try testRouter02.removeLiquidityETHWithPermit(
                address(usdc), liquidity, 0, 0, owner, MAX, /*approveMax*/ true, v, r, s
            ) {
                // POSTCONDTION:
                (uint256 reserveAAfter, uint256 reserveBAfter,) = testWethPair.getReserves();
                (uint256 totalSupplyAfter) = testWethPair.totalSupply();
                (uint256 userBalAfter) = testWethPair.balanceOf(address(this));
                uint256 kAfter = reserveAAfter * reserveBAfter;

                assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                assertLt(kAfter, kBefore, "K CHECK");
                assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            } catch { /*assert(false)*/ } // overflow
                /*
            } else {
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    privateKey,
                    keccak256(
                        abi.encodePacked(
                            "\x19\x01",
                            testStablePair.DOMAIN_SEPARATOR(),
                            keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(testRouter02), liquidity, 0, deadline))
                        )
                    )
                );
                // ACTION:
                try testRouter02.removeLiquidityETHWithPermit(
                    address(usdc), liquidity, 0, 0, owner, MAX, approveMax, v, r, s
                ) {
                    // POSTCONDTION:
                    (uint256 reserveAAfter, uint256 reserveBAfter,) = testWethPair.getReserves();
                    (uint256 totalSupplyAfter) = testWethPair.totalSupply();
                    (uint256 userBalAfter) = testWethPair.balanceOf(address(this));
                    uint256 kAfter = reserveAAfter * reserveBAfter;
                    assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                    assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                    assertLt(kAfter, kBefore, "K CHECK");
                    assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                    assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
                } catch { /*assert(false)* / } // overflow
            }
            */
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Removing liquidity from a pair should:
     * Decrease reserves
     * Decrease address to balance
     * Decrease totalSupply
     * Decrease K
    */
    function testFuzz_removeLiqETHSupportingFeeOnTransferTokens(uint256 amount) public {
        // PRECONDTION:
        uint256 _amount = bound(amount, (10 ** 3), MAX);

        if (!setETHFee) {
            _initETHFee(_amount);
        }

        try testRouter02.addLiquidityETH{value: _amount}(address(feeToken), _amount, 0, 0, address(this), MAX) returns (
            uint256, uint256, uint256 liquidity
        ) {
            (uint256 reserveABefore, uint256 reserveBBefore,) = testFeePair.getReserves();
            (uint256 totalSupplyBefore) = testFeePair.totalSupply();
            (uint256 userBalBefore) = testFeePair.balanceOf(address(this));
            uint256 kBefore = reserveABefore * reserveBBefore;

            // ACTION:
            try testRouter02.removeLiquidityETHSupportingFeeOnTransferTokens(
                address(feeToken), liquidity, 0, 0, address(this), MAX
            ) {
                // POSTCONDTION:
                (uint256 reserveAAfter, uint256 reserveBAfter,) = testFeePair.getReserves();
                (uint256 totalSupplyAfter) = testFeePair.totalSupply();
                (uint256 userBalAfter) = testFeePair.balanceOf(address(this));
                uint256 kAfter = reserveAAfter * reserveBAfter;

                assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                assertLt(kAfter, kBefore, "K CHECK");
                assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
            } catch { /*assert(false)*/ } // overflow
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Removing liquidity from a pair should:
     * Decrease reserves
     * Decrease address to balance
     * Decrease totalSupply
     * Decrease K
    */
    function testFuzz_removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(uint256 amount) public {
        // PRECONDTION:
        amount = bound(amount, (10 ** 3), MAX);

        if (!setPermitETHFee) {
            _initPermitETHFee(owner, amount);
            vm.startPrank(owner);
            weth.approve(address(testRouter02), amount);
            feeToken.approve(address(testRouter02), amount);
        }

        try testRouter02.addLiquidityETH{value: amount}(address(feeToken), amount, 0, 0, owner, MAX) returns (
            uint256, uint256, uint256 liquidity
        ) {
            (uint256 reserveABefore, uint256 reserveBBefore,) = testWethPair.getReserves();
            uint256 totalSupplyBefore = testWethPair.totalSupply();
            (uint256 userBalBefore) = testWethPair.balanceOf(address(this));
            uint256 kBefore = reserveABefore * reserveBBefore;

            {
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                    privateKey,
                    keccak256(
                        abi.encodePacked(
                            "\x19\x01",
                            testStablePair.DOMAIN_SEPARATOR(),
                            keccak256(
                                abi.encode(
                                    PERMIT_TYPEHASH,
                                    owner,
                                    address(testRouter02),
                                    type(uint256).max, // approveMax ? type(uint256).max : liquidity, // @todo extra test with aproveMax
                                    0,
                                    block.timestamp
                                )
                            )
                        )
                    )
                );

                // ACTION:
                try testRouter02.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
                    address(feeToken), liquidity, 0, 0, owner, MAX, true, v, r, s
                ) {
                    // POSTCONDTION:
                    (uint256 reserveAAfter, uint256 reserveBAfter,) = testWethPair.getReserves();
                    (uint256 totalSupplyAfter) = testWethPair.totalSupply();
                    (uint256 userBalAfter) = testWethPair.balanceOf(address(this));
                    uint256 kAfter = reserveAAfter * reserveBAfter;

                    assertLt(reserveAAfter, reserveABefore, "RESERVE TOKEN A CHECK");
                    assertLt(reserveBAfter, reserveBBefore, "RESERVE TOKEN B CHECK");
                    assertLt(kAfter, kBefore, "K CHECK");
                    assertLt(totalSupplyAfter, totalSupplyBefore, "TOTAL SUPPLY CHECK");
                    assertLt(userBalAfter, userBalBefore, "USER BAL CHECK");
                } catch { /*assert(false)*/ } // overflow
            }
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: swapExactTokensForTokens within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same
    */
    function testFuzz_swapExactTokensForTokens(uint256 amount) public {
        // PRECONDITIONS:
        amount = bound(amount, 1, MAX - 100000);

        testStablePair.getReserves();
        (uint256 reserveABefore, uint256 reserveBBefore) =
            PairLibrary.getReserves(address(testFactory), address(usdc), address(usdt));
        console.log("RESERVE A BEFORE: %s", reserveABefore);
        console.log("RESERVE B BEFORE: %s", reserveBBefore);
        uint256 kBefore = reserveABefore * reserveBBefore;

        if (!setStable) {
            _init(amount, amount);
            // For some reserves
            usdt.mint(address(testStablePair), 100000);
            usdc.mint(address(testStablePair), 100000);
            testStablePair.sync();
        }
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(usdt);

        uint256 userBalBefore1 = ERC20(path[0]).balanceOf(address(this));
        uint256 userBalBefore2 = ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");

        // ACTION:
        try testRouter02.swapExactTokensForTokens(amount, 0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint256 userBalAfter1 = ERC20(path[0]).balanceOf(address(this));
            uint256 userBalAfter2 = ERC20(path[1]).balanceOf(address(this));
            (uint256 reserveAAfter, uint256 reserveBAfter) =
                PairLibrary.getReserves(address(testFactory), address(usdc), address(usdt));
            uint256 kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK");
            assertLt(userBalBefore2, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same
    */
    function testFuzz_swapExactETHForTokens(uint256 amount) public {
        // PRECONDITIONS:
        uint256 _amount = bound(amount, 1, MAX);

        if (!setETH) {
            _initETH(_amount);
            // For some reserves
            try usdc.mint(address(testWethPair), 100000000000000) {} catch { /*assert(false)*/ } // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testWethPair), 100);
            testWethPair.sync();
        }
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);

        uint256 userBalBefore1 = _amount;
        uint256 userBalBefore2 = ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");

        (uint256 reserveABefore, uint256 reserveBBefore) =
            PairLibrary.getReserves(address(testFactory), address(usdc), address(weth));
        uint256 kBefore = reserveABefore * reserveBBefore;

        // ACTION:
        try testRouter02.swapExactETHForTokens{value: 1 ether}(0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint256 userBalAfter1 = weth.balanceOf(address(this));
            uint256 userBalAfter2 = ERC20(path[1]).balanceOf(address(this));
            (uint256 reserveAAfter, uint256 reserveBAfter) =
                PairLibrary.getReserves(address(testFactory), address(usdc), address(weth));
            uint256 kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK");
            assertLt(userBalBefore2, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same
    */
    function testFuzz_swapTokensForExactETH(uint256 amount) public {
        // PRECONDITIONS:
        uint256 _amount = bound(amount, 1, MAX);

        if (!setETH) {
            _initETH(_amount);
            // For some reserves
            try usdc.mint(address(testWethPair), 100000000000000) {} catch { /*assert(false)*/ } // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testWethPair), 100);
            testWethPair.sync();
        }
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);

        uint256 userBalBefore1 = ERC20(path[0]).balanceOf(address(this));
        uint256 userBalBefore2 = _amount;
        require(userBalBefore1 > 0, "NO BAL");

        (uint256 reserveABefore, uint256 reserveBBefore) =
            PairLibrary.getReserves(address(testFactory), address(usdc), address(weth));
        uint256 kBefore = reserveABefore * reserveBBefore;

        // ACTION:
        try testRouter02.swapTokensForExactETH(MAX, 0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint256 userBalAfter1 = ERC20(path[0]).balanceOf(address(this));
            uint256 userBalAfter2 = ERC20(path[1]).balanceOf(address(this));
            (uint256 reserveAAfter, uint256 reserveBAfter) =
                PairLibrary.getReserves(address(testFactory), address(usdc), address(weth));
            uint256 kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK");
            assertLt(userBalBefore2, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same
    */
    function testFuzz_swapExactTokensForETH(uint256 amount) public {
        // PRECONDITIONS:
        uint256 _amount = bound(amount, 1, MAX);

        if (!setETH) {
            _initETH(_amount);
            // For some reserves
            try usdc.mint(address(testWethPair), 100000000000000) {} catch { /*assert(false)*/ } // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testWethPair), 100);
            testWethPair.sync();
        }
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);

        uint256 userBalBefore1 = ERC20(path[0]).balanceOf(address(this));
        uint256 userBalBefore2 = _amount;
        require(userBalBefore1 > 0, "NO BAL");

        (uint256 reserveABefore, uint256 reserveBBefore) =
            PairLibrary.getReserves(address(testFactory), address(usdc), address(weth));
        uint256 kBefore = reserveABefore * reserveBBefore;

        // ACTION:
        try testRouter02.swapExactTokensForETH(MAX, 0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint256 userBalAfter1 = ERC20(path[0]).balanceOf(address(this));
            uint256 userBalAfter2 = ERC20(path[1]).balanceOf(address(this));
            (uint256 reserveAAfter, uint256 reserveBAfter) =
                PairLibrary.getReserves(address(testFactory), address(usdc), address(weth));
            uint256 kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK");
            assertLt(userBalBefore2, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same
    */
    function testFuzz_swapETHForExactTokens(uint256 amount) public {
        // PRECONDITIONS:
        uint256 _amount = bound(amount, 1, MAX);

        if (!setETH) {
            _initETH(_amount);
            // For some reserves
            try usdc.mint(address(testWethPair), 100000000000000) {} catch { /*assert(false)*/ } // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testWethPair), 100);
            testWethPair.sync();
        }
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);

        uint256 userBalBefore1 = _amount;
        uint256 userBalBefore2 = ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");

        (uint256 reserveABefore, uint256 reserveBBefore) =
            PairLibrary.getReserves(address(testFactory), address(usdc), address(weth));
        uint256 kBefore = reserveABefore * reserveBBefore;

        // ACTION:
        try testRouter02.swapExactETHForTokens{value: 1 ether}(0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint256 userBalAfter1 = weth.balanceOf(address(this));
            uint256 userBalAfter2 = ERC20(path[1]).balanceOf(address(this));
            (uint256 reserveAAfter, uint256 reserveBAfter) =
                PairLibrary.getReserves(address(testFactory), address(usdc), address(weth));
            uint256 kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK");
            assertLt(userBalBefore2, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same
    */
    function testFuzz_swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256 amount) public {
        // PRECONDITIONS:
        uint256 _amount = bound(amount, 1, MAX);
        uint256 burnAmount = _amount / 100;

        (uint256 reserveABefore, uint256 reserveBBefore) =
            PairLibrary.getReserves(address(testFactory), address(usdc), address(feeToken));
        uint256 kBefore = reserveABefore * reserveBBefore;

        if (!setFee) {
            _initFee(_amount, _amount);
            // For some reserves
            try feeToken.mint(address(testFeePair), 100000) {} catch { /*assert(false)*/ } // overflow
            try usdc.mint(address(testFeePair), 100000) {} catch { /*assert(false)*/ } // overflow
            testFeePair.sync();
        }
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(feeToken);

        uint256 userBalBefore1 = ERC20(path[0]).balanceOf(address(this));
        uint256 userBalBefore2 = ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");

        // ACTION:
        try testRouter02.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, 0, path, address(this), MAX) {
            //POSTCONDITIONS:
            uint256 userBalAfter1 = ERC20(path[0]).balanceOf(address(this));
            uint256 userBalAfter2 = ERC20(path[1]).balanceOf(address(this));
            (uint256 reserveAAfter, uint256 reserveBAfter) =
                PairLibrary.getReserves(address(testFactory), address(usdc), address(feeToken));
            uint256 kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK");
            assertLt(userBalBefore2 - burnAmount, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same
    */
    function testFuzz_swapExactETHForTokensSupportingFeeOnTransferTokens(uint256 amount) public {
        // PRECONDTION:
        uint256 _amount = bound(amount, (10 ** 3), MAX);
        uint256 burnAmount = _amount / 100;

        (uint256 reserveABefore, uint256 reserveBBefore) =
            PairLibrary.getReserves(address(testFactory), address(weth), address(feeToken));
        uint256 kBefore = reserveABefore * reserveBBefore;

        if (!setETHFee) {
            _initETHFee(_amount);
            // For some reserves
            try feeToken.mint(address(testFeeWethPair), 100000) {} catch { /*assert(false)*/ } // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testFeeWethPair), 100);
            testFeeWethPair.sync();
        }

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(feeToken);

        uint256 userBalBefore1 = ERC20(path[0]).balanceOf(address(this));
        uint256 userBalBefore2 = ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");

        // ACTION:
        try testRouter02.swapExactETHForTokensSupportingFeeOnTransferTokens{value: _amount}(0, path, address(this), MAX)
        {
            // POSTCONDTION:
            uint256 userBalAfter1 = ERC20(path[0]).balanceOf(address(this));
            uint256 userBalAfter2 = ERC20(path[1]).balanceOf(address(this));
            (uint256 reserveAAfter, uint256 reserveBAfter) =
                PairLibrary.getReserves(address(testFactory), address(usdc), address(feeToken));
            uint256 kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK");
            assertLt(userBalBefore2 - burnAmount, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch { /*assert(false)*/ } // overflow
    }

    /* INVARIANT: Swapping within a pair should:
     * Decrease balance of user for token 2
     * Increase balance of user for token 1
     * K should decrease or remain the same
    */
    function testFuzz_swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amount) public {
        // PRECONDTION:
        uint256 _amount = bound(amount, (10 ** 3), MAX);
        uint256 burnAmount = _amount / 100;

        (uint256 reserveABefore, uint256 reserveBBefore) =
            PairLibrary.getReserves(address(testFactory), address(weth), address(feeToken));
        uint256 kBefore = reserveABefore * reserveBBefore;

        if (!setETHFee) {
            _initETHFee(_amount);
            // For some reserves
            try feeToken.mint(address(testFeeWethPair), 100000) {} catch { /*assert(false)*/ } // overflow
            vm.deal(address(this), 100 ether);
            weth.deposit{value: 100 ether}();
            weth.transfer(address(testFeeWethPair), 100);
            testFeeWethPair.sync();
        }

        address[] memory path = new address[](2);
        path[0] = address(feeToken);
        path[1] = address(weth);

        uint256 userBalBefore1 = ERC20(path[0]).balanceOf(address(this));
        uint256 userBalBefore2 = ERC20(path[1]).balanceOf(address(this));
        require(userBalBefore1 > 0, "NO BAL");

        // ACTION:
        try testRouter02.swapExactTokensForETHSupportingFeeOnTransferTokens(_amount, 0, path, address(this), MAX) {
            // POSTCONDTION:
            uint256 userBalAfter1 = ERC20(path[0]).balanceOf(address(this));
            uint256 userBalAfter2 = ERC20(path[1]).balanceOf(address(this));
            (uint256 reserveAAfter, uint256 reserveBAfter) =
                PairLibrary.getReserves(address(testFactory), address(usdc), address(feeToken));
            uint256 kAfter = reserveAAfter * reserveBAfter;

            assertGe(kAfter, kBefore, "K CHECK");
            assertLt(userBalBefore2 - burnAmount, userBalAfter2, "USER BAL 2 CHECK");
            assertGt(userBalBefore1, userBalAfter1, "USER BAL 1 CHECK");
        } catch { /*assert(false)*/ } // overflow
    }

    // Helper functions to mint tokens when necessary
    bool setStable;

    function _init(uint256 amount1, uint256 amount2) internal {
        usdt.mint(address(this), amount2);
        usdc.mint(address(this), amount1);
        setStable = true;
    }

    bool setPermit;

    function _initPermit(address _owner, uint256 amount1, uint256 amount2) internal {
        usdt.mint(_owner, amount2);
        usdc.mint(_owner, amount1);
        setPermit = true;
    }

    bool setPermitETHFee;

    function _initPermitETHFee(address _owner, uint256 amount) internal {
        vm.deal(_owner, amount);
        feeToken.mint(_owner, amount);
        setPermitETHFee = true;
    }

    bool setPermitETH;

    function _initPermitETH(address _owner, uint256 amount) internal {
        vm.deal(_owner, amount);
        try feeToken.mint(_owner, amount) {} catch { /*assert(false)*/ } // overflow
        setPermitETH = true;
    }

    bool setFee;

    function _initFee(uint256 amount1, uint256 amount2) internal {
        feeToken.mint(address(this), amount2);
        usdc.mint(address(this), amount1);
        setFee = true;
    }

    bool setETHFee;

    function _initETHFee(uint256 amount) internal {
        vm.deal(address(this), amount);
        feeToken.mint(address(this), amount);
        setETHFee = true;
    }

    bool setETH;

    function _initETH(uint256 amount) internal {
        vm.deal(address(this), amount);
        usdc.mint(address(this), amount);
        setETH = true;
    }
}

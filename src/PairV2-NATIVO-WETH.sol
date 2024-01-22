// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {IUniswapV2Callee} from "v2-core/interfaces/IUniswapV2Callee.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC1363} from "./ERC1363.sol";
import {IPairLatamSwap} from "./interfaces/IPairLatamSwap.sol";
import {IGenericWETH} from "./interfaces/IGenericWETH.sol";

contract PairV2Native is ERC20, ERC1363, ReentrancyGuard, IPairLatamSwap {
    using SafeTransferLib for address;

    error ErrFunctionDisabled();
    error ErrEtherReject();

    // 10 ** 3 = 1e3 = 1000
    uint256 public constant MINIMUM_LIQUIDITY = 1e3;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;

    //type(uint112).max; // uses single storage slot, accessible via getReserves
    uint112 private constant reserve0 = type(uint112).max;
    // uses single storage slot, accessible via getReserves
    uint112 private constant reserve1 = type(uint112).max;
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint256 public constant price0CumulativeLast = 1 ether;
    uint256 public constant price1CumulativeLast = 1 ether;
    // kLast = type(uint112).max * type(uint112).max
    uint256 public constant kLast = type(uint112).max * type(uint112).max;

    function name() public view override returns (string memory) {
        return "LatamSwap PairV2";
    }

    function symbol() public view override returns (string memory) {
        // max length allowed is 11 characters
        return "LATAMSWP-V2";
    }

    function totalSupply() public view override returns (uint256 result) {
        result = type(uint256).max;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    constructor(address _token0, address _token1, address _factory) {
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external returns (uint256) {
        revert ErrFunctionDisabled();
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external returns (uint256, uint256) {
        revert ErrFunctionDisabled();
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        revert ErrFunctionDisabled();
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        revert ErrFunctionDisabled();
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external nonReentrant {
        if (to == token0 || to == token1) revert ErrLatamswapInvalidTo();

        blockTimestampLast = uint32(block.timestamp);

        amount0Out = token0.balanceOf(address(this));
        amount1Out = token1.balanceOf(address(this));

        if (amount1Out > 0) {
            IGenericWETH(token1).withdraw(amount1Out);
            IGenericWETH(token0).deposit{value: amount1Out}();
        }

        if (amount0Out > 0) {
            IGenericWETH(token0).withdraw(amount0Out);
            IGenericWETH(token1).deposit{value: amount0Out}();
        }

        blockTimestampLast = uint32(block.timestamp);

        // @dev reuse variable declarations to avoid extra vars
        amount0Out = token0.balanceOf(address(this));
        amount1Out = token1.balanceOf(address(this));

        if (amount0Out > 0) token0.safeTransfer(to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) token1.safeTransfer(to, amount1Out); // optimistically transfer tokens

        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);

        emit Swap(msg.sender, amount0Out, amount1Out, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external nonReentrant {
        uint256 amount0 = token0.balanceOf(address(this));
        uint256 amount1 = token1.balanceOf(address(this));

        if (amount0 > 0) token0.safeTransfer(to, amount0); // optimistically transfer tokens
        if (amount1 > 0) token1.safeTransfer(to, amount1); // optimistically transfer tokens
    }

    // force reserves to match balances
    function sync() external nonReentrant {
        revert ErrFunctionDisabled();
    }

    function approveAndCall(address spender, uint256 amount) external override returns (bool) {
        revert ErrFunctionDisabled();
    }

    function approveAndCall(address spender, uint256 amount, bytes memory data) public override returns (bool) {
        revert ErrFunctionDisabled();
    }

    function transferAndCall(address to, uint256 amount) public override returns (bool) {
        revert ErrFunctionDisabled();
    }

    function transferAndCall(address to, uint256 amount, bytes memory data) public override returns (bool) {
        revert ErrFunctionDisabled();
    }

    function transferFromAndCall(address from, address to, uint256 amount) external override returns (bool) {
        revert ErrFunctionDisabled();
    }

    function transferFromAndCall(address from, address to, uint256 amount, bytes memory data)
        public
        override
        returns (bool)
    {
        revert ErrFunctionDisabled();
    }

    receive() external payable {
        if (msg.sender != token0 && msg.sender != token1) revert ErrEtherReject();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {IUniswapV2Callee} from "v2-core/interfaces/IUniswapV2Callee.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC1363} from "./ERC1363.sol";
import {IPairLatamSwap} from "./interfaces/IPairLatamSwap.sol";

    
interface INativeWrap {
    function withdraw(uint256 amount) external;
    function deposit() external payable;
}

contract PairV2Native is ERC20, ERC1363, ReentrancyGuard, IPairLatamSwap {
    using SafeTransferLib for address;

    // 10 ** 3 = 1e3 = 1000
    uint256 public constant MINIMUM_LIQUIDITY = 1e3;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0 = type(uint112).max; // uses single storage slot, accessible via getReserves
    uint112 private reserve1 = type(uint112).max; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint256 public price0CumulativeLast = 1 ether;
    uint256 public price1CumulativeLast = 1 ether;
    uint256 public kLast = type(uint256).max;

    function name() public view override returns (string memory) {
        return "LatamSwap PairV2";
    }

    function symbol() public view override returns (string memory) {
        // max length allowed is 11 characters
        return "LATAMSWP-V2";
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
        revert('mint disabled');
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external returns (uint256, uint256) {
        revert('burn disabled');
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        revert('transfer disabled');
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        revert('transferFrom disabled');
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) revert ErrLatamswapInsufficientOutputAmount();
        if (to == token0 || to == token1) revert ErrLatamswapInvalidTo();

        blockTimestampLast = uint32(block.timestamp);
        
        if (amount0Out > amount1Out) {
            INativeWrap(token0).withdraw(amount0Out - amount1Out);
            INativeWrap(token1).deposit{value: amount0Out - amount1Out}();    
        } else {
            INativeWrap(token1).withdraw(amount1Out - amount0Out);
            INativeWrap(token0).deposit{value: amount1Out - amount0Out}();    
        }

        amount0Out = token0.balanceOf(address(this));
        amount1Out = token1.balanceOf(address(this));

        if (amount0Out > 0) token0.safeTransfer(to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) token1.safeTransfer(to, amount1Out); // optimistically transfer tokens
            
        emit Swap(msg.sender, amount0Out, amount1Out, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external {
        // empty funcion doesnt do anything
    }

    // force reserves to match balances
    function sync() external nonReentrant {
        // empty funcion doesnt do anything
    }

    receive() external payable {
        require(msg.sender == token0 || msg.sender == token1, "Latamswap: Cannot receive ETH");
    }
}

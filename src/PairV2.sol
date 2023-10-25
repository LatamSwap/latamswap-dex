// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {UQ112x112} from "./utils/UQ112x112.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {IUniswapV2Callee} from "v2-core/interfaces/IUniswapV2Callee.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC1363} from "./ERC1363.sol";

contract PairV2 is ERC20, ERC1363, ReentrancyGuard {
    using SafeTransferLib for address;
    using UQ112x112 for uint224;

    // 10 ** 3 = 1e3 = 1000
    uint256 public constant MINIMUM_LIQUIDITY = 1e3;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    function name() public view override returns (string memory) {
        return "LatamSwap PairV2";
    }

    function symbol() public view override returns (string memory) {
        return "LATAMSWAP-V2";
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    error ErrLatamswapWrongK();
    error ErrLatamswapOverflow();
    error ErrLatamswapInsufficientLiquidity();
    error ErrLatamswapInsufficientLiquidityBurned();
    error ErrLatamswapInsufficientOutputAmount();
    error ErrLatamswapInvalidTo();
    error ErrLatamswapInsufficientInputAmount();

    constructor(address _token0, address _token1) {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) {
            revert ErrLatamswapOverflow();
        }

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp - blockTimestampLast); // overflow is desired
            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                // * never overflows, and + overflow is desired
                price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }

            reserve0 = uint112(balance0);
            reserve1 = uint112(balance1);
            blockTimestampLast = uint32(block.timestamp);
        }

        emit Sync(reserve0, reserve1);
    }

    // fee is always on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private {
        uint256 _kLast = kLast; // gas savings
        if (_kLast != 0) {
            uint256 rootK = FixedPointMathLib.sqrt(uint256(_reserve0) * uint256(_reserve1));
            uint256 rootKLast = FixedPointMathLib.sqrt(_kLast);
            if (rootK > rootKLast) {
                uint256 numerator = totalSupply() * (rootK - rootKLast);
                uint256 denominator = rootK * 5 + rootKLast;
                unchecked {
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(factory, liquidity);
                }
            }
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(amount0 * amount1);
            if (liquidity <= MINIMUM_LIQUIDITY) {
                revert ErrLatamswapInsufficientLiquidity();
            }
            liquidity -= MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity =
                FixedPointMathLib.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }

        if (liquidity == 0) revert ErrLatamswapInsufficientLiquidity();

        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        kLast = uint256(reserve0) * uint256(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity * balance0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity * balance1 / _totalSupply; // using balances ensures pro-rata distribution
        if (amount0 == 0 || amount1 == 0) revert ErrLatamswapInsufficientLiquidityBurned();
        _burn(address(this), liquidity);
        token0.safeTransfer(to, amount0);
        token1.safeTransfer(to, amount1);
        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        kLast = uint256(reserve0) * uint256(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) revert ErrLatamswapInsufficientOutputAmount();
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        if (amount0Out >= _reserve0 || amount1Out >= _reserve1) revert ErrLatamswapInsufficientLiquidity();

        if (to == token0 || to == token1) revert ErrLatamswapInvalidTo();
        if (amount0Out > 0) token0.safeTransfer(to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) token1.safeTransfer(to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        uint256 amount0In;
        uint256 amount1In;

        unchecked {
            uint256 aux = _reserve0 - amount0Out;
            amount0In = balance0 > aux ? balance0 - aux : 0;
            aux = _reserve1 - amount1Out;
            amount1In = balance1 > aux ? balance1 - aux : 0;
        }

        if (amount0In == 0 && amount1In == 0) revert ErrLatamswapInsufficientInputAmount();
        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint256 balance0Adjusted = balance0 * 1_000 - (amount0In * 3);
            uint256 balance1Adjusted = balance1 * 1_000 - (amount1In * 3);

            if ((balance0Adjusted * balance1Adjusted) < (uint256(_reserve0) * _reserve1 * 1_000_000)) {
                revert ErrLatamswapWrongK();
            }
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external nonReentrant {
        token0.safeTransfer(to, token0.balanceOf(address(this)) - reserve0);
        token1.safeTransfer(to, token1.balanceOf(address(this)) - reserve1);
    }

    // force reserves to match balances
    function sync() external nonReentrant {
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)), reserve0, reserve1);
    }
}

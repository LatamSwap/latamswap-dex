// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {UQ112x112} from "./utils/UQ112x112.sol";
import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";

import {IUniswapV2Callee} from "v2-core/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";

import {ERC20} from "./ERC20-pair.sol";

contract PairV2 is ERC20, ReentrancyGuard {
    using UQ112x112 for uint224;
    using SafeTransferLib for address;

    error errOverflow();
    error errInsufficientLiquidityMinted();
    error errInsufficientLiquidityBurned();
    error errInsufficientOutputAmount();

    // reserve slots for balance storage
    uint256[1<<160] private __gapBalances;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;

    address private immutable feeTo;
    
    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves
    
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

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

    constructor(address _token0, address _token1) ERC20() {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
        feeTo = IUniswapV2Factory(factory).feeTo();
    }

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) {
            revert errOverflow();
        }
        unchecked {
            uint256 timeElapsed = block.timestamp - uint256(blockTimestampLast); // overflow is desired
            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                // * never overflows, and + overflow is desired
                price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
            blockTimestampLast = uint32(block.timestamp);
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) internal {
        uint256 _kLast = kLast; // gas savings
        if (_kLast > 0) {
            uint256 rootK = FixedPointMathLib.sqrt(uint256(_reserve0) * uint256(_reserve1));
            uint256 rootKLast = FixedPointMathLib.sqrt(_kLast);
            if (rootK > rootKLast) {
                uint256 liquidity;
                assembly {
                    // uint256 numerator = totalSupply() * (rootK - rootKLast);
                    let numerator := mul(sload(_TOTALSUPPLY_SLOT), sub(rootK, rootKLast))
                    // uint256 denominator = rootK * 5 + rootKLast;
                    let denominator := add(mul(rootK, 5), rootKLast)

                    // uint256 liquidity = numerator / denominator;
                    liquidity := div(numerator, denominator)
                }
                // 1/6th of the growth in sqrt(k)
                if (liquidity > 0) _mint(feeTo, liquidity);
            }
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        uint112 _reserve0 = reserve0;
        uint112 _reserve1 = reserve1;
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;
        // gas savings, must be defined here since totalSupply can update in _mintFee
        // uint256 cacheTotalSupply = totalSupply();
        uint256 cacheTotalSupply;
        assembly {
            cacheTotalSupply := sload(_TOTALSUPPLY_SLOT)
        }

        if (cacheTotalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            // permanently nonReentrant the first MINIMUM_LIQUIDITY tokens
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity =
                FixedPointMathLib.min(amount0 * cacheTotalSupply / _reserve0, amount1 * cacheTotalSupply / _reserve1);
        }
        if (liquidity == 0) {
            revert errInsufficientLiquidityMinted();
        }
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);

        kLast = uint256(reserve0) * uint256(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        uint112 _reserve0 = reserve0;
        uint112 _reserve1 = reserve1;

        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        // uint256 liquidity = balanceOf(address(this));
        uint256 liquidity;

        assembly {
            liquidity := sload(address())
        }

        _mintFee(_reserve0, _reserve1);
        // uint256 cacheTotalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        uint256 cacheTotalSupply;
        assembly {
            cacheTotalSupply := sload(_TOTALSUPPLY_SLOT)
        }

        //unchecked {
        //amount0 = liquidity * balance0 / cacheTotalSupply; // cacheTotalSupply; // using balances ensures pro-rata distribution
        //amount1 = liquidity * balance1 / cacheTotalSupply; // cacheTotalSupply; // using balances ensures pro-rata distribution
        //}
        assembly {
            amount0 := div(mul(liquidity, balance0), cacheTotalSupply)
            amount1 := div(mul(liquidity, balance1), cacheTotalSupply)
        }

        if (amount0 == 0 || amount1 == 0) {
            revert errInsufficientLiquidityBurned();
        }
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
        if (amount0Out == 0 && amount1Out == 0) {
            revert errInsufficientOutputAmount();
        }
        uint112 _reserve0 = reserve0;
        uint112 _reserve1 = reserve1;
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "INSUFFICIENT_LIQUIDITY");

        // scope for _token{0,1}, avoids stack too deep errors
        require(to != token0 && to != token1, "INVALID_TO");
        if (amount0Out > 0) token0.safeTransfer(to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) token1.safeTransfer(to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        uint256 amount0In;
        uint256 amount1In;
        /*
        unchecked {
            uint256 _aux = _reserve0 - amount0Out;
            if (balance0 > _aux) {
                amount0In = balance0 - _aux;
            }
            _aux = _reserve1 - amount1Out;
            if (balance1 > _aux) {
                amount1In = balance1 - _aux;
            }
        }
        */
        assembly {
            let _aux := sub(_reserve0, amount0Out)
            if gt(balance0, _aux) {
                amount0In := sub(balance0, _aux)
            }
            _aux := sub(_reserve1, amount1Out)
            if gt(balance1, _aux) {
                amount1In := sub(balance1, _aux)
            }
        }

        if (amount0In == 0 && amount1In == 0) {
            revert("INSUFFICIENT_INPUT_AMOUNT");
        }
        _update(balance0, balance1, _reserve0, _reserve1);

        // uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        // uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;

        // 1_000_000 = 1000**2

        // inlining the following to avoid stack too deep
        require(
            (balance0 * 1000 - amount0In * 3) // balance0Adjusted
                * (balance1 * 1000 - amount1In * 3) // balance1Adjusted
                >= uint256(_reserve0) * uint256(_reserve1) * 1_000_000,
            "invalid K"
        );

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

pragma solidity 0.8.23;

import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ILatamSwapRouter} from "./interfaces/ILatamSwapRouter.sol";
import {PairLibrary} from "./PairLibrary.sol";
import {PairV2} from "./PairV2.sol";
import {INativo} from "nativo/INativo.sol";

contract LatamswapRouter is ILatamSwapRouter {

    using SafeTransferLib for address;

    address public immutable factory;
    address public immutable NATIVO;
    address public immutable WETH;

    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp) revert ErrExpired();
        _;
    }

    constructor(address _factory, address _nativo) {
        factory = _factory;
        NATIVO = _nativo;
        WETH = _nativo;
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            (uint256 reserveA, uint256 reserveB) = PairLibrary.getReserves(factory, tokenA, tokenB);

            uint256 amountBOptimal = PairLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal > amountBDesired) {
                uint256 amountAOptimal = PairLibrary.quote(amountBDesired, reserveB, reserveA);
                if (amountAOptimal > amountADesired) revert ErrInsufficientQuoteA();
                if (amountAOptimal < amountAMin) revert ErrInsufficientAmountA();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            } else {
                if (amountBOptimal < amountBMin) revert ErrInsufficientAmountB();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = PairLibrary.pairFor(factory, tokenA, tokenB);
        SafeTransferLib.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        SafeTransferLib.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = PairV2(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        (amountToken, amountETH) =
            _addLiquidity(token, NATIVO, amountTokenDesired, msg.value, amountTokenMin, amountETHMin);
        address pair = PairLibrary.pairFor(factory, token, NATIVO);
        token.safeTransferFrom(msg.sender, pair, amountToken);
        INativo(payable(NATIVO)).depositTo{value: amountETH}(pair);
        liquidity = PairV2(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) msg.sender.safeTransferETH(msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = PairLibrary.pairFor(factory, tokenA, tokenB);
        PairV2(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = PairV2(pair).burn(to);
        (address token0,) = PairLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        if (amountA < amountAMin) revert ErrInsufficientAmountA();
        if (amountB < amountBMin) revert ErrInsufficientAmountB();
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) =
            removeLiquidity(token, NATIVO, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
        SafeTransferLib.safeTransfer(token, to, amountToken);
        INativo(payable(NATIVO)).withdrawTo(to, amountETH);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB) {
        address pair = PairLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        PairV2(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH) {
        address pair = PairLibrary.pairFor(factory, token, NATIVO);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        PairV2(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public returns (uint256 amountETH) {
        (, amountETH) = removeLiquidity(token, NATIVO, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
        SafeTransferLib.safeTransfer(token, to, token.balanceOf(address(this)));
        INativo(payable(NATIVO)).withdrawTo(to, amountETH);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH) {
        address pair = PairLibrary.pairFor(factory, token, NATIVO);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        PairV2(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] calldata path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1;) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PairLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? PairLibrary.pairFor(factory, output, path[i + 2]) : _to;
            PairV2(PairLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, "");

            unchecked {
                ++i;
            }
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = PairLibrary.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert ErrInsufficientOutputAmount();
        SafeTransferLib.safeTransferFrom(
            path[0], msg.sender, PairLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = PairLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax) revert ErrExcessiveInputAmount();
        SafeTransferLib.safeTransferFrom(
            path[0], msg.sender, PairLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        if (path[0] != NATIVO) revert ErrInvalidPath();
        amounts = PairLibrary.getAmountsOut(factory, msg.value, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert ErrInsufficientOutputAmount();
        INativo(payable(NATIVO)).depositTo{value: amounts[0]}(PairLibrary.pairFor(factory, path[0], path[1]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        if (path[path.length - 1] != NATIVO) revert ErrInvalidPath();
        amounts = PairLibrary.getAmountsIn(factory, amountOut, path);
        // Overall gas change: -261368 (-1.761%)
        if (amounts[0] > amountInMax) revert ErrExcessiveInputAmount();
        SafeTransferLib.safeTransferFrom(
            path[0], msg.sender, PairLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        INativo(payable(NATIVO)).withdrawTo(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        if (path[path.length - 1] != NATIVO) revert ErrInvalidPath();
        amounts = PairLibrary.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert ErrInsufficientOutputAmount();
        SafeTransferLib.safeTransferFrom(
            path[0], msg.sender, PairLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        INativo(payable(NATIVO)).withdrawTo(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        if (path[0] != NATIVO) revert ErrInvalidPath();
        amounts = PairLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > msg.value) revert ErrExcessiveInputAmount();
        INativo(payable(NATIVO)).depositTo{value: amounts[0]}(PairLibrary.pairFor(factory, path[0], path[1]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) SafeTransferLib.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1;) {
            address input;
            address output;

            unchecked {
                (input, output) = (path[i], path[i + 1]);
            }
            (address token0,) = PairLibrary.sortTokens(input, output);
            PairV2 pair = PairV2(PairLibrary.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = input.balanceOf(address(pair)) - (reserveInput);
                amountOutput = PairLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            unchecked {
                (uint256 amount0Out, uint256 amount1Out) =
                    input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
                address to = i < path.length - 2 ? PairLibrary.pairFor(factory, output, path[i + 2]) : _to;
                pair.swap(amount0Out, amount1Out, to, "");
                ++i;
            }
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) {
        SafeTransferLib.safeTransferFrom(path[0], msg.sender, PairLibrary.pairFor(factory, path[0], path[1]), amountIn);
        uint256 balanceBefore = path[path.length - 1].balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        if (path[path.length - 1].balanceOf(to) - balanceBefore < amountOutMin) revert ErrInsufficientOutputAmount();
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        if (path[0] != NATIVO) revert ErrInvalidPath();
        INativo(payable(NATIVO)).depositTo{value: msg.value}(PairLibrary.pairFor(factory, path[0], path[1]));
        uint256 balanceBefore = path[path.length - 1].balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        if (path[path.length - 1].balanceOf(to) - balanceBefore < amountOutMin) revert ErrInsufficientOutputAmount();
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        if (path[path.length - 1] != NATIVO) revert ErrInvalidPath();
        SafeTransferLib.safeTransferFrom(path[0], msg.sender, PairLibrary.pairFor(factory, path[0], path[1]), amountIn);
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = NATIVO.balanceOf(address(this));
        if (amountOut < amountOutMin) revert ErrInsufficientOutputAmount();
        INativo(payable(NATIVO)).withdrawTo(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB) {
        return PairLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        virtual
        override
        returns (uint256 amountOut)
    {
        return PairLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        virtual
        override
        returns (uint256 amountIn)
    {
        return PairLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return PairLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return PairLibrary.getAmountsIn(factory, amountOut, path);
    }
}

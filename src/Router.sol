pragma solidity ^0.8.0;

import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {PairV2Library} from "./PairV2Library.sol";
//import 'v2-periphery/libraries/SafeMath.sol';
import {PairV2} from "./PairV2.sol";
import {INativo} from "nativo/INativo.sol";
import {IWETH} from "v2-periphery/interfaces/IWETH.sol";

contract UniswapV2Router02 is IUniswapV2Router02 {
    using SafeTransferLib for address;

    address public immutable factory;
    address public immutable WETH;
    address public immutable NATIVO;

    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp) {
            revert("UniswapV2Router: EXPIRED");
        }
        _;
    }

    constructor(address _factory, address _WETH, address _NATIVO) public {
        factory = _factory;
        WETH = _WETH;
        NATIVO = _NATIVO;
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
            (uint256 reserveA, uint256 reserveB) = PairV2Library.getReserves(factory, tokenA, tokenB);

            uint256 amountBOptimal = PairV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal > amountBDesired) {
                uint256 amountAOptimal = PairV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                if (amountAOptimal < amountAMin) revert("Router: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            } else {
                if (amountBOptimal < amountBMin) revert("Router: INSUFFICIENT_B_AMOUNT");
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
        address pair = PairV2Library.pairFor(factory, tokenA, tokenB);
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
        address pair = PairV2Library.pairFor(factory, token, NATIVO);
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
        address pair = PairV2Library.pairFor(factory, tokenA, tokenB);
        PairV2(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = PairV2(pair).burn(to);
        (address token0,) = PairV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        if (amountA < amountAMin) revert("Router: INSUFFICIENT_A_AMOUNT");
        if (amountB < amountBMin) revert("Router: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
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
        address pair = PairV2Library.pairFor(factory, tokenA, tokenB);
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
        address pair = PairV2Library.pairFor(factory, token, NATIVO);
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
    ) public ensure(deadline) returns (uint256 amountETH) {
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
        address pair = PairV2Library.pairFor(factory, token, NATIVO);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        PairV2(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PairV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? PairV2Library.pairFor(factory, output, path[i + 2]) : _to;
            PairV2(PairV2Library.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, "");
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = PairV2Library.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert("Router: INSUFFICIENT_OUTPUT_AMOUNT");
        SafeTransferLib.safeTransferFrom(
            path[0], msg.sender, PairV2Library.pairFor(factory, path[0], path[1]), amounts[0]
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
        amounts = PairV2Library.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax) revert("Router: EXCESSIVE_INPUT_AMOUNT");
        SafeTransferLib.safeTransferFrom(
            path[0], msg.sender, PairV2Library.pairFor(factory, path[0], path[1]), amounts[0]
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
        if (path[0] != NATIVO) revert("Router: INVALID_PATH");
        amounts = PairV2Library.getAmountsOut(factory, msg.value, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert("Router: INSUFFICIENT_OUTPUT_AMOUNT");
        INativo(payable(NATIVO)).depositTo{value: amounts[0]}(PairV2Library.pairFor(factory, path[0], path[1]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == NATIVO, "UniswapV2Router: INVALID_PATH");
        amounts = PairV2Library.getAmountsIn(factory, amountOut, path);
        // Overall gas change: -261368 (-1.761%)
        require(amounts[0] <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        SafeTransferLib.safeTransferFrom(
            path[0], msg.sender, PairV2Library.pairFor(factory, path[0], path[1]), amounts[0]
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
        require(path[path.length - 1] == NATIVO, "UniswapV2Router: INVALID_PATH");
        amounts = PairV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        SafeTransferLib.safeTransferFrom(
            path[0], msg.sender, PairV2Library.pairFor(factory, path[0], path[1]), amounts[0]
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
        require(path[0] == NATIVO, "UniswapV2Router: INVALID_PATH");
        amounts = PairV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        INativo(payable(NATIVO)).depositTo{value: amounts[0]}(
          PairV2Library.pairFor(factory, path[0], path[1])
        );
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) SafeTransferLib.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        address input;
        address output;

        for (uint256 i; i < path.length - 1;) {
            unchecked {
                (input, output) = (path[i], path[i + 1]);
            }
            (address token0,) = PairV2Library.sortTokens(input, output);
            PairV2 pair = PairV2(PairV2Library.pairFor(factory, input, output));

            uint256 amountInput;
            uint256 amountOutput;
            {
                (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = input.balanceOf(address(pair)) - (reserveInput);
                amountOutput = PairV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }

            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            if (i < path.length - 2) {
                pair.swap(amount0Out, amount1Out, PairV2Library.pairFor(factory, output, path[i + 2]), "");
            } else {
                pair.swap(amount0Out, amount1Out, _to, "");
            }
            assembly {
                i := add(i, 1)
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
        SafeTransferLib.safeTransferFrom(
            path[0], msg.sender, PairV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        uint256 balanceBefore = path[path.length - 1].balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            path[path.length - 1].balanceOf(to) - balanceBefore >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == NATIVO, "INVALID_PATH");
        uint256 amountIn = msg.value;
        INativo(payable(NATIVO)).depositTo{value: amountIn}(
          PairV2Library.pairFor(factory, path[0], path[1])
        );
        uint256 balanceBefore = path[path.length - 1].balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        if (path[path.length - 1].balanceOf(to) - balanceBefore < amountOutMin) {
            revert("INSUFFICIENT_OUTPUT_AMOUNT");
        }
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == NATIVO, "UniswapV2Router: INVALID_PATH");
        SafeTransferLib.safeTransferFrom(
            path[0], msg.sender, PairV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = NATIVO.balanceOf(address(this));
        require(amountOut >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        INativo(payable(NATIVO)).withdrawTo(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        return PairV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountOut)
    {
        return PairV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountIn)
    {
        return PairV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return PairV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return PairV2Library.getAmountsIn(factory, amountOut, path);
    }
}

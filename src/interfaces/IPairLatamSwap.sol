// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IPairLatamSwap {
    function MINIMUM_LIQUIDITY() external view returns (uint256 MINIMUM_LIQUIDITY);

    function factory() external view returns (address factory);
    function token0() external view returns (address token0);
    function token1() external view returns (address token1);

    function price0CumulativeLast() external view returns (uint256 price0CumulativeLast);
    function price1CumulativeLast() external view returns (uint256 price1CumulativeLast);
    function kLast() external view returns (uint256 kLast);

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);

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

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    // force balances to match reserves
    function skim(address to) external;

    // force reserves to match balances
    function sync() external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {CREATE3} from "solady/utils/CREATE3.sol";

import {PairV2} from "./PairV2.sol";
import {PairV2Native} from "./PairV2-NATIVO-WETH.sol";
import {PairLibrary} from "./PairLibrary.sol";

/**
 * @title LatamswapFactory
 * @dev This contract is responsible for creating and managing token pairs on Latamswap.
 * @notice This contract is used to deploy new pairs and handle safe transfers for the owner.
 * @author 0x4non LatamSwap
 */
contract LatamswapFactory is Ownable {
    using SafeTransferLib for address;

    error ErrZeroAddress();
    error ErrIdenticalAddress();
    error ErrPairExists();
    error ErrNativoMustBeDeployed();

    /// @dev Maps tokens to its pair
    mapping(address fromToken => mapping(address toToken => address pair)) public getPair;
    /// @dev Stores all created pairs
    address[] public allPairs;

    /// @dev Event emitted when a new pair is created
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 allPairsLength);

    /// @dev Initializes the owner of the contract
    constructor(address _owner, address _weth, address _nativo) {
        if (_nativo == address(0)) {
            revert ErrNativoMustBeDeployed();
        }
        if (_weth != address(0) && _nativo != _weth) {
            _createStablePair(_weth, _nativo);
        }
        _initializeOwner(_owner);
    }

    /// @dev Returns the total number of pairs.
    /// @return Total number of pairs.
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function _createStablePair(address weth, address nativo) internal returns (address pair) {
        // @dev sortTokens will revert if any address is 0 or address are identical
        (address token0, address token1) = PairLibrary.sortTokens(weth, nativo);
        if (getPair[token0][token1] != address(0)) revert ErrPairExists(); // single check is sufficient

        bytes memory creationCode =
            abi.encodePacked(type(PairV2Native).creationCode, abi.encode(token0, token1, address(this)));

        pair = CREATE3.deploy(keccak256(abi.encodePacked(token0, token1)), creationCode, 0);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev Creates a new pair with two tokens.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return pair The address of the newly created pair.
     * @notice Tokens must be different and not already have a pair.
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // @dev sortTokens will revert if any address is 0 or address are identical
        (address token0, address token1) = PairLibrary.sortTokens(tokenA, tokenB);
        if (getPair[token0][token1] != address(0)) revert ErrPairExists(); // single check is sufficient

        bytes memory creationCode =
            abi.encodePacked(type(PairV2).creationCode, abi.encode(token0, token1, address(this)));

        pair = CREATE3.deploy(keccak256(abi.encodePacked(token0, token1)), creationCode, 0);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev Allows the owner to withdraw the entire balance of a specific token.
     * @param token The token to withdraw.
     * @param to The recipient address.
     */
    function withdraw(address token, address to) external onlyOwner {
        token.safeTransferAll(to);
    }

    /**
     * @dev Allows the owner to withdraw a specified amount of a specific token.
     * @param token The token to withdraw.
     * @param to The recipient address.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev The allowance has overflowed.
    error AllowanceOverflow();

    /// @dev The allowance has underflowed.
    error AllowanceUnderflow();

    /// @dev Insufficient balance. 4bytes sig 0xf4d678b8
    error InsufficientBalance();

    /// @dev Insufficient allowance.
    error InsufficientAllowance();

    /// @dev The permit is invalid.
    error InvalidPermit();

    /// @dev The permit has expired.
    error PermitExpired();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed fxrom, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    uint8 public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/
    // idea taken from https://github.com/Philogy/meth-weth/blob/5219af2f4ab6c91f8fac37b2633da35e20345a9e/src/reference/ReferenceMETH.sol
    struct Value {
        uint256 value;
    }


    uint256[1 << 160] private __gapBalances;
    
    // @dev _TOTALSUPPLY_SLOT = uint256(keccak256("ERC20_TOTALSUPPLY")) - 1;
    uint256 internal constant _TOTALSUPPLY_SLOT = 0x80184635fb759c2e2becdf0161d7c8162d7f6308ac5335f500b64180ffc7e07a;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    
    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the name of the token.
    function name() public view returns (string memory) {
        return "LatamSwap PairV2";
    }

    /// @dev Returns the symbol of the token.
    function symbol() external view returns (string memory) {
        return "LATAMSWAP-V2";
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply().value;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balanceOf(account).value;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        /// @solidity memory-safe-assembly
        assembly {
            // balanceOf[msg.sender] -= amount;
            let _balance := sload(caller())
            if lt(_balance, amount) {
                mstore(0x00, 0xf4d678b8) // error InsufficientBalance();
                revert(0x1c, 0x04)
            }
            sstore(caller(), sub(_balance, amount))

            // Cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value.
            // unchecked {
            //    balanceOf[to] += amount;
            // }
            sstore(to, add(sload(to), amount))
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _useAllowance(from, amount);
        _transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (deadline < block.timestamp) revert PermitExpired();

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                _nonces(owner).value++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            _allowance(recoveredAddress, spender).value = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        unchecked {
            _balanceOf(to).value += amount;
            _totalSupply().value += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        Value storage _balance = _balanceOf(from);

        if (_balance.value < amount) revert InsufficientBalance();

        unchecked {
            _balance.value -= amount;
            _totalSupply().value -= amount;
        }

        emit Transfer(from, address(0), amount);
        
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowance(msg.sender, spender).value = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        _allowance(owner, spender).value = amount;

        emit Approval(owner, spender, amount);
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowance(owner, spender).value;
    }

    function nonces(address owner) external view returns (uint256) {
        return _nonces(owner).value;
    }

    // idea taken from https://github.com/Philogy/meth-weth/blob/5219af2f4ab6c91f8fac37b2633da35e20345a9e/src/reference/ReferenceMETH.sol
    function _balanceOf(address acc) internal pure returns (Value storage value) {
        /// @solidity memory-safe-assembly
        assembly {
            value.slot := acc
        }
    }

    function _totalSupply() internal pure returns (Value storage value) {
        /// @solidity memory-safe-assembly
        assembly {
            value.slot := _TOTALSUPPLY_SLOT
        }
    }

    // idea taken from https://github.com/Philogy/meth-weth/blob/5219af2f4ab6c91f8fac37b2633da35e20345a9e/src/reference/ReferenceMETH.sol
    function _allowance(address owner, address spender) internal pure returns (Value storage value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, owner)
            mstore(0x20, spender)
            value.slot := keccak256(0x00, 0x40)
        }
    }

    function _nonces(address owner) internal pure returns (Value storage value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0xff) // just use a simple push1(0xff) to avoid collisions
            mstore(0x20, owner)
            value.slot := keccak256(0x00, 0x40)
        }
    }

    // idea taken from https://github.com/Philogy/meth-weth/blob/5219af2f4ab6c91f8fac37b2633da35e20345a9e/src/reference/ReferenceMETH.sol
    function _useAllowance(address owner, uint256 amount) internal {
        Value storage currentAllowance = _allowance(owner, msg.sender);
        if (currentAllowance.value < amount) revert InsufficientAllowance();
        unchecked {
            // if msg.sender try to spend more than allowed it will do an arythmetic underflow revert
            if (currentAllowance.value != type(uint256).max) currentAllowance.value -= amount;
        }
    }

    function _transfer(address from, address to, uint256 amount) internal {
        Value storage _balanceFrom = _balanceOf(from);

        if (_balanceFrom.value < amount) revert InsufficientBalance();

        unchecked {
            _balanceFrom.value -= amount;
            _balanceOf(to).value += amount;
        }

        emit Transfer(from, to, amount);
    }
}

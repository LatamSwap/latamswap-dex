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

    // Balances of users will be stored onfrom 0x000000000000
    // reserve slots for balance storage
    uint256[1 << 160] private __gapBalances;

    mapping(address user => mapping(address spender => uint256 amount)) public allowance;

    // @dev _TOTALSUPPLY_SLOT = uint256(keccak256("ERC20_TOTALSUPPLY")) - 1;
    uint256 internal constant _TOTALSUPPLY_SLOT = 0x80184635fb759c2e2becdf0161d7c8162d7f6308ac5335f500b64180ffc7e07a;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address user => uint256 nonce) public nonces;

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

    function totalSupply() public view returns (uint256 _totalSupply) {
        /// @solidity memory-safe-assembly
        assembly {
            _totalSupply := sload(_TOTALSUPPLY_SLOT)
        }
    }

    function balanceOf(address account) public view returns (uint256 _balance) {
        /// @solidity memory-safe-assembly
        assembly {
            _balance := sload(account)
        }
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
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
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        _transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

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
                                nonces[owner]++,
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

            allowance[recoveredAddress][spender] = value;
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
        /// @solidity memory-safe-assembly
        assembly {
            // totalSupply += amount
            sstore(_TOTALSUPPLY_SLOT, add(sload(_TOTALSUPPLY_SLOT), amount))

            // Cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value.
            // unchecked {
            //    balanceOf[to] += amount;
            // }
            sstore(to, add(sload(to), amount))
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // check underflow
            let _balance := sload(from)
            if lt(_balance, amount) {
                mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                revert(0x1c, 0x04)
            }

            // totalSupply -= amount
            sstore(_TOTALSUPPLY_SLOT, sub(sload(_TOTALSUPPLY_SLOT), amount))

            // balanceOf[from] -= amount;
            sstore(from, sub(_balance, amount))
        }

        emit Transfer(from, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS LOGIC
    //////////////////////////////////////////////////////////////*/

    function _approve(address owner, address spender, uint256 amount) internal {
        allowance[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 allowed = allowance[owner][spender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[owner][spender] = allowed - amount;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // balanceOf[from] -= amount;
            let _balance := sload(from)
            if lt(_balance, amount) {
                mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                revert(0x1c, 0x04)
            }
            sstore(from, sub(_balance, amount))

            // Cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value.
            // unchecked {
            //     balanceOf[to] += amount;
            // }
            sstore(to, add(sload(to), amount))
        }
        emit Transfer(from, to, amount);
    }
}

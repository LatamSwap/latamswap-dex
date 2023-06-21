// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    // @dev _REENTRANCYGUARD_SLOT = uint256(keccak256("REENTRANCYGUARD")) - 1;
    uint256 internal constant _REENTRANCYGUARD_SLOT = 0xafea3f692ebda86be3dc0084fb2839a8dadb72083b86f4dba20216cbea31ca12;

    error cantReenter();

    modifier nonReentrant() {
        assembly {
            let locked := sload(_REENTRANCYGUARD_SLOT)
            if eq(locked, 2) {
                mstore(0x00, 0x26d9c842) // error cantReenter();
                revert(0x1c, 0x04)
            }

            sstore(_REENTRANCYGUARD_SLOT, 2)
        }

        _;

        assembly {
            sstore(_REENTRANCYGUARD_SLOT, 1)
        }
    }
}

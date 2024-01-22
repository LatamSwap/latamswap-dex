// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC1363Spender} from "openzeppelin/interfaces/IERC1363Spender.sol";
import {IERC1363Receiver} from "openzeppelin/interfaces/IERC1363Receiver.sol";

import {ERC20} from "solady/tokens/ERC20.sol";

/// @dev implementation of https://eips.ethereum.org/EIPS/eip-1363

abstract contract ERC1363 is ERC20 {
    /*//////////////////////////////////////////////////////////////
                        PRIVATE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // bytes4(keccak256("onApprovalReceived(address,uint256,bytes)"))
    bytes4 private constant _INTERFACE_ID_ERC1363_ON_APPROVAL_RECEIVED =
        bytes4(keccak256("onApprovalReceived(address,uint256,bytes)"));

    // bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))
    bytes4 private constant _INTERFACE_ID_ERC1363_ON_TRANSFER_RECEIVED =
        bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"));

    /*//////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/

    error Spender_onApprovalReceived_rejected();
    error Receiver_transferReceived_rejected();

    /*//////////////////////////////////////////////////////////////
                     ERC1363 METHODS AND LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Approves and then calls the receiving contract with empty data
    /// @dev The receiving contract must implement `onApprovalReceived(address,uint256,bytes)`
    /// @param spender The contract permitted to spend the tokens
    /// @param amount The amount of tokens to spend
    /// @return true unless the `spender` contract throws error or does not implement `onApprovalReceived(address,uint256,bytes)`
    function approveAndCall(address spender, uint256 amount) external returns (bool) {
        return approveAndCall(spender, amount, "");
    }

    /// @notice Approves and then calls the receiving contract
    /// @dev The receiving contract must implement `onApprovalReceived(address,uint256,bytes)`
    /// @param spender The contract permitted to spend the tokens
    /// @param amount The amount of tokens to spend
    /// @param data Additional data with no specified format to send to the `spender` contract
    /// @return true unless the `spender` contract throws error or does not implement `onApprovalReceived(address,uint256,bytes)`
    function approveAndCall(address spender, uint256 amount, bytes memory data) public returns (bool) {
        _approve(msg.sender, spender, amount);
        bytes4 response = IERC1363Spender(spender).onApprovalReceived(msg.sender, amount, data);

        // the response must equal to _INTERFACE_ID_ERC1363_ON_APPROVAL_RECEIVED
        // that is `bytes4(keccak256("onApprovalReceived(address,uint256,bytes)"))`
        if (response != _INTERFACE_ID_ERC1363_ON_APPROVAL_RECEIVED) {
            revert Spender_onApprovalReceived_rejected();
        }
        return true;
    }

    function transferAndCall(address to, uint256 amount) public returns (bool) {
        return transferAndCall(to, amount, "");
    }

    /// @notice Transfer tokens to a specified address and then execute a callback on recipient
    /// @param to The address to transfer `to`
    /// @param amount The amount to be transferred
    /// @param data Additional data with no specified format to send to the recipient
    /// @return true unless the recipient contract throws error , in that case it reverts.
    function transferAndCall(address to, uint256 amount, bytes memory data) public returns (bool) {
        _transfer(msg.sender, to, amount);
        bytes4 response = IERC1363Receiver(to).onTransferReceived(msg.sender, msg.sender, amount, data);
        // the response must equal to _INTERFACE_ID_ERC1363_ON_TRANSFER_RECEIVED
        // that is `bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))`
        if (response != _INTERFACE_ID_ERC1363_ON_TRANSFER_RECEIVED) {
            revert Receiver_transferReceived_rejected();
        }
        return true;
    }

    function transferFromAndCall(address from, address to, uint256 amount) external returns (bool) {
        return transferFromAndCall(from, to, amount, "");
    }

    function transferFromAndCall(address from, address to, uint256 amount, bytes memory data) public returns (bool) {
        // @dev _useAllowance will revert if not has enough allowance
        _spendAllowance(from, msg.sender, amount);
        // now lets transfer nativo tokens to the `to` address
        _transfer(from, to, amount);

        // now lets call the `onTransferReceived` function of the `to` address
        bytes4 response = IERC1363Receiver(to).onTransferReceived(msg.sender, from, amount, data);
        // the response must equal to _INTERFACE_ID_ERC1363_ON_TRANSFER_RECEIVED
        // that is `bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))`
        if (response != _INTERFACE_ID_ERC1363_ON_TRANSFER_RECEIVED) {
            revert Receiver_transferReceived_rejected();
        }
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                     ERC165 INTERFACE SUPPORT
    //////////////////////////////////////////////////////////////*/
    function supportsInterface(bytes4 interfaceId) external view returns (bool result) {
        /*
         * Note: the ERC-165 identifier for this interface is 0xb0202a11.
         * 0xb0202a11 ===
         *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
         *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
         *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
         *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
         *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
         *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
         */

        /// @solidity memory-safe-assembly
        assembly {
            let s := shr(224, interfaceId)
            // ERC1363: 0xb0202a11
            //result := or(eq(s, 0x.....), eq(s, 0x......))
            result := eq(s, 0xb0202a11)
        }
    }
}

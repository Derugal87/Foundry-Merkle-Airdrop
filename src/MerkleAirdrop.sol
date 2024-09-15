// SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MerkleAirdrop is EIP712 {
    // some list of addresses
    // allow smn in the list to claim ERC20 tokens
    ////////////////////
    //// ERRORS   //////
    ////////////////////
    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    ////////////////////
    //// EVENTS   //////
    ////////////////////
    event Claimed(address account, uint256 amount);

    ////////////////////
    //// TYPES   //////
    ////////////////////
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /////////////////////////
    //// VARIABLES   //////
    /////////////////////////

    IERC20 private immutable i_airdropToken;
    bytes32 private immutable i_merkleRoot;
    mapping(address => bool) private s_hasClaimed;

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account,uint256 amount)");

    // define the message hash struct
    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    // This function needs a lot of gas to execute, if you have millions of addresses in the list
    // function claim(address account) external {
    //     for (uint256 i = 0; i < claimers.length; i++) {}
    // }

    // merkle prooof is a way to prove that an address is in the list for each claimer

    ///////////////////////
    //// CONSTRUCTOR   //////
    /////////////////////////
    /**
     *
     * @param merkleRoot bytes32 merkle root
     * @param airdropToken IERC20 token to be airdropped
     */
    constructor(bytes32 merkleRoot, IERC20 airdropToken) EIP712("MerkleAirdrop", "1.0.0") {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    //////////////////////////////
    /////// INTERNAL    //////////
    //////////////////////////////
    /**
     *
     * @param account  address to be claimed
     * @param digest  bytes32 message to be signed
     * @param v  uint8 v
     * @param r  bytes32 r
     * @param s  bytes32 s
     */
    function _isValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
        return actualSigner == account;
    }

    //////////////////////////////
    /////// EXTERNAL    //////////
    //////////////////////////////
    /**
     *
     * @param account  address to be claimed
     * @param amount  amount to be claimed
     * @param merkleProof  bytes32[] proof of the merkle tree
     */
    // claim the airdrop using a signature from the account owner
    function claim(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (s_hasClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }

        // Verify the signature
        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }

        // Verify the merkle proof
        // calculate the leaf node hash
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        // verify the merkle proof (TODO: understand verify)
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }

        s_hasClaimed[account] = true; // prevent users claiming more than once and draining the contract
        emit Claimed(account, amount);
        // transfer the tokens
        i_airdropToken.safeTransfer(account, amount);
    }

    //////////////////////////////
    /// EXTERNAL VIEW   //////////
    //////////////////////////////

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }

    //////////////////////////////
    /////// PUBLIC    //////////
    //////////////////////////////
    /**
     *
     * @param account  address to be claimed
     * @param amount  amount to be claimed
     */
    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount}))));
    }
}

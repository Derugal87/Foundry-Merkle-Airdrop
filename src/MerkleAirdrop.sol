// SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleAirdrop {
    // some list of addresses
    // allow smn in the list to claim ERC20 tokens
    ////////////////////
    //// ERRORS   //////
    ////////////////////
    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();

    ////////////////////
    //// EVENTS   //////
    ////////////////////
    event Claimed(address account, uint256 amount);

    ////////////////////
    //// TYPES   //////
    ////////////////////
    using SafeERC20 for IERC20;

    /////////////////////////
    //// VARIABLES   //////
    /////////////////////////

    address[] public claimers;
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;
    mapping(address claimer => bool claimed) private s_hasClaimed;

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
    constructor(bytes32 merkleRoot, IERC20 airdropToken) {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
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
    function claim(address account, uint256 amount, bytes32[] calldata merkleProof) external {
        if (s_hasClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }
        // calculate using account and amount, the hash => leaf node
        // using 2 keccak is more secure, using 1 keccak there is a low chance of collision
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }
        s_hasClaimed[account] = true;
        emit Claimed(account, amount);
        i_airdropToken.safeTransfer(account, amount);
    }

    //////////////////////////////
    /// EXTERNAL VIEW   //////////
    //////////////////////////////

    function getMerkeRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }
}

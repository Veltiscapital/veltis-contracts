// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract VeltisRuleEngine is Ownable, Pausable {
    // Mapping of blacklisted addresses
    mapping(address => bool) public blacklistedAddresses;
    
    // Mapping of token transfer restrictions
    mapping(uint256 => bool) public tokenTransferRestrictions;
    
    constructor() Ownable(msg.sender) {}
    
    // Can transfer check
    function canTransfer(address from, address to, uint256 tokenId) external view returns (bool) {
        return !blacklistedAddresses[from] && 
               !blacklistedAddresses[to] && 
               !tokenTransferRestrictions[tokenId] &&
               !paused();
    }
    
    // Validate transfer with reason
    function validateTransferReason(address from, address to, uint256 tokenId) external view returns (string memory) {
        if (paused()) {
            return "Contract is paused";
        }
        
        if (blacklistedAddresses[from]) {
            return "Sender is blacklisted";
        }
        
        if (blacklistedAddresses[to]) {
            return "Recipient is blacklisted";
        }
        
        if (tokenTransferRestrictions[tokenId]) {
            return "Token transfers are restricted";
        }
        
        return "";
    }
} 
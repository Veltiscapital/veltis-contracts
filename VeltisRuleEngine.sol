// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract VeltisRuleEngine is Ownable, Pausable {
    // Mapping of blacklisted addresses
    mapping(address => bool) public blacklistedAddresses;
    
    // Mapping of transfer restrictions between addresses
    mapping(address => mapping(address => bool)) public transferRestrictions;
    
    // Mapping of token transfer restrictions
    mapping(uint256 => bool) public tokenTransferRestrictions;
    
    // Events
    event AddressBlacklisted(address indexed user, bool status);
    event TransferRestrictionSet(address indexed from, address indexed to, bool status);
    event TokenTransferRestrictionSet(uint256 indexed tokenId, bool status);
    
    constructor() Ownable() {}
    
    // Pause contract
    function pause() external onlyOwner {
        _pause();
    }
    
    // Unpause contract
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Blacklist an address
    function blacklistAddress(address _address, bool status) external onlyOwner {
        blacklistedAddresses[_address] = status;
        emit AddressBlacklisted(_address, status);
    }
    
    // Set transfer restrictions between addresses
    function setTransferRestriction(address from, address to, bool status) external onlyOwner {
        transferRestrictions[from][to] = status;
        emit TransferRestrictionSet(from, to, status);
    }
    
    // Set token transfer restrictions
    function setTokenTransferRestriction(uint256 tokenId, bool status) external onlyOwner {
        tokenTransferRestrictions[tokenId] = status;
        emit TokenTransferRestrictionSet(tokenId, status);
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
        
        if (transferRestrictions[from][to]) {
            return "Transfer between these addresses is restricted";
        }
        
        if (tokenTransferRestrictions[tokenId]) {
            return "Token transfers are restricted";
        }
        
        return "";
    }
    
    // Can transfer check
    function canTransfer(address from, address to, uint256 tokenId) external view returns (bool) {
        bytes memory reason = bytes(this.validateTransferReason(from, to, tokenId));
        return reason.length == 0;
    }
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./VeltisRuleEngine.sol";

contract VeltisIPNFTRegistry is ERC721, Ownable {
    // Rule Engine
    VeltisRuleEngine public ruleEngine;
    
    // Token counter
    uint256 private _tokenIdCounter;
    
    // IP Metadata structure
    struct IPMetadata {
        string title;
        string description;
        uint256 category;
        uint256 valuation;
    }
    
    // Token metadata storage
    mapping(uint256 => IPMetadata) private _ipMetadata;
    mapping(uint256 => string) private _tokenURIs;
    
    // Token locked status
    mapping(uint256 => bool) public tokenLocked;
    
    constructor(address _ruleEngine) ERC721("Veltis IP NFT", "VIPNFT") Ownable(msg.sender) {
        ruleEngine = VeltisRuleEngine(_ruleEngine);
    }
    
    function mintIPNFT(
        string memory title,
        string memory description,
        uint256 category,
        uint256 valuation,
        string memory uri
    ) external returns (uint256) {
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        _mint(msg.sender, tokenId);
        _tokenURIs[tokenId] = uri;
        
        _ipMetadata[tokenId] = IPMetadata({
            title: title,
            description: description,
            category: category,
            valuation: valuation
        });
        
        return tokenId;
    }
    
    function getIPMetadata(uint256 tokenId) external view returns (IPMetadata memory) {
        require(_exists(tokenId), "Token does not exist");
        return _ipMetadata[tokenId];
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }
    
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
    
    function updateValuation(uint256 tokenId, uint256 newValuation) external {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Not authorized");
        
        _ipMetadata[tokenId].valuation = newValuation;
    }
    
    function lockToken(uint256 tokenId) external {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Not authorized");
        require(!tokenLocked[tokenId], "Token already locked");
        
        tokenLocked[tokenId] = true;
    }
    
    function unlockToken(uint256 tokenId) external {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Not authorized");
        require(tokenLocked[tokenId], "Token not locked");
        
        tokenLocked[tokenId] = false;
    }
    
    function canTransfer(address from, address to, uint256 tokenId) external view returns (bool) {
        if (tokenLocked[tokenId]) {
            return false;
        }
        
        return ruleEngine.canTransfer(from, to, tokenId);
    }
} 
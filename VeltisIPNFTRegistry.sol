// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./VeltisRuleEngine.sol";

contract VeltisIPNFTRegistry is ERC721URIStorage, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    
    // Counters
    Counters.Counter private _tokenIds;
    
    // Rule Engine for transfer restrictions
    VeltisRuleEngine public ruleEngine;
    
    // IP Metadata structure
    struct IPMetadata {
        string title;
        string description;
        uint256 category;
        uint256 valuation;
        address owner;
        bool isVerified;
        uint8 verificationLevel;
        uint256 createdAt;
        uint256 updatedAt;
    }
    
    // Token metadata storage
    mapping(uint256 => IPMetadata) private _ipMetadata;
    
    // Token locked status
    mapping(uint256 => bool) public tokenLocked;
    
    // Events
    event TokenMinted(uint256 indexed tokenId, address indexed owner, string title, uint256 category, uint256 valuation);
    event TokenVerified(uint256 indexed tokenId, uint8 verificationLevel);
    event ValuationUpdated(uint256 indexed tokenId, uint256 newValuation);
    event TokenLockToggled(uint256 indexed tokenId, bool locked);
    
    constructor(address _ruleEngine) ERC721("Veltis IP NFT", "VIPNFT") Ownable() {
        ruleEngine = VeltisRuleEngine(_ruleEngine);
    }
    
    function mintIPNFT(
        string memory title,
        string memory description,
        uint256 category,
        uint256 valuation,
        string memory tokenURI
    ) external returns (uint256) {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);
        
        _ipMetadata[tokenId] = IPMetadata({
            title: title,
            description: description,
            category: category,
            valuation: valuation,
            owner: msg.sender,
            isVerified: false,
            verificationLevel: 0,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });
        
        emit TokenMinted(tokenId, msg.sender, title, category, valuation);
        
        return tokenId;
    }
    
    function verifyToken(uint256 tokenId, uint8 verificationLevel) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        
        IPMetadata storage metadata = _ipMetadata[tokenId];
        metadata.isVerified = true;
        metadata.verificationLevel = verificationLevel;
        metadata.updatedAt = block.timestamp;
        
        emit TokenVerified(tokenId, verificationLevel);
    }
    
    function updateValuation(uint256 tokenId, uint256 newValuation) external {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Not authorized");
        
        IPMetadata storage metadata = _ipMetadata[tokenId];
        metadata.valuation = newValuation;
        metadata.updatedAt = block.timestamp;
        
        emit ValuationUpdated(tokenId, newValuation);
    }
    
    function lockToken(uint256 tokenId) external {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Not authorized");
        require(!tokenLocked[tokenId], "Token already locked");
        
        tokenLocked[tokenId] = true;
        
        emit TokenLockToggled(tokenId, true);
    }
    
    function unlockToken(uint256 tokenId) external {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Not authorized");
        require(tokenLocked[tokenId], "Token not locked");
        
        tokenLocked[tokenId] = false;
        
        emit TokenLockToggled(tokenId, false);
    }
    
    function getIPMetadata(uint256 tokenId) external view returns (IPMetadata memory) {
        require(_exists(tokenId), "Token does not exist");
        return _ipMetadata[tokenId];
    }
    
    function canTransfer(address from, address to, uint256 tokenId) external view returns (bool) {
        if (tokenLocked[tokenId]) {
            return false;
        }
        
        return ruleEngine.canTransfer(from, to, tokenId);
    }
    
    // Override functions to satisfy both inherited contracts
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }
    
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimpleIPNFTRegistry
 * @dev A simplified contract for registering and managing IP-NFTs with fee collection
 */
contract SimpleIPNFTRegistry is ERC721URIStorage, AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    struct IPMetadata {
        string title;
        string authors;
        string institution;
        uint256 filingDate;
        string ipfsDocumentCID;
        string ipType; // Patent, Copyright, etc.
        uint256 valuation;
    }
    
    // Token storage
    mapping(uint256 => IPMetadata) public ipMetadata;
    
    // Fee configuration
    uint256 public mintFeePercentage = 300; // 3% in basis points
    address public feeCollector;
    
    // Events
    event IPNFTMinted(uint256 tokenId, address owner, string title, uint256 valuation, uint256 fee);
    
    /**
     * @dev Constructor
     */
    constructor() ERC721("BiotechIPNFT", "BIPNFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        
        feeCollector = msg.sender;
    }
    
    /**
     * @dev Mint a new IP-NFT with fee collection
     * @param recipient The recipient of the IP-NFT
     * @param tokenURI The URI of the token metadata
     * @param title The title of the IP
     * @param authors The authors of the IP
     * @param institution The institution of the IP
     * @param filingDate The filing date of the IP
     * @param ipfsDocumentCID The IPFS CID of the IP document
     * @param ipType The type of the IP (Patent, Copyright, etc.)
     * @param valuation The valuation of the IP in wei
     * @return The ID of the minted token
     */
    function mintIP(
        address recipient,
        string memory tokenURI,
        string memory title,
        string memory authors,
        string memory institution,
        uint256 filingDate,
        string memory ipfsDocumentCID,
        string memory ipType,
        uint256 valuation
    ) public payable nonReentrant returns (uint256) {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have minter role");
        
        // Calculate fee based on valuation (3%)
        uint256 requiredFee = (valuation * mintFeePercentage) / 10000;
        require(msg.value >= requiredFee, "Insufficient fee");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        _mint(recipient, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        
        ipMetadata[newTokenId] = IPMetadata({
            title: title,
            authors: authors,
            institution: institution,
            filingDate: filingDate,
            ipfsDocumentCID: ipfsDocumentCID,
            ipType: ipType,
            valuation: valuation
        });
        
        // Transfer fee to fee collector
        payable(feeCollector).transfer(requiredFee);
        
        // Refund excess payment if any
        if (msg.value > requiredFee) {
            payable(msg.sender).transfer(msg.value - requiredFee);
        }
        
        emit IPNFTMinted(newTokenId, recipient, title, valuation, requiredFee);
        
        return newTokenId;
    }
    
    /**
     * @dev Set the mint fee percentage
     * @param percentage The new percentage (in basis points)
     */
    function setMintFeePercentage(uint256 percentage) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        require(percentage <= 1000, "Fee too high"); // Max 10%
        
        mintFeePercentage = percentage;
    }
    
    /**
     * @dev Set the fee collector address
     * @param collector The new fee collector address
     */
    function setFeeCollector(address collector) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        require(collector != address(0), "Invalid address");
        
        feeCollector = collector;
    }
    
    /**
     * @dev Get the valuation of an IP-NFT
     * @param tokenId The ID of the token
     * @return The valuation
     */
    function getValuation(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return ipMetadata[tokenId].valuation;
    }
    
    /**
     * @dev Calculate the mint fee for a given valuation
     * @param valuation The valuation amount
     * @return The mint fee
     */
    function calculateMintFee(uint256 valuation) external view returns (uint256) {
        return (valuation * mintFeePercentage) / 10000;
    }
    
    /**
     * @dev Grant the minter role to an address
     * @param minter The address to grant the minter role to
     */
    function grantMinterRole(address minter) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        grantRole(MINTER_ROLE, minter);
    }
    
    /**
     * @dev Check if an interface is supported
     * @param interfaceId The interface ID to check
     * @return Whether the interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev Receive function to accept ETH payments
     */
    receive() external payable {
        // Only accept payments from the contract owner or fee collector
        require(
            msg.sender == feeCollector || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Unauthorized payment"
        );
    }
}

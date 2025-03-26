// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title IPNFTRegistryWithFees
 * @dev A contract for registering and managing IP-NFTs (Intellectual Property NFTs)
 * with enhanced security, recovery mechanisms, MEV protection, and fee collection
 */
contract IPNFTRegistryWithFees is ERC721URIStorage, ERC721Enumerable, AccessControl, IERC2981, ReentrancyGuard, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant RECOVERY_ROLE = keccak256("RECOVERY_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    struct IPMetadata {
        string title;
        string authors;
        string institution;
        uint256 filingDate;
        uint256 expirationDate;
        string ipfsDocumentCID;
        string ipType; // Patent, Copyright, etc.
        string developmentStage;
        bool isVerified;
        bool isFrozen;
        string digitalFingerprint; // Hash for verification
        uint256 lastValuationAmount;
        uint256 lastValuationDate;
    }
    
    // Token storage
    mapping(uint256 => IPMetadata) public ipMetadata;
    
    // Royalty configuration
    mapping(uint256 => address) public royaltyRecipients;
    mapping(uint256 => uint256) public royaltyPercentages;
    mapping(uint256 => mapping(address => uint256)) public royaltyShares; // For multiple recipients
    mapping(uint256 => address[]) public royaltyRecipientsList; // List of recipients for a token
    
    // Recovery mechanism
    mapping(uint256 => address) public originalOwners; // Track original owners for recovery
    mapping(address => bool) public blockedAddresses; // OFAC compliance
    
    // MEV protection
    uint256 public mintCooldown = 1 minutes; // Cooldown between mints to prevent front-running
    mapping(address => uint256) public lastMintTime;
    
    // Transaction fees
    uint256 public mintFeePercentage = 300; // 3% in basis points
    uint256 public transferFeePercentage = 300; // 3% in basis points
    address public feeCollector;
    
    // Valuation tracking
    uint256 public minValuationUpdateInterval = 1 days; // Minimum time between valuations
    mapping(uint256 => uint256) public ipValuations; // Track IP valuations for fee calculation
    
    // Transfer approval tracking
    mapping(uint256 => bool) public transferFeePaid; // Track if transfer fee has been paid
    
    // Events
    event IPNFTMinted(uint256 tokenId, address owner, string title, uint256 valuation, uint256 fee);
    event IPNFTVerified(uint256 tokenId, address verifier);
    event IPNFTFrozen(uint256 tokenId, address operator);
    event IPNFTUnfrozen(uint256 tokenId, address operator);
    event IPNFTRecovered(uint256 tokenId, address from, address to);
    event IPNFTValuationUpdated(uint256 tokenId, uint256 newValuation);
    event RoyaltyRecipientAdded(uint256 tokenId, address recipient, uint256 share);
    event AddressBlocked(address blockedAddress);
    event AddressUnblocked(address unblockedAddress);
    event TransferFeePaid(uint256 tokenId, address from, address to, uint256 platformFee, uint256 royaltyAmount);
    
    /**
     * @dev Constructor
     */
    constructor() ERC721("BiotechIPNFT", "BIPNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(VERIFIER_ROLE, msg.sender);
        _setupRole(RECOVERY_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        
        feeCollector = msg.sender;
    }
    
    /**
     * @dev Get the royalty information for a token
     * @param tokenId The ID of the token
     * @param salePrice The sale price of the token
     * @return receiver The receiver of the royalties
     * @return royaltyAmount The amount of royalties to pay
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) public view override returns (address receiver, uint256 royaltyAmount) {
        receiver = royaltyRecipients[tokenId];
        royaltyAmount = (salePrice * royaltyPercentages[tokenId]) / 10000; // basis points
    }
    
    /**
     * @dev Modifier to check if an address is not blocked (OFAC compliance)
     */
    modifier notBlocked(address _address) {
        require(!blockedAddresses[_address], "Address is blocked");
        _;
    }
    
    /**
     * @dev Modifier to check if a token is not frozen
     */
    modifier notFrozen(uint256 tokenId) {
        require(!ipMetadata[tokenId].isFrozen, "Token is frozen");
        _;
    }
    
    /**
     * @dev Modifier to prevent MEV attacks by enforcing cooldown periods
     */
    modifier preventMEV() {
        require(
            lastMintTime[msg.sender] + mintCooldown < block.timestamp,
            "Cooldown period not elapsed"
        );
        _;
        lastMintTime[msg.sender] = block.timestamp;
    }
    
    /**
     * @dev Mint a new IP-NFT with enhanced security, MEV protection, and fee collection
     * @param recipient The recipient of the IP-NFT
     * @param tokenURI The URI of the token metadata
     * @param title The title of the IP
     * @param authors The authors of the IP
     * @param institution The institution of the IP
     * @param filingDate The filing date of the IP
     * @param expirationDate The expiration date of the IP
     * @param ipfsDocumentCID The IPFS CID of the IP document
     * @param ipType The type of the IP (Patent, Copyright, etc.)
     * @param developmentStage The development stage of the IP
     * @param digitalFingerprint Hash of the document for verification
     * @param royaltyRecipient The recipient of royalties
     * @param royaltyPercentage The percentage of royalties (in basis points, e.g. 250 = 2.5%)
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
        uint256 expirationDate,
        string memory ipfsDocumentCID,
        string memory ipType,
        string memory developmentStage,
        string memory digitalFingerprint,
        address royaltyRecipient,
        uint256 royaltyPercentage,
        uint256 valuation
    ) public payable nonReentrant whenNotPaused notBlocked(recipient) preventMEV returns (uint256) {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have minter role");
        require(royaltyPercentage <= 5000, "Royalty percentage too high"); // Max 50%
        
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
            expirationDate: expirationDate,
            ipfsDocumentCID: ipfsDocumentCID,
            ipType: ipType,
            developmentStage: developmentStage,
            isVerified: false,
            isFrozen: false,
            digitalFingerprint: digitalFingerprint,
            lastValuationAmount: valuation,
            lastValuationDate: block.timestamp
        });
        
        // Store valuation for future fee calculations
        ipValuations[newTokenId] = valuation;
        
        // Set up royalties
        royaltyRecipients[newTokenId] = royaltyRecipient;
        royaltyPercentages[newTokenId] = royaltyPercentage;
        
        // Add to royalty recipients list
        royaltyRecipientsList[newTokenId].push(royaltyRecipient);
        royaltyShares[newTokenId][royaltyRecipient] = 10000; // 100% to single recipient initially
        
        // Track original owner for recovery
        originalOwners[newTokenId] = recipient;
        
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
     * @dev Pay transfer fee for a token
     * @param tokenId The ID of the token to transfer
     * @param to The recipient address
     */
    function transferWithFee(uint256 tokenId, address to) public payable nonReentrant whenNotPaused notBlocked(to) notFrozen(tokenId) {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not the token owner");
        
        // Calculate platform fee (3% of valuation)
        uint256 valuation = ipValuations[tokenId];
        uint256 platformFee = (valuation * transferFeePercentage) / 10000;
        
        // Calculate creator royalty
        (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(tokenId, valuation);
        
        // Ensure sufficient payment
        require(msg.value >= platformFee + royaltyAmount, "Insufficient fee");
        
        // Transfer platform fee to fee collector
        payable(feeCollector).transfer(platformFee);
        
        // Transfer royalty to creator
        payable(royaltyReceiver).transfer(royaltyAmount);
        
        // Refund excess payment if any
        if (msg.value > platformFee + royaltyAmount) {
            payable(msg.sender).transfer(msg.value - platformFee - royaltyAmount);
        }
        
        // Transfer the token
        _transfer(msg.sender, to, tokenId);
        
        emit TransferFeePaid(tokenId, msg.sender, to, platformFee, royaltyAmount);
    }
    
    /**
     * @dev Verify an IP-NFT
     * @param tokenId The ID of the token to verify
     */
    function verifyIP(uint256 tokenId) public whenNotPaused nonReentrant {
        require(hasRole(VERIFIER_ROLE, msg.sender), "Must have verifier role");
        require(_exists(tokenId), "Token does not exist");
        
        ipMetadata[tokenId].isVerified = true;
        
        emit IPNFTVerified(tokenId, msg.sender);
    }
    
    /**
     * @dev Update the valuation of an IP-NFT
     * @param tokenId The ID of the token to update
     * @param newValuation The new valuation amount
     */
    function updateValuation(uint256 tokenId, uint256 newValuation) public whenNotPaused nonReentrant {
        require(hasRole(VERIFIER_ROLE, msg.sender), "Must have verifier role");
        require(_exists(tokenId), "Token does not exist");
        require(
            block.timestamp >= ipMetadata[tokenId].lastValuationDate + minValuationUpdateInterval,
            "Valuation updated too recently"
        );
        
        ipMetadata[tokenId].lastValuationAmount = newValuation;
        ipMetadata[tokenId].lastValuationDate = block.timestamp;
        
        // Update stored valuation for fee calculations
        ipValuations[tokenId] = newValuation;
        
        emit IPNFTValuationUpdated(tokenId, newValuation);
    }
    
    /**
     * @dev Freeze an IP-NFT to prevent transfers (recovery mechanism)
     * @param tokenId The ID of the token to freeze
     */
    function freezeToken(uint256 tokenId) public whenNotPaused nonReentrant {
        require(hasRole(RECOVERY_ROLE, msg.sender), "Must have recovery role");
        require(_exists(tokenId), "Token does not exist");
        require(!ipMetadata[tokenId].isFrozen, "Token already frozen");
        
        ipMetadata[tokenId].isFrozen = true;
        
        emit IPNFTFrozen(tokenId, msg.sender);
    }
    
    /**
     * @dev Unfreeze an IP-NFT to allow transfers
     * @param tokenId The ID of the token to unfreeze
     */
    function unfreezeToken(uint256 tokenId) public whenNotPaused nonReentrant {
        require(hasRole(RECOVERY_ROLE, msg.sender), "Must have recovery role");
        require(_exists(tokenId), "Token does not exist");
        require(ipMetadata[tokenId].isFrozen, "Token not frozen");
        
        ipMetadata[tokenId].isFrozen = false;
        
        emit IPNFTUnfrozen(tokenId, msg.sender);
    }
    
    /**
     * @dev Recover an IP-NFT to its original owner (in case of theft or loss)
     * @param tokenId The ID of the token to recover
     */
    function recoverToken(uint256 tokenId) public whenNotPaused nonReentrant {
        require(hasRole(RECOVERY_ROLE, msg.sender), "Must have recovery role");
        require(_exists(tokenId), "Token does not exist");
        
        address currentOwner = ownerOf(tokenId);
        address originalOwner = originalOwners[tokenId];
        
        require(currentOwner != originalOwner, "Token already owned by original owner");
        
        // Force transfer back to original owner
        _transfer(currentOwner, originalOwner, tokenId);
        
        emit IPNFTRecovered(tokenId, currentOwner, originalOwner);
    }
    
    /**
     * @dev Add a royalty recipient for a token (for multiple recipients)
     * @param tokenId The ID of the token
     * @param recipient The recipient address
     * @param share The share of royalties (in basis points)
     */
    function addRoyaltyRecipient(uint256 tokenId, address recipient, uint256 share) public whenNotPaused nonReentrant {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || msg.sender == royaltyRecipients[tokenId], "Not authorized");
        require(_exists(tokenId), "Token does not exist");
        require(share > 0, "Share must be greater than 0");
        require(recipient != address(0), "Invalid recipient");
        
        // Calculate total shares after adding this recipient
        uint256 totalShares = share;
        for (uint256 i = 0; i < royaltyRecipientsList[tokenId].length; i++) {
            address existingRecipient = royaltyRecipientsList[tokenId][i];
            if (existingRecipient != recipient) {
                totalShares += royaltyShares[tokenId][existingRecipient];
            }
        }
        
        require(totalShares <= 10000, "Total shares exceed 100%");
        
        // Add recipient if not already in the list
        bool found = false;
        for (uint256 i = 0; i < royaltyRecipientsList[tokenId].length; i++) {
            if (royaltyRecipientsList[tokenId][i] == recipient) {
                found = true;
                break;
            }
        }
        
        if (!found) {
            royaltyRecipientsList[tokenId].push(recipient);
        }
        
        royaltyShares[tokenId][recipient] = share;
        
        emit RoyaltyRecipientAdded(tokenId, recipient, share);
    }
    
    /**
     * @dev Block an address (OFAC compliance)
     * @param _address The address to block
     */
    function blockAddress(address _address) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        require(!blockedAddresses[_address], "Address already blocked");
        
        blockedAddresses[_address] = true;
        
        emit AddressBlocked(_address);
    }
    
    /**
     * @dev Unblock an address
     * @param _address The address to unblock
     */
    function unblockAddress(address _address) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        require(blockedAddresses[_address], "Address not blocked");
        
        blockedAddresses[_address] = false;
        
        emit AddressUnblocked(_address);
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
     * @dev Set the transfer fee percentage
     * @param percentage The new percentage (in basis points)
     */
    function setTransferFeePercentage(uint256 percentage) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        require(percentage <= 1000, "Fee too high"); // Max 10%
        
        transferFeePercentage = percentage;
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
     * @dev Set the mint cooldown period (MEV protection)
     * @param cooldown The new cooldown period in seconds
     */
    function setMintCooldown(uint256 cooldown) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        
        mintCooldown = cooldown;
    }
    
    /**
     * @dev Set the minimum valuation update interval
     * @param interval The new interval in seconds
     */
    function setMinValuationUpdateInterval(uint256 interval) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        
        minValuationUpdateInterval = interval;
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() public {
        require(hasRole(PAUSER_ROLE, msg.sender), "Must have pauser role");
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() public {
        require(hasRole(PAUSER_ROLE, msg.sender), "Must have pauser role");
        _unpause();
    }
    
    
    /**
     * @dev Get detailed royalty information for a token with multiple recipients
     * @param tokenId The ID of the token
     * @param salePrice The sale price of the token
     * @return recipients The list of royalty recipients
     * @return amounts The corresponding amounts for each recipient
     */
    function detailedRoyaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address[] memory recipients, uint256[] memory amounts) {
        recipients = royaltyRecipientsList[tokenId];
        amounts = new uint256[](recipients.length);
        
        uint256 totalRoyalty = (salePrice * royaltyPercentages[tokenId]) / 10000;
        
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            amounts[i] = (totalRoyalty * royaltyShares[tokenId][recipient]) / 10000;
        }
        
        return (recipients, amounts);
    }
    
    /**
     * @dev Get the current valuation of an IP-NFT
     * @param tokenId The ID of the token
     * @return The current valuation
     */
    function getValuation(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return ipValuations[tokenId];
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
     * @dev Calculate the transfer fee for a given token
     * @param tokenId The ID of the token
     * @return platformFee The platform fee
     * @return royaltyAmount The royalty amount
     */
    function calculateTransferFee(uint256 tokenId) external view returns (uint256 platformFee, uint256 royaltyAmount) {
        require(_exists(tokenId), "Token does not exist");
        
        uint256 valuation = ipValuations[tokenId];
        platformFee = (valuation * transferFeePercentage) / 10000;
        
        (address royaltyReceiver, uint256 royalty) = royaltyInfo(tokenId, valuation);
        royaltyAmount = royalty;
        
        return (platformFee, royaltyAmount);
    }
    
    /**
     * @dev Grant the minter role to an address
     * @param minter The address to grant the minter role to
     */
    function grantMinterRole(address minter) public whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        grantRole(MINTER_ROLE, minter);
    }
    
    /**
     * @dev Grant the verifier role to an address
     * @param verifier The address to grant the verifier role to
     */
    function grantVerifierRole(address verifier) public whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        grantRole(VERIFIER_ROLE, verifier);
    }
    
    /**
     * @dev Grant the recovery role to an address
     * @param recovery The address to grant the recovery role to
     */
    function grantRecoveryRole(address recovery) public whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        grantRole(RECOVERY_ROLE, recovery);
    }
    
    /**
     * @dev Grant the pauser role to an address
     * @param pauser The address to grant the pauser role to
     */
    function grantPauserRole(address pauser) public whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        grantRole(PAUSER_ROLE, pauser);
    }
    
    /**
     * @dev Check if an interface is supported
     * @param interfaceId The interface ID to check
     * @return Whether the interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev Hook that is called before any token transfer
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable) 
        whenNotPaused
    {
        // Skip checks for minting (from == address(0)) and burning (to == address(0))
        if (from != address(0) && to != address(0)) {
            // Check if token is frozen
            require(!ipMetadata[tokenId].isFrozen, "Token is frozen");
            
            // Check if recipient is blocked (OFAC compliance)
            require(!blockedAddresses[to], "Recipient address is blocked");
            
            // For regular transfers, we need to use the transferWithFee function
            // This check is skipped for recovery operations and admin functions
            if (!hasRole(RECOVERY_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
                revert("Use transferWithFee function");
            }
        }
        
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    /**
     * @dev Hook that is called when a token is burned
     */
    function _burn(uint256 tokenId)
        internal
        override(ERC721URIStorage)
    {
        super._burn(tokenId);
    }
    
    /**
     * @dev Get the URI of a token
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
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

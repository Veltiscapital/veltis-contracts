// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "../interfaces/IRuleEngine.sol";

contract VeltisIPNFTRegistry is 
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IERC2981Upgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant RECOVERY_ROLE = keccak256("RECOVERY_ROLE");
    
    // Counters
    CountersUpgradeable.Counter private _tokenIds;
    
    // Rule Engine for transfer restrictions
    IRuleEngine public ruleEngine;
    
    // IP Metadata structure
    struct IPMetadata {
        string title;
        string description;
        string category;
        uint256 valuation;
        address owner;
        bool isVerified;
        bool isFrozen;
        uint256 createdAt;
        uint256 updatedAt;
    }
    
    // Token storage
    mapping(uint256 => IPMetadata) public ipMetadata;
    mapping(uint256 => string) public ipSymbol;
    
    // Royalty configuration
    uint256 public defaultRoyaltyPercentage;
    address public defaultRoyaltyRecipient;
    mapping(uint256 => address) public royaltyRecipients;
    mapping(uint256 => uint256) public royaltyPercentages;
    
    // Transfer restrictions
    mapping(uint256 => bool) public transferLocked;
    
    // Recovery mechanism
    mapping(uint256 => address) public originalOwners;
    
    // Platform fees
    uint256 public mintFeePercentage;
    uint256 public transferFeePercentage;
    address public feeCollector;
    
    // Events
    event IPTokenMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string title,
        uint256 valuation
    );
    event IPTokenVerified(uint256 indexed tokenId);
    event ValuationUpdated(uint256 indexed tokenId, uint256 newValuation);
    event IPNFTTransferRestricted(uint256 indexed tokenId, address indexed from, address indexed to, string reason);
    event RuleEngineSet(address indexed ruleEngine);
    event RoyaltyUpdated(uint256 indexed tokenId, address recipient, uint256 percentage);
    event DefaultRoyaltyUpdated(address recipient, uint256 percentage);
    event TransferLockToggled(uint256 indexed tokenId, bool locked);
    event TokenFrozen(uint256 indexed tokenId);
    event TokenUnfrozen(uint256 indexed tokenId);
    
    // Custom errors
    error TokenAlreadyFrozen(uint256 tokenId);
    error TokenNotFrozen(uint256 tokenId);
    error TokenIsCurrentlyFrozen(uint256 tokenId);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        string memory name,
        string memory symbol,
        address admin
    ) public initializer {
        __ERC721_init(name, symbol);
        __ERC721URIStorage_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ERC721Enumerable_init();
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(VERIFIER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(RECOVERY_ROLE, admin);
        
        // Set default parameters
        defaultRoyaltyPercentage = 250; // 2.5% in basis points
        defaultRoyaltyRecipient = admin;
        
        // Set platform fees
        mintFeePercentage = 300; // 3% in basis points
        transferFeePercentage = 250; // 2.5% in basis points
        feeCollector = admin;
        
        // Start token IDs at 1
        _tokenIds.increment();
        
        emit DefaultRoyaltyUpdated(admin, 250);
    }
    
    function setRuleEngine(address _ruleEngine) external onlyRole(ADMIN_ROLE) {
        require(_ruleEngine != address(0), "Invalid rule engine");
        ruleEngine = IRuleEngine(_ruleEngine);
        emit RuleEngineSet(_ruleEngine);
    }
    
    function calculateMintFee(uint256 valuation) public view returns (uint256) {
        return (valuation * mintFeePercentage) / 10000;
    }
    
    function calculateTransferFee(uint256 tokenId) public view returns (uint256 platformFee, uint256 royaltyAmount) {
        uint256 valuation = ipMetadata[tokenId].valuation;
        
        platformFee = (valuation * transferFeePercentage) / 10000;
        
        uint256 royaltyPercentage = royaltyPercentages[tokenId] > 0 ? 
            royaltyPercentages[tokenId] : defaultRoyaltyPercentage;
            
        royaltyAmount = (valuation * royaltyPercentage) / 10000;
        
        return (platformFee, royaltyAmount);
    }
    
    function mint(
        address recipient,
        string memory tokenURI,
        string memory title,
        string memory description,
        string memory category,
        uint256 valuation
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI);

        ipMetadata[tokenId] = IPMetadata({
            title: title,
            description: description,
            category: category,
            valuation: valuation,
            owner: recipient,
            isVerified: false,
            isFrozen: false,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        emit IPTokenMinted(tokenId, recipient, title, valuation);
        return tokenId;
    }
    
    function verifyToken(uint256 tokenId) external onlyRole(VERIFIER_ROLE) {
        require(_exists(tokenId), "Token does not exist");
        require(!ipMetadata[tokenId].isVerified, "Token already verified");
        
        ipMetadata[tokenId].isVerified = true;
        ipMetadata[tokenId].updatedAt = block.timestamp;
        
        emit IPTokenVerified(tokenId);
    }
    
    function updateValuation(uint256 tokenId, uint256 newValuation) external {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || hasRole(ADMIN_ROLE, msg.sender), "Not authorized");
        
        ipMetadata[tokenId].valuation = newValuation;
        ipMetadata[tokenId].updatedAt = block.timestamp;
        
        emit ValuationUpdated(tokenId, newValuation);
    }
    
    function setDefaultRoyalty(address recipient, uint256 percentage) external onlyRole(ADMIN_ROLE) {
        require(percentage <= 1000, "Percentage too high"); // Max 10%
        
        defaultRoyaltyRecipient = recipient;
        defaultRoyaltyPercentage = percentage;
        
        emit DefaultRoyaltyUpdated(recipient, percentage);
    }
    
    function setTokenRoyalty(uint256 tokenId, address recipient, uint256 percentage) external onlyRole(ADMIN_ROLE) {
        require(_exists(tokenId), "Token does not exist");
        require(percentage <= 1000, "Percentage too high"); // Max 10%
        
        royaltyRecipients[tokenId] = recipient;
        royaltyPercentages[tokenId] = percentage;
        
        emit RoyaltyUpdated(tokenId, recipient, percentage);
    }
    
    function setPlatformFees(
        uint256 _mintFeePercentage,
        uint256 _transferFeePercentage,
        address _feeCollector
    ) external onlyRole(ADMIN_ROLE) {
        require(_mintFeePercentage <= 1000, "Mint fee too high"); // Max 10%
        require(_transferFeePercentage <= 1000, "Transfer fee too high"); // Max 10%
        require(_feeCollector != address(0), "Invalid fee collector");
        
        mintFeePercentage = _mintFeePercentage;
        transferFeePercentage = _transferFeePercentage;
        feeCollector = _feeCollector;
    }
    
    function toggleTransferLock(uint256 tokenId, bool locked) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId) || hasRole(ADMIN_ROLE, _msgSender()), "Not authorized");
        require(_exists(tokenId), "Token does not exist");
        
        transferLocked[tokenId] = locked;
        
        emit TransferLockToggled(tokenId, locked);
    }
    
    function getIPMetadata(uint256 tokenId) external view returns (IPMetadata memory) {
        require(_exists(tokenId), "Token does not exist");
        return ipMetadata[tokenId];
    }
    
    function getIPNFTsByOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        
        return tokenIds;
    }
    
    function canTransfer(address from, address to, uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId) && tokenId != 0) {
            return false;
        }
        
        // Check if token is locked or frozen
        if (tokenId != 0 && (transferLocked[tokenId] || ipMetadata[tokenId].isFrozen)) {
            return false;
        }
        
        // Check rule engine if set
        if (address(ruleEngine) != address(0)) {
            return ruleEngine.canTransfer(from, to, tokenId);
        }
        
        return true;
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_exists(tokenId), "Token does not exist");
        
        address royaltyRecipient = royaltyRecipients[tokenId] != address(0) ? 
            royaltyRecipients[tokenId] : defaultRoyaltyRecipient;
            
        uint256 royaltyPercentage = royaltyPercentages[tokenId] > 0 ? 
            royaltyPercentages[tokenId] : defaultRoyaltyPercentage;
            
        royaltyAmount = (salePrice * royaltyPercentage) / 10000;
        
        return (royaltyRecipient, royaltyAmount);
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        if (ipMetadata[tokenId].isFrozen) {
            revert TokenIsCurrentlyFrozen(tokenId);
        }
    }
    
    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            ERC721Upgradeable,
            ERC721URIStorageUpgradeable,
            ERC721EnumerableUpgradeable,
            AccessControlUpgradeable,
            IERC165Upgradeable
        )
        returns (bool)
    {
        return interfaceId == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function freezeToken(uint256 tokenId) external onlyRole(ADMIN_ROLE) {
        if (ipMetadata[tokenId].isFrozen) {
            revert TokenAlreadyFrozen(tokenId);
        }
        ipMetadata[tokenId].isFrozen = true;
        ipMetadata[tokenId].updatedAt = block.timestamp;
        emit TokenFrozen(tokenId);
    }

    function unfreezeToken(uint256 tokenId) external onlyRole(ADMIN_ROLE) {
        if (!ipMetadata[tokenId].isFrozen) {
            revert TokenNotFrozen(tokenId);
        }
        ipMetadata[tokenId].isFrozen = false;
        ipMetadata[tokenId].updatedAt = block.timestamp;
        emit TokenUnfrozen(tokenId);
    }
} 
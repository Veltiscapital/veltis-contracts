// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title IPNFTFractionalization
 * @dev A contract for fractionalizing IP-NFTs into tradable ERC20 tokens
 */
contract IPNFTFractionalization is ERC20Capped, ERC721Holder, ReentrancyGuard, AccessControl, Pausable {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // IPNFT Information
    address public ipnftContract;
    uint256 public ipnftTokenId;
    address public originalOwner;
    uint256 public creationTimestamp;
    
    // Fractionalization Parameters
    uint256 public totalShares;
    uint256 public initialPrice;
    bool public redemptionEnabled = false;
    uint256 public redemptionPrice;
    
    // Platform Fees
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 300; // 3% in basis points
    address public feeCollector;
    
    // Events
    event IPNFTFractionalized(address indexed originalOwner, uint256 indexed tokenId, uint256 totalShares, uint256 initialPrice);
    event RedemptionEnabled(uint256 redemptionPrice);
    event IPNFTRedeemed(address indexed redeemer, uint256 indexed tokenId);
    event TokensBought(address indexed buyer, uint256 amount, uint256 price);
    event TokensSold(address indexed seller, uint256 amount, uint256 price);
    
    /**
     * @dev Constructor to create a fractionalized IPNFT
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _ipnftContract Address of the IPNFT contract
     * @param _ipnftTokenId TokenID of the IPNFT to fractionalize
     * @param _totalShares Total number of shares to create
     * @param _initialPrice Initial price per share
     * @param _feeCollector Address to collect platform fees
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _ipnftContract,
        uint256 _ipnftTokenId,
        uint256 _totalShares,
        uint256 _initialPrice,
        address _feeCollector
    ) ERC20(_name, _symbol) ERC20Capped(_totalShares) {
        require(_totalShares > 0, "Total shares must be positive");
        require(_initialPrice > 0, "Initial price must be positive");
        require(_feeCollector != address(0), "Fee collector cannot be zero address");
        
        ipnftContract = _ipnftContract;
        ipnftTokenId = _ipnftTokenId;
        originalOwner = msg.sender;
        totalShares = _totalShares;
        initialPrice = _initialPrice;
        feeCollector = _feeCollector;
        creationTimestamp = block.timestamp;
        
        // Set up roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        
        // Transfer the NFT to this contract
        IERC721(_ipnftContract).safeTransferFrom(msg.sender, address(this), _ipnftTokenId);
        
        // Mint initial shares to the original owner
        _mint(msg.sender, _totalShares);
        
        emit IPNFTFractionalized(msg.sender, _ipnftTokenId, _totalShares, _initialPrice);
    }
    
    /**
     * @dev Enable redemption of the IPNFT
     * @param _redemptionPrice Price at which the NFT can be redeemed
     */
    function enableRedemption(uint256 _redemptionPrice) external {
        require(hasRole(OPERATOR_ROLE, msg.sender) || msg.sender == originalOwner, "Not authorized");
        require(!redemptionEnabled, "Redemption already enabled");
        require(_redemptionPrice > 0, "Redemption price must be positive");
        
        redemptionEnabled = true;
        redemptionPrice = _redemptionPrice;
        
        emit RedemptionEnabled(_redemptionPrice);
    }
    
    /**
     * @dev Redeem the IPNFT by burning all tokens
     */
    function redeemIPNFT() external nonReentrant whenNotPaused {
        require(redemptionEnabled, "Redemption not enabled");
        require(balanceOf(msg.sender) == totalSupply(), "Must own all tokens to redeem");
        
        // Burn all tokens
        _burn(msg.sender, totalSupply());
        
        // Transfer the NFT back to the redeemer
        IERC721(ipnftContract).safeTransferFrom(address(this), msg.sender, ipnftTokenId);
        
        emit IPNFTRedeemed(msg.sender, ipnftTokenId);
    }
    
    /**
     * @dev Buy tokens at the current price
     * @param _tokenAmount Amount of tokens to buy
     */
    function buyTokens(uint256 _tokenAmount) external payable nonReentrant whenNotPaused {
        require(_tokenAmount > 0, "Amount must be positive");
        require(msg.sender != originalOwner, "Original owner cannot buy tokens");
        
        // Check if seller has enough tokens
        require(balanceOf(originalOwner) >= _tokenAmount, "Not enough tokens available");
        
        // Calculate price including platform fee
        uint256 basePrice = _tokenAmount * initialPrice;
        uint256 platformFee = (basePrice * PLATFORM_FEE_PERCENTAGE) / 10000;
        uint256 totalPrice = basePrice + platformFee;
        
        require(msg.value >= totalPrice, "Insufficient payment");
        
        // Transfer tokens from original owner to buyer
        _transfer(originalOwner, msg.sender, _tokenAmount);
        
        // Transfer payment to original owner
        payable(originalOwner).transfer(basePrice);
        
        // Transfer platform fee
        payable(feeCollector).transfer(platformFee);
        
        // Refund excess payment
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
        
        emit TokensBought(msg.sender, _tokenAmount, totalPrice);
    }
    
    /**
     * @dev Sell tokens back to the contract
     * @param _tokenAmount Amount of tokens to sell
     */
    function sellTokens(uint256 _tokenAmount) external nonReentrant whenNotPaused {
        require(_tokenAmount > 0, "Amount must be positive");
        require(balanceOf(msg.sender) >= _tokenAmount, "Not enough tokens owned");
        require(address(this).balance >= _tokenAmount * initialPrice, "Insufficient contract balance");
        
        // Calculate price and platform fee
        uint256 basePrice = _tokenAmount * initialPrice;
        uint256 platformFee = (basePrice * PLATFORM_FEE_PERCENTAGE) / 10000;
        uint256 sellerAmount = basePrice - platformFee;
        
        // Transfer tokens to the contract (effectively burning them)
        _burn(msg.sender, _tokenAmount);
        
        // Transfer payment to seller
        payable(msg.sender).transfer(sellerAmount);
        
        // Transfer platform fee
        payable(feeCollector).transfer(platformFee);
        
        emit TokensSold(msg.sender, _tokenAmount, sellerAmount);
    }
    
    /**
     * @dev Deposit funds to the contract liquidity pool
     */
    function depositLiquidity() external payable {
        require(msg.value > 0, "Must send positive amount");
    }
    
    /**
     * @dev Withdraw contract liquidity (only original owner or admin)
     * @param _amount Amount to withdraw
     */
    function withdrawLiquidity(uint256 _amount) external nonReentrant {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || msg.sender == originalOwner, "Not authorized");
        require(_amount > 0 && _amount <= address(this).balance, "Invalid amount");
        
        payable(msg.sender).transfer(_amount);
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external {
        require(hasRole(PAUSER_ROLE, msg.sender), "Must have pauser role");
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external {
        require(hasRole(PAUSER_ROLE, msg.sender), "Must have pauser role");
        _unpause();
    }
    
    /**
     * @dev Emergency recovery of any ERC20 tokens sent to the contract
     */
    function recoverERC20(address _tokenAddress, uint256 _amount) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        require(_tokenAddress != address(this), "Cannot recover fractional tokens");
        
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
    }
    
    /**
     * @dev Set a new fee collector address
     */
    function setFeeCollector(address _newFeeCollector) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        require(_newFeeCollector != address(0), "Cannot set zero address");
        
        feeCollector = _newFeeCollector;
    }
    
    /**
     * @dev Get information about the fractionalized IPNFT
     */
    function getFractionalizationInfo() external view returns (
        address nftContract,
        uint256 tokenId,
        address owner,
        uint256 created,
        uint256 shares,
        uint256 price,
        bool canRedeem,
        uint256 redeemPrice
    ) {
        return (
            ipnftContract,
            ipnftTokenId,
            originalOwner,
            creationTimestamp,
            totalShares,
            initialPrice,
            redemptionEnabled,
            redemptionPrice
        );
    }
    
    /**
     * @dev Override _update to add the whenNotPaused modifier
     */
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }
} 
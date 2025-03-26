// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IPNFTFractionalization.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title IPNFTFractionalizationFactory
 * @dev Factory contract to create new fractionalization contracts for IP-NFTs
 */
contract IPNFTFractionalizationFactory is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Platform fee settings
    address public feeCollector;
    uint256 public creationFeePercentage = 300; // 3% in basis points
    
    // Tracking fractionalization contracts
    struct FractionalizationInfo {
        address tokenContract;
        address ipnftContract;
        uint256 ipnftTokenId;
        address owner;
        string name;
        string symbol;
        uint256 createdAt;
    }
    
    mapping(address => FractionalizationInfo[]) public userFractionalizations;
    mapping(address => mapping(uint256 => address)) public ipnftToFractionalization;
    address[] public allFractionalizations;
    
    // Events
    event FractionalizationCreated(
        address indexed fractionalizationContract,
        address indexed ipnftContract,
        uint256 indexed ipnftTokenId,
        address owner,
        string name,
        string symbol
    );
    event CreationFeeUpdated(uint256 newFeePercentage);
    event FeeCollectorUpdated(address newFeeCollector);
    
    /**
     * @dev Constructor
     * @param _feeCollector Address to collect platform fees
     */
    constructor(address _feeCollector) {
        require(_feeCollector != address(0), "Fee collector cannot be zero address");
        
        feeCollector = _feeCollector;
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }
    
    /**
     * @dev Create a new fractionalization contract
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _ipnftContract Address of the IPNFT contract
     * @param _ipnftTokenId TokenID of the IPNFT to fractionalize
     * @param _totalShares Total number of shares to create
     * @param _initialPrice Initial price per share in wei
     * @return The address of the new fractionalization contract
     */
    function createFractionalization(
        string memory _name,
        string memory _symbol,
        address _ipnftContract,
        uint256 _ipnftTokenId,
        uint256 _totalShares,
        uint256 _initialPrice
    ) external payable nonReentrant whenNotPaused returns (address) {
        require(_totalShares > 0, "Total shares must be positive");
        require(_initialPrice > 0, "Initial price must be positive");
        require(ipnftToFractionalization[_ipnftContract][_ipnftTokenId] == address(0), "IPNFT already fractionalized");
        
        // Calculate creation fee (3% of total valuation)
        uint256 totalValuation = _totalShares * _initialPrice;
        uint256 creationFee = (totalValuation * creationFeePercentage) / 10000;
        
        require(msg.value >= creationFee, "Insufficient fee");
        
        // Deploy new fractionalization contract
        IPNFTFractionalization fractionalization = new IPNFTFractionalization(
            _name,
            _symbol,
            _ipnftContract,
            _ipnftTokenId,
            _totalShares,
            _initialPrice,
            feeCollector
        );
        
        // Store fractionalization info
        FractionalizationInfo memory info = FractionalizationInfo({
            tokenContract: address(fractionalization),
            ipnftContract: _ipnftContract,
            ipnftTokenId: _ipnftTokenId,
            owner: msg.sender,
            name: _name,
            symbol: _symbol,
            createdAt: block.timestamp
        });
        
        userFractionalizations[msg.sender].push(info);
        ipnftToFractionalization[_ipnftContract][_ipnftTokenId] = address(fractionalization);
        allFractionalizations.push(address(fractionalization));
        
        // Transfer fee
        payable(feeCollector).transfer(creationFee);
        
        // Refund excess fee
        if (msg.value > creationFee) {
            payable(msg.sender).transfer(msg.value - creationFee);
        }
        
        emit FractionalizationCreated(
            address(fractionalization),
            _ipnftContract,
            _ipnftTokenId,
            msg.sender,
            _name,
            _symbol
        );
        
        return address(fractionalization);
    }
    
    /**
     * @dev Set the creation fee percentage
     * @param _newFeePercentage New fee percentage in basis points
     */
    function setCreationFeePercentage(uint256 _newFeePercentage) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        require(_newFeePercentage <= 1000, "Fee too high"); // Max 10%
        
        creationFeePercentage = _newFeePercentage;
        
        emit CreationFeeUpdated(_newFeePercentage);
    }
    
    /**
     * @dev Set a new fee collector address
     * @param _newFeeCollector New fee collector address
     */
    function setFeeCollector(address _newFeeCollector) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have admin role");
        require(_newFeeCollector != address(0), "Cannot set zero address");
        
        feeCollector = _newFeeCollector;
        
        emit FeeCollectorUpdated(_newFeeCollector);
    }
    
    /**
     * @dev Pause the factory
     */
    function pause() external {
        require(hasRole(PAUSER_ROLE, msg.sender), "Must have pauser role");
        _pause();
    }
    
    /**
     * @dev Unpause the factory
     */
    function unpause() external {
        require(hasRole(PAUSER_ROLE, msg.sender), "Must have pauser role");
        _unpause();
    }
    
    /**
     * @dev Get all fractionalizations for a user
     * @param _user User address
     * @return Array of fractionalization info structures
     */
    function getUserFractionalizations(address _user) external view returns (FractionalizationInfo[] memory) {
        return userFractionalizations[_user];
    }
    
    /**
     * @dev Get the fractionalization contract for an IPNFT
     * @param _ipnftContract IPNFT contract address
     * @param _ipnftTokenId IPNFT token ID
     * @return The fractionalization contract address
     */
    function getFractionalizationContract(address _ipnftContract, uint256 _ipnftTokenId) external view returns (address) {
        return ipnftToFractionalization[_ipnftContract][_ipnftTokenId];
    }
    
    /**
     * @dev Get the total number of fractionalization contracts created
     * @return The count of all fractionalization contracts
     */
    function getTotalFractionalizations() external view returns (uint256) {
        return allFractionalizations.length;
    }
} 
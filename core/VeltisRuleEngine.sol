// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IRuleEngine.sol";

contract VeltisRuleEngine is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IRuleEngine 
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Mapping to store blacklisted addresses
    mapping(address => bool) public blacklistedAddresses;
    
    // Mapping to store transfer restrictions between addresses
    mapping(address => mapping(address => bool)) public transferRestrictions;
    
    // Mapping to store token-specific transfer restrictions
    mapping(uint256 => bool) public tokenTransferRestrictions;

    // Events
    event AddressBlacklisted(address indexed account);
    event AddressUnblacklisted(address indexed account);
    event TransferRestrictionSet(address indexed from, address indexed to, bool restricted);
    event TokenTransferRestrictionSet(uint256 indexed tokenId, bool restricted);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    // IRuleEngine implementation
    function canTransfer(
        address from, 
        address to, 
        uint256 tokenId
    ) external view override returns (bool) {
        // Check if either address is blacklisted
        if (blacklistedAddresses[from] || blacklistedAddresses[to]) {
            return false;
        }

        // Check if there's a specific restriction between these addresses
        if (transferRestrictions[from][to]) {
            return false;
        }

        // Check if the token has specific transfer restrictions
        if (tokenTransferRestrictions[tokenId]) {
            return false;
        }

        // Check if the contract is paused
        if (paused()) {
            return false;
        }

        return true;
    }

    function validateTransferReason(
        address from, 
        address to, 
        uint256 tokenId
    ) external view override returns (string memory) {
        if (blacklistedAddresses[from]) {
            return "Sender is blacklisted";
        }
        if (blacklistedAddresses[to]) {
            return "Recipient is blacklisted";
        }
        if (transferRestrictions[from][to]) {
            return "Transfer restricted between these addresses";
        }
        if (tokenTransferRestrictions[tokenId]) {
            return "Token is restricted from transfer";
        }
        if (paused()) {
            return "Transfers are paused";
        }
        return "Transfer allowed";
    }

    function operateOnTransfer(
        address from, 
        address to, 
        uint256 tokenId
    ) external override returns (bool) {
        // This function can be used to perform any necessary operations
        // when a transfer occurs, such as logging or updating state
        // Currently, it just validates the transfer
        require(canTransfer(from, to, tokenId), validateTransferReason(from, to, tokenId));
        return true;
    }

    // Admin functions
    function blacklistAddress(address account) external onlyRole(ADMIN_ROLE) {
        require(account != address(0), "Invalid address");
        blacklistedAddresses[account] = true;
        emit AddressBlacklisted(account);
    }

    function unblacklistAddress(address account) external onlyRole(ADMIN_ROLE) {
        require(account != address(0), "Invalid address");
        blacklistedAddresses[account] = false;
        emit AddressUnblacklisted(account);
    }

    function setTransferRestriction(
        address from,
        address to,
        bool restricted
    ) external onlyRole(OPERATOR_ROLE) {
        require(from != address(0) && to != address(0), "Invalid address");
        transferRestrictions[from][to] = restricted;
        emit TransferRestrictionSet(from, to, restricted);
    }

    function setTokenTransferRestriction(
        uint256 tokenId,
        bool restricted
    ) external onlyRole(OPERATOR_ROLE) {
        tokenTransferRestrictions[tokenId] = restricted;
        emit TokenTransferRestrictionSet(tokenId, restricted);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRuleEngine {
    function blacklistedAddresses(address user) external view returns (bool);
    function transferRestrictions(address from, address to) external view returns (bool);
    function tokenTransferRestrictions(uint256 tokenId) external view returns (bool);
    function blacklistAddress(address _address, bool status) external;
    function setTransferRestriction(address from, address to, bool status) external;
    function setTokenTransferRestriction(uint256 tokenId, bool status) external;
    function validateTransferReason(address from, address to, uint256 tokenId) external view returns (string memory);
    function canTransfer(address from, address to, uint256 tokenId) external view returns (bool);
} 
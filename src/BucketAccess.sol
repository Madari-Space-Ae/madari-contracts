// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BucketRegistry.sol";

/**
 * @title BucketAccess
 * @author Deca4 Advisory for Madari Space
 * @notice Manages access control and encrypted keys for buckets
 * @dev Each user's encrypted bucket key is stored on-chain (encrypted with their public key)
 */
contract BucketAccess {
    enum Permission {
        NONE,
        READ,
        WRITE,
        ADMIN
    }

    struct Grant {
        bytes encryptedBucketKey; // Bucket master key encrypted for this user (ECIES)
        Permission permission;
        uint256 grantedAt;
        address grantedBy;
    }

    BucketRegistry public immutable bucketRegistry;

    // bucketId => user => Grant
    mapping(bytes32 => mapping(address => Grant)) public grants;

    // bucketId => list of users with grants
    mapping(bytes32 => address[]) public grantedUsers;

    event AccessGranted(
        bytes32 indexed bucketId,
        address indexed user,
        Permission permission,
        address indexed grantedBy
    );

    event AccessRevoked(
        bytes32 indexed bucketId,
        address indexed user,
        address indexed revokedBy
    );

    event BucketKeyUpdated(bytes32 indexed bucketId, address indexed user);

    constructor(address _bucketRegistry) {
        bucketRegistry = BucketRegistry(_bucketRegistry);
    }

    modifier onlyBucketAdmin(bytes32 bucketId) {
        require(
            bucketRegistry.getOwner(bucketId) == msg.sender ||
                grants[bucketId][msg.sender].permission == Permission.ADMIN,
            "Not admin"
        );
        _;
    }

    modifier bucketMustExist(bytes32 bucketId) {
        require(bucketRegistry.bucketExists(bucketId), "Bucket not found");
        _;
    }

    /**
     * @notice Initialize owner access when bucket is created
     * @dev Called by bucket owner after createBucket to store their encrypted key
     * @param bucketId The bucket to initialize
     * @param encryptedBucketKey The bucket master key encrypted with owner's public key
     */
    function initializeOwnerAccess(
        bytes32 bucketId,
        bytes calldata encryptedBucketKey
    ) external bucketMustExist(bucketId) {
        require(
            bucketRegistry.getOwner(bucketId) == msg.sender,
            "Not owner"
        );
        require(
            grants[bucketId][msg.sender].permission == Permission.NONE,
            "Already initialized"
        );

        grants[bucketId][msg.sender] = Grant({
            encryptedBucketKey: encryptedBucketKey,
            permission: Permission.ADMIN,
            grantedAt: block.timestamp,
            grantedBy: msg.sender
        });
        grantedUsers[bucketId].push(msg.sender);

        emit AccessGranted(bucketId, msg.sender, Permission.ADMIN, msg.sender);
    }

    /**
     * @notice Grant access to a user
     * @param bucketId The bucket to grant access to
     * @param user The user to grant access to
     * @param encryptedBucketKey The bucket master key encrypted with user's public key
     * @param permission The permission level (READ, WRITE, or ADMIN)
     */
    function grantAccess(
        bytes32 bucketId,
        address user,
        bytes calldata encryptedBucketKey,
        Permission permission
    ) external bucketMustExist(bucketId) onlyBucketAdmin(bucketId) {
        require(permission != Permission.NONE, "Use revokeAccess");
        require(user != address(0), "Invalid user");
        require(
            grants[bucketId][user].permission == Permission.NONE,
            "Already has access"
        );

        grants[bucketId][user] = Grant({
            encryptedBucketKey: encryptedBucketKey,
            permission: permission,
            grantedAt: block.timestamp,
            grantedBy: msg.sender
        });
        grantedUsers[bucketId].push(user);

        emit AccessGranted(bucketId, user, permission, msg.sender);
    }

    /**
     * @notice Revoke access from a user
     * @param bucketId The bucket to revoke access from
     * @param user The user to revoke
     */
    function revokeAccess(
        bytes32 bucketId,
        address user
    ) external bucketMustExist(bucketId) onlyBucketAdmin(bucketId) {
        require(
            user != bucketRegistry.getOwner(bucketId),
            "Cannot revoke owner"
        );
        require(
            grants[bucketId][user].permission != Permission.NONE,
            "No access to revoke"
        );

        delete grants[bucketId][user];
        // Note: grantedUsers array not cleaned up (gas optimization)

        emit AccessRevoked(bucketId, user, msg.sender);
    }

    /**
     * @notice Update encrypted bucket key for a user (used during re-keying)
     * @param bucketId The bucket
     * @param user The user to update
     * @param newEncryptedBucketKey The new encrypted key
     */
    function updateEncryptedBucketKey(
        bytes32 bucketId,
        address user,
        bytes calldata newEncryptedBucketKey
    ) external bucketMustExist(bucketId) onlyBucketAdmin(bucketId) {
        require(
            grants[bucketId][user].permission != Permission.NONE,
            "No access"
        );

        grants[bucketId][user].encryptedBucketKey = newEncryptedBucketKey;

        emit BucketKeyUpdated(bucketId, user);
    }

    // ============ View Functions ============

    function canAccess(
        bytes32 bucketId,
        address user
    ) external view returns (bool) {
        return grants[bucketId][user].permission != Permission.NONE;
    }

    function canWrite(
        bytes32 bucketId,
        address user
    ) external view returns (bool) {
        Permission p = grants[bucketId][user].permission;
        return p == Permission.WRITE || p == Permission.ADMIN;
    }

    function canAdmin(
        bytes32 bucketId,
        address user
    ) external view returns (bool) {
        return grants[bucketId][user].permission == Permission.ADMIN;
    }

    function getGrant(
        bytes32 bucketId,
        address user
    ) external view returns (Grant memory) {
        return grants[bucketId][user];
    }

    function getEncryptedBucketKey(
        bytes32 bucketId,
        address user
    ) external view returns (bytes memory) {
        require(
            grants[bucketId][user].permission != Permission.NONE,
            "No access"
        );
        return grants[bucketId][user].encryptedBucketKey;
    }

    function getGrantedUsers(
        bytes32 bucketId
    ) external view returns (address[] memory) {
        return grantedUsers[bucketId];
    }

    function getPermission(
        bytes32 bucketId,
        address user
    ) external view returns (Permission) {
        return grants[bucketId][user].permission;
    }
}

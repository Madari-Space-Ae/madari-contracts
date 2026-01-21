// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BucketRegistry.sol";
import "./BucketAccess.sol";

/**
 * @title ObjectRegistry
 * @author Deca4 Advisory for Madari Space
 * @notice Tracks objects (files) within buckets
 * @dev Objects are registered on-chain with their content hash; actual content lives on satellite
 */
contract ObjectRegistry {
    struct Object {
        bytes32 objectId;
        bytes32 bucketId;
        string key; // e.g., "/contracts/v1.pdf"
        bytes32 contentHash; // SHA-256 of encrypted content
        uint256 size; // Size in bytes
        uint256 uploadedAt;
        address uploadedBy;
        bool exists;
    }

    BucketRegistry public immutable bucketRegistry;
    BucketAccess public immutable bucketAccess;

    // objectId => Object
    mapping(bytes32 => Object) public objects;

    // bucketId => list of objectIds
    mapping(bytes32 => bytes32[]) public bucketObjects;

    // bucketId => key => objectId (for key uniqueness within bucket)
    mapping(bytes32 => mapping(string => bytes32)) public objectByKey;

    // Track object count per bucket
    mapping(bytes32 => uint256) public objectCount;

    event ObjectCreated(
        bytes32 indexed objectId,
        bytes32 indexed bucketId,
        string key,
        bytes32 contentHash,
        uint256 size,
        address indexed uploadedBy
    );

    event ObjectDeleted(
        bytes32 indexed objectId,
        bytes32 indexed bucketId,
        string key,
        address indexed deletedBy
    );

    event ObjectUpdated(
        bytes32 indexed objectId,
        bytes32 indexed bucketId,
        bytes32 newContentHash,
        uint256 newSize,
        address indexed updatedBy
    );

    constructor(address _bucketRegistry, address _bucketAccess) {
        bucketRegistry = BucketRegistry(_bucketRegistry);
        bucketAccess = BucketAccess(_bucketAccess);
    }

    modifier canWriteToBucket(bytes32 bucketId) {
        require(bucketRegistry.bucketExists(bucketId), "Bucket not found");
        require(bucketAccess.canWrite(bucketId, msg.sender), "No write access");
        _;
    }

    /**
     * @notice Create or update an object in a bucket
     * @param bucketId The bucket to store the object in
     * @param key The path/key for the object (e.g., "/docs/file.pdf")
     * @param contentHash SHA-256 hash of the encrypted content
     * @param size Size in bytes of the encrypted content
     * @return objectId The unique identifier for the object
     */
    function putObject(
        bytes32 bucketId,
        string calldata key,
        bytes32 contentHash,
        uint256 size
    ) external canWriteToBucket(bucketId) returns (bytes32 objectId) {
        require(bytes(key).length > 0, "Key required");
        require(bytes(key).length <= 256, "Key too long");
        require(size > 0, "Size must be > 0");
        require(contentHash != bytes32(0), "Content hash required");

        // Check if object already exists
        bytes32 existingObjectId = objectByKey[bucketId][key];

        if (existingObjectId != bytes32(0)) {
            // Update existing object
            Object storage obj = objects[existingObjectId];
            obj.contentHash = contentHash;
            obj.size = size;
            obj.uploadedAt = block.timestamp;
            obj.uploadedBy = msg.sender;

            emit ObjectUpdated(
                existingObjectId,
                bucketId,
                contentHash,
                size,
                msg.sender
            );
            return existingObjectId;
        }

        // Create new object
        objectId = keccak256(
            abi.encodePacked(bucketId, key, block.timestamp, block.number)
        );

        objects[objectId] = Object({
            objectId: objectId,
            bucketId: bucketId,
            key: key,
            contentHash: contentHash,
            size: size,
            uploadedAt: block.timestamp,
            uploadedBy: msg.sender,
            exists: true
        });

        bucketObjects[bucketId].push(objectId);
        objectByKey[bucketId][key] = objectId;
        objectCount[bucketId]++;

        emit ObjectCreated(
            objectId,
            bucketId,
            key,
            contentHash,
            size,
            msg.sender
        );
        return objectId;
    }

    /**
     * @notice Delete an object from a bucket
     * @param bucketId The bucket containing the object
     * @param key The object key to delete
     */
    function deleteObject(
        bytes32 bucketId,
        string calldata key
    ) external canWriteToBucket(bucketId) {
        bytes32 objectId = objectByKey[bucketId][key];
        require(objectId != bytes32(0), "Object not found");

        delete objectByKey[bucketId][key];
        delete objects[objectId];
        objectCount[bucketId]--;
        // Note: bucketObjects array not cleaned up (gas optimization)

        emit ObjectDeleted(objectId, bucketId, key, msg.sender);
    }

    // ============ View Functions ============

    function getObject(bytes32 objectId) external view returns (Object memory) {
        require(objects[objectId].exists, "Object not found");
        return objects[objectId];
    }

    function getObjectByKey(
        bytes32 bucketId,
        string calldata key
    ) external view returns (Object memory) {
        bytes32 objectId = objectByKey[bucketId][key];
        require(objectId != bytes32(0), "Object not found");
        return objects[objectId];
    }

    function listObjects(
        bytes32 bucketId
    ) external view returns (bytes32[] memory) {
        return bucketObjects[bucketId];
    }

    function getObjectCount(bytes32 bucketId) external view returns (uint256) {
        return objectCount[bucketId];
    }

    function objectExists(
        bytes32 bucketId,
        string calldata key
    ) external view returns (bool) {
        return objectByKey[bucketId][key] != bytes32(0);
    }

    function getContentHash(bytes32 objectId) external view returns (bytes32) {
        require(objects[objectId].exists, "Object not found");
        return objects[objectId].contentHash;
    }
}

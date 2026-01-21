// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BucketRegistry
 * @author Deca4 Advisory for Madari Space
 * @notice Manages bucket creation and ownership for sovereign document storage
 * @dev Buckets are containers for objects, similar to S3 buckets
 */
contract BucketRegistry {
    struct Bucket {
        bytes32 bucketId;
        address owner;
        string name;
        uint256 createdAt;
        bytes32 encryptionKeyHash; // Hash of bucket's master key (for verification)
        bool exists;
    }

    // bucketId => Bucket
    mapping(bytes32 => Bucket) public buckets;

    // owner => list of bucketIds
    mapping(address => bytes32[]) public userBuckets;

    // owner => name => bucketId (for name uniqueness per owner)
    mapping(address => mapping(string => bytes32)) public bucketByName;

    event BucketCreated(
        bytes32 indexed bucketId,
        address indexed owner,
        string name,
        uint256 timestamp
    );

    event BucketDeleted(
        bytes32 indexed bucketId,
        address indexed owner,
        uint256 timestamp
    );

    /**
     * @notice Create a new bucket
     * @param name Human-readable bucket name (unique per owner)
     * @param encryptionKeyHash Hash of the bucket's master encryption key
     * @return bucketId The unique identifier for the created bucket
     */
    function createBucket(
        string calldata name,
        bytes32 encryptionKeyHash
    ) external returns (bytes32 bucketId) {
        require(bytes(name).length > 0, "Name required");
        require(bytes(name).length <= 63, "Name too long");
        require(
            bucketByName[msg.sender][name] == bytes32(0),
            "Name already exists"
        );

        // Generate unique bucket ID
        bucketId = keccak256(
            abi.encodePacked(msg.sender, name, block.timestamp, block.number)
        );

        buckets[bucketId] = Bucket({
            bucketId: bucketId,
            owner: msg.sender,
            name: name,
            createdAt: block.timestamp,
            encryptionKeyHash: encryptionKeyHash,
            exists: true
        });

        userBuckets[msg.sender].push(bucketId);
        bucketByName[msg.sender][name] = bucketId;

        emit BucketCreated(bucketId, msg.sender, name, block.timestamp);
        return bucketId;
    }

    /**
     * @notice Delete a bucket (must be empty - checked by ObjectRegistry)
     * @param bucketId The bucket to delete
     */
    function deleteBucket(bytes32 bucketId) external {
        Bucket storage bucket = buckets[bucketId];
        require(bucket.exists, "Bucket not found");
        require(bucket.owner == msg.sender, "Not owner");

        delete bucketByName[msg.sender][bucket.name];
        delete buckets[bucketId];
        // Note: userBuckets array not cleaned up (gas optimization)

        emit BucketDeleted(bucketId, msg.sender, block.timestamp);
    }

    // ============ View Functions ============

    function getBucket(bytes32 bucketId) external view returns (Bucket memory) {
        require(buckets[bucketId].exists, "Bucket not found");
        return buckets[bucketId];
    }

    function listBuckets(
        address owner
    ) external view returns (bytes32[] memory) {
        return userBuckets[owner];
    }

    function bucketExists(bytes32 bucketId) external view returns (bool) {
        return buckets[bucketId].exists;
    }

    function getOwner(bytes32 bucketId) external view returns (address) {
        return buckets[bucketId].owner;
    }

    function getBucketByName(
        address owner,
        string calldata name
    ) external view returns (bytes32) {
        return bucketByName[owner][name];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PublicKeyRegistry
 * @author Deca4 Advisory for Madari Space
 * @notice Stores user public keys for encryption key exchange
 * @dev Users register their public key once; others use it to encrypt shared keys via ECIES
 */
contract PublicKeyRegistry {
    // user => public key (uncompressed secp256k1, 65 bytes: 0x04 || x || y)
    mapping(address => bytes) public publicKeys;

    // Track registration timestamps
    mapping(address => uint256) public registeredAt;

    event PublicKeyRegistered(
        address indexed user,
        bytes publicKey,
        uint256 timestamp
    );

    event PublicKeyUpdated(
        address indexed user,
        bytes oldKey,
        bytes newKey,
        uint256 timestamp
    );

    /**
     * @notice Register your public key for receiving encrypted keys
     * @dev Public key must be uncompressed secp256k1 format (65 bytes starting with 0x04)
     * @param publicKey Uncompressed secp256k1 public key (65 bytes)
     */
    function registerPublicKey(bytes calldata publicKey) external {
        require(publicKey.length == 65, "Invalid public key length");
        require(publicKey[0] == 0x04, "Must be uncompressed format");

        bytes memory oldKey = publicKeys[msg.sender];

        if (oldKey.length > 0) {
            emit PublicKeyUpdated(
                msg.sender,
                oldKey,
                publicKey,
                block.timestamp
            );
        } else {
            emit PublicKeyRegistered(msg.sender, publicKey, block.timestamp);
        }

        publicKeys[msg.sender] = publicKey;
        registeredAt[msg.sender] = block.timestamp;
    }

    /**
     * @notice Get a user's public key
     * @param user The address to look up
     * @return The user's registered public key
     */
    function getPublicKey(address user) external view returns (bytes memory) {
        bytes memory pk = publicKeys[user];
        require(pk.length > 0, "Public key not registered");
        return pk;
    }

    /**
     * @notice Check if user has registered a public key
     * @param user The address to check
     * @return True if user has a registered public key
     */
    function hasPublicKey(address user) external view returns (bool) {
        return publicKeys[user].length > 0;
    }

    /**
     * @notice Get multiple public keys in one call (gas efficient for batch operations)
     * @param users Array of addresses to look up
     * @return Array of public keys (empty bytes for unregistered users)
     */
    function getPublicKeys(
        address[] calldata users
    ) external view returns (bytes[] memory) {
        bytes[] memory keys = new bytes[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            keys[i] = publicKeys[users[i]];
        }
        return keys;
    }

    /**
     * @notice Get registration timestamp for a user
     * @param user The address to check
     * @return Timestamp when the user registered (0 if not registered)
     */
    function getRegistrationTime(address user) external view returns (uint256) {
        return registeredAt[user];
    }
}

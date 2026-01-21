// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ObjectRegistry.sol";

/**
 * @title CustodyProofs
 * @author Deca4 Advisory for Madari Space
 * @notice Records attestations from satellite proving custody of objects in orbit
 * @dev Attestations include orbital position and are signed by the satellite's onboard key
 */
contract CustodyProofs {
    struct Attestation {
        bytes32 attestationId;
        bytes32 objectId;
        bytes32 bucketId;
        uint256 timestamp; // When the attestation was generated (satellite time)
        int256 latitude; // Satellite position (scaled by 1e6, e.g., 25276987 = 25.276987)
        int256 longitude; // Satellite position (scaled by 1e6)
        uint256 altitude; // In meters above sea level
        bytes32 contentHashAttest; // Hash of content at time of attestation
        bytes signature; // Satellite's ECDSA signature (65 bytes: r, s, v)
        uint256 submittedAt; // When recorded on-chain
    }

    ObjectRegistry public immutable objectRegistry;

    // Public address of the satellite (derived from onboard private key)
    address public satelliteAddress;

    // Contract owner for admin functions
    address public owner;

    // attestationId => Attestation
    mapping(bytes32 => Attestation) public attestations;

    // objectId => list of attestationIds
    mapping(bytes32 => bytes32[]) public objectAttestations;

    // Latest attestation per object
    mapping(bytes32 => bytes32) public latestAttestation;

    // Total attestation count
    uint256 public totalAttestations;

    event AttestationSubmitted(
        bytes32 indexed attestationId,
        bytes32 indexed objectId,
        bytes32 indexed bucketId,
        uint256 timestamp,
        int256 latitude,
        int256 longitude,
        uint256 altitude
    );

    event SatelliteAddressUpdated(
        address indexed oldAddress,
        address indexed newAddress
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor(address _objectRegistry, address _satelliteAddress) {
        objectRegistry = ObjectRegistry(_objectRegistry);
        satelliteAddress = _satelliteAddress;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /**
     * @notice Submit a custody attestation from the satellite
     * @dev Ground station relay calls this after receiving attestation from satellite
     * @param objectId The object being attested
     * @param timestamp When the attestation was generated (satellite time, UTC)
     * @param latitude Satellite latitude (scaled by 1e6)
     * @param longitude Satellite longitude (scaled by 1e6)
     * @param altitude Satellite altitude in meters
     * @param contentHashAttest SHA-256 of content at attestation time
     * @param signature ECDSA signature from satellite (65 bytes)
     * @return attestationId The unique identifier for this attestation
     */
    function submitAttestation(
        bytes32 objectId,
        uint256 timestamp,
        int256 latitude,
        int256 longitude,
        uint256 altitude,
        bytes32 contentHashAttest,
        bytes calldata signature
    ) external returns (bytes32 attestationId) {
        // Verify object exists
        ObjectRegistry.Object memory obj = objectRegistry.getObject(objectId);
        require(obj.exists, "Object not found");

        // Verify signature (commented out for PoC - enable in production)
        // bytes32 messageHash = keccak256(
        //     abi.encodePacked(
        //         objectId,
        //         timestamp,
        //         latitude,
        //         longitude,
        //         altitude,
        //         contentHashAttest
        //     )
        // );
        // require(
        //     recoverSigner(messageHash, signature) == satelliteAddress,
        //     "Invalid signature"
        // );

        // Require signature to be present (even if not verified in PoC)
        require(signature.length == 65, "Invalid signature length");

        attestationId = keccak256(
            abi.encodePacked(objectId, timestamp, block.number, totalAttestations)
        );

        attestations[attestationId] = Attestation({
            attestationId: attestationId,
            objectId: objectId,
            bucketId: obj.bucketId,
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            contentHashAttest: contentHashAttest,
            signature: signature,
            submittedAt: block.timestamp
        });

        objectAttestations[objectId].push(attestationId);
        latestAttestation[objectId] = attestationId;
        totalAttestations++;

        emit AttestationSubmitted(
            attestationId,
            objectId,
            obj.bucketId,
            timestamp,
            latitude,
            longitude,
            altitude
        );

        return attestationId;
    }

    /**
     * @notice Update satellite address (for key rotation)
     * @param newAddress The new satellite public address
     */
    function updateSatelliteAddress(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        emit SatelliteAddressUpdated(satelliteAddress, newAddress);
        satelliteAddress = newAddress;
    }

    /**
     * @notice Transfer ownership of the contract
     * @param newOwner The new owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ============ View Functions ============

    function getAttestation(
        bytes32 attestationId
    ) external view returns (Attestation memory) {
        require(
            attestations[attestationId].attestationId != bytes32(0),
            "Attestation not found"
        );
        return attestations[attestationId];
    }

    function getObjectAttestations(
        bytes32 objectId
    ) external view returns (bytes32[] memory) {
        return objectAttestations[objectId];
    }

    function getLatestAttestation(
        bytes32 objectId
    ) external view returns (Attestation memory) {
        bytes32 attestationId = latestAttestation[objectId];
        require(attestationId != bytes32(0), "No attestations");
        return attestations[attestationId];
    }

    function getAttestationCount(
        bytes32 objectId
    ) external view returns (uint256) {
        return objectAttestations[objectId].length;
    }

    /**
     * @notice Verify content hash matches latest attestation
     * @param objectId The object to verify
     * @param contentHash The content hash to compare
     * @return True if content hash matches the latest attestation
     */
    function verifyContentHash(
        bytes32 objectId,
        bytes32 contentHash
    ) external view returns (bool) {
        bytes32 attestationId = latestAttestation[objectId];
        if (attestationId == bytes32(0)) return false;
        return attestations[attestationId].contentHashAttest == contentHash;
    }

    /**
     * @notice Check if object has been attested
     * @param objectId The object to check
     * @return True if object has at least one attestation
     */
    function hasAttestation(bytes32 objectId) external view returns (bool) {
        return latestAttestation[objectId] != bytes32(0);
    }

    // ============ Signature Recovery (for production) ============

    /**
     * @notice Recover signer address from message hash and signature
     * @dev Used to verify satellite signature in production
     */
    function recoverSigner(
        bytes32 messageHash,
        bytes memory signature
    ) public pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Invalid signature v value");

        bytes32 prefixedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        return ecrecover(prefixedHash, v, r, s);
    }
}

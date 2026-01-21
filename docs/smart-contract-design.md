# Smart Contract Design

**Project:** Madari Space - Sovereign Document Custody in Orbit
**Version:** 1.0
**Date:** January 21, 2026
**Author:** Deca4 Advisory

---

## 1. Executive Summary

Madari provides **cryptographically-verified document custody in orbit**. These smart contracts run on a custom **Avalanche L1** and serve as the trust anchor for the entire system. They:

1. Track who owns what (buckets and objects)
2. Control who can access what (encrypted key distribution)
3. Record proof that data exists in space (satellite attestations)

The key differentiator from traditional cloud storage: **verifiable proof**. Anyone can independently verify that a specific document was stored on a specific satellite at a specific time—without trusting Madari.

---

## 2. System Architecture

### Where Smart Contracts Fit

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MADARI SYSTEM ARCHITECTURE                         │
│                                                                              │
│   ┌──────────┐      ┌─────────────┐      ┌─────────────┐      ┌──────────┐ │
│   │  Client  │ ───► │     API     │ ───► │  Avalanche  │      │Satellite │ │
│   │  (User)  │ ◄─── │   (GCP)     │ ◄─── │     L1      │      │ (Space)  │ │
│   └──────────┘      └─────────────┘      └─────────────┘      └──────────┘ │
│        │                  │                     │                    │      │
│        │                  │                     │                    │      │
│   Encrypts data      Routes requests      SMART CONTRACTS       Stores data │
│   Holds keys         Stores files         ═══════════════       Signs proofs│
│                      (off-chain)          │             │                   │
│                                           │ • BucketRegistry                │
│   ┌──────────────┐                        │ • BucketAccess                  │
│   │Ground Station│ ◄────────────────────► │ • ObjectRegistry                │
│   │   (Relay)    │    Relay attestations  │ • CustodyProofs                 │
│   └──────────────┘                        │ • PublicKeyRegistry             │
│                                           │             │                   │
│                                           ═══════════════                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Residency

| Data Type | Location | Why |
|-----------|----------|-----|
| Encrypted files | Satellite + GCS backup | Satellite is the "proof" location |
| Encryption keys (encrypted) | Blockchain | Enables trustless key sharing |
| Access permissions | Blockchain | Immutable, verifiable ACL |
| Content hashes | Blockchain | Tamper-proof integrity check |
| Custody attestations | Blockchain | The core "proof of space" |
| User public keys | Blockchain | Required for ECIES key exchange |

---

## 3. Contract Overview

### Contract Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONTRACT DEPENDENCIES                                │
│                                                                              │
│                     ┌──────────────────┐                                    │
│                     │  BucketRegistry  │                                    │
│                     │                  │                                    │
│                     │  Standalone      │                                    │
│                     │  (no deps)       │                                    │
│                     └────────┬─────────┘                                    │
│                              │                                              │
│              ┌───────────────┼───────────────┐                              │
│              │               │               │                              │
│              ▼               │               │                              │
│     ┌──────────────────┐     │               │                              │
│     │   BucketAccess   │     │               │                              │
│     │                  │     │               │                              │
│     │  Depends on:     │     │               │                              │
│     │  • BucketRegistry│     │               │                              │
│     └────────┬─────────┘     │               │                              │
│              │               │               │                              │
│              ▼               ▼               │                              │
│     ┌──────────────────────────┐             │                              │
│     │    ObjectRegistry        │             │                              │
│     │                          │             │                              │
│     │  Depends on:             │             │                              │
│     │  • BucketRegistry        │             │                              │
│     │  • BucketAccess          │             │                              │
│     └────────────┬─────────────┘             │                              │
│                  │                           │                              │
│                  ▼                           │                              │
│     ┌──────────────────┐      ┌──────────────────────┐                      │
│     │  CustodyProofs   │      │  PublicKeyRegistry   │                      │
│     │                  │      │                      │                      │
│     │  Depends on:     │      │  Standalone          │                      │
│     │  • ObjectRegistry│      │  (no deps)           │                      │
│     └──────────────────┘      └──────────────────────┘                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Deployment Order

1. `BucketRegistry` - No dependencies
2. `PublicKeyRegistry` - No dependencies (can deploy in parallel)
3. `BucketAccess` - Requires BucketRegistry address
4. `ObjectRegistry` - Requires BucketRegistry + BucketAccess addresses
5. `CustodyProofs` - Requires ObjectRegistry address + satellite address

---

## 4. Contract Details

### 4.1 BucketRegistry

**Purpose:** Manage buckets (containers for objects), similar to S3 buckets.

**Key Concept:** Bucket names are unique *per owner*, not globally. Alice and Bob can both have a bucket named "documents".

```solidity
struct Bucket {
    bytes32 bucketId;           // Unique identifier (hash of owner + name + timestamp)
    address owner;              // Bucket owner
    string name;                // Human-readable name (max 63 chars)
    uint256 createdAt;          // Creation timestamp
    bytes32 encryptionKeyHash;  // Hash of bucket's master encryption key
    bool exists;                // Existence flag
}
```

**Key Functions:**

| Function | Access | Purpose |
|----------|--------|---------|
| `createBucket(name, keyHash)` | Anyone | Create a new bucket |
| `deleteBucket(bucketId)` | Owner only | Delete a bucket |
| `getBucket(bucketId)` | View | Get bucket details |
| `listBuckets(owner)` | View | List all buckets for an owner |
| `bucketExists(bucketId)` | View | Check if bucket exists |

**Events:**
- `BucketCreated(bucketId, owner, name, timestamp)`
- `BucketDeleted(bucketId, owner, timestamp)`

---

### 4.2 BucketAccess

**Purpose:** Manage access control and encrypted key distribution for buckets.

**Key Concept:** Each user's access includes an `encryptedBucketKey` - the bucket's master encryption key encrypted specifically for that user using ECIES. This enables trustless key sharing without any party (including Madari) being able to read the keys.

```solidity
enum Permission { NONE, READ, WRITE, ADMIN }

struct Grant {
    bytes encryptedBucketKey;   // Bucket key encrypted for this user (ECIES)
    Permission permission;       // Access level
    uint256 grantedAt;          // When access was granted
    address grantedBy;          // Who granted access
}
```

**Permission Levels:**

| Permission | Download | Upload | Grant/Revoke | Delete Bucket |
|------------|----------|--------|--------------|---------------|
| NONE | ❌ | ❌ | ❌ | ❌ |
| READ | ✅ | ❌ | ❌ | ❌ |
| WRITE | ✅ | ✅ | ❌ | ❌ |
| ADMIN | ✅ | ✅ | ✅ | ✅ |

**Key Functions:**

| Function | Access | Purpose |
|----------|--------|---------|
| `initializeOwnerAccess(bucketId, encryptedKey)` | Owner | Set up owner's encrypted key after bucket creation |
| `grantAccess(bucketId, user, encryptedKey, permission)` | Admin | Grant access to a user |
| `revokeAccess(bucketId, user)` | Admin | Remove a user's access |
| `updateEncryptedBucketKey(bucketId, user, newKey)` | Admin | Update key (for re-keying operations) |
| `canAccess/canWrite/canAdmin(bucketId, user)` | View | Check permissions |
| `getEncryptedBucketKey(bucketId, user)` | View | Get user's encrypted key |

**Events:**
- `AccessGranted(bucketId, user, permission, grantedBy)`
- `AccessRevoked(bucketId, user, revokedBy)`
- `BucketKeyUpdated(bucketId, user)`

---

### 4.3 ObjectRegistry

**Purpose:** Track objects (files) stored in buckets.

**Key Concept:** Only the content *hash* is stored on-chain, not the content itself. The actual encrypted file lives on the satellite. This contract links the on-chain record to the off-chain storage.

```solidity
struct Object {
    bytes32 objectId;       // Unique identifier
    bytes32 bucketId;       // Parent bucket
    string key;             // Path within bucket (e.g., "/docs/contract.pdf")
    bytes32 contentHash;    // SHA-256 of encrypted content
    uint256 size;           // Size in bytes
    uint256 uploadedAt;     // Upload timestamp
    address uploadedBy;     // Who uploaded
    bool exists;            // Existence flag
}
```

**Key Functions:**

| Function | Access | Purpose |
|----------|--------|---------|
| `putObject(bucketId, key, hash, size)` | WRITE permission | Create or update an object |
| `deleteObject(bucketId, key)` | WRITE permission | Delete an object |
| `getObject(objectId)` | View | Get object by ID |
| `getObjectByKey(bucketId, key)` | View | Get object by bucket + key |
| `listObjects(bucketId)` | View | List all objects in bucket |
| `objectCount(bucketId)` | View | Count objects in bucket |

**Events:**
- `ObjectCreated(objectId, bucketId, key, contentHash, size, uploadedBy)`
- `ObjectUpdated(objectId, bucketId, newContentHash, newSize, updatedBy)`
- `ObjectDeleted(objectId, bucketId, key, deletedBy)`

---

### 4.4 CustodyProofs

**Purpose:** Record cryptographic attestations from the satellite proving custody of objects in orbit.

**Key Concept:** The satellite has a private key that *never leaves orbit*. A valid signature from this key is mathematical proof the attestation originated from the satellite. Combined with orbital telemetry, this proves data custody in space.

```solidity
struct Attestation {
    bytes32 attestationId;      // Unique identifier
    bytes32 objectId;           // Object being attested
    bytes32 bucketId;           // Parent bucket
    uint256 timestamp;          // When generated (satellite time)
    int256 latitude;            // Orbital position (scaled 1e6)
    int256 longitude;           // Orbital position (scaled 1e6)
    uint256 altitude;           // Altitude in meters
    bytes32 contentHashAttest;  // Hash at attestation time
    bytes signature;            // Satellite's ECDSA signature (65 bytes)
    uint256 submittedAt;        // When recorded on-chain
}
```

**What Makes This "Proof":**

1. **Satellite signature:** 65-byte ECDSA secp256k1 signature. The private key is stored in the satellite's HSM and never leaves orbit.

2. **Content hash verification:** The satellite re-hashes stored data at attestation time. Matching hash = data integrity verified.

3. **Orbital telemetry:** Latitude, longitude, altitude can be cross-referenced with public TLE (Two-Line Element) data to verify satellite position.

4. **Immutable record:** Once on the blockchain, the attestation cannot be altered or deleted.

**Key Functions:**

| Function | Access | Purpose |
|----------|--------|---------|
| `submitAttestation(objectId, timestamp, lat, lon, alt, hash, sig)` | Anyone | Record an attestation |
| `getAttestation(attestationId)` | View | Get attestation details |
| `getLatestAttestation(objectId)` | View | Get most recent attestation |
| `verifyContentHash(objectId, hash)` | View | Check if hash matches latest attestation |
| `hasAttestation(objectId)` | View | Check if object has any attestations |
| `updateSatelliteAddress(newAddr)` | Owner | Rotate satellite key |

**Events:**
- `AttestationSubmitted(attestationId, objectId, bucketId, timestamp, lat, lon, alt)`
- `SatelliteAddressUpdated(oldAddress, newAddress)`

---

### 4.5 PublicKeyRegistry

**Purpose:** Store user public keys for ECIES encryption key exchange.

**Key Concept:** To share access to a bucket, you need the recipient's public key to encrypt the bucket key for them. This contract provides a decentralized directory of user public keys.

```solidity
// User => Public Key (65 bytes, uncompressed secp256k1)
mapping(address => bytes) public publicKeys;
```

**Key Functions:**

| Function | Access | Purpose |
|----------|--------|---------|
| `registerPublicKey(publicKey)` | Anyone | Register your public key |
| `getPublicKey(user)` | View | Get a user's public key |
| `hasPublicKey(user)` | View | Check if user has registered |
| `getPublicKeys(users[])` | View | Batch lookup (gas efficient) |

**Events:**
- `PublicKeyRegistered(user, publicKey, timestamp)`
- `PublicKeyUpdated(user, oldKey, newKey, timestamp)`

---

## 5. Encryption Model

### Envelope Encryption

Madari uses **envelope encryption** - a standard pattern used by AWS KMS, Google Cloud KMS, and similar services.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ENVELOPE ENCRYPTION                                  │
│                                                                              │
│   FILE UPLOAD:                                                               │
│                                                                              │
│   1. Generate random DEK (Data Encryption Key)                              │
│      DEK = random 256 bits                                                  │
│                                                                              │
│   2. Encrypt file with DEK                                                  │
│      encryptedFile = AES-256-GCM(file, DEK)                                │
│                                                                              │
│   3. Encrypt DEK with bucket master key                                     │
│      (Bucket key is already encrypted per-user on-chain)                    │
│                                                                              │
│   4. Store:                                                                  │
│      - encryptedFile → Satellite                                            │
│      - contentHash   → Blockchain (ObjectRegistry)                          │
│      - Bucket key encryption → Blockchain (BucketAccess)                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Hierarchy

```
User's Wallet Private Key
         │
         │ derives
         ▼
User's Encryption Public Key ──────────────────┐
                                               │
                                               ▼
                              ┌────────────────────────────────┐
                              │     On-Chain (BucketAccess)     │
                              │                                 │
                              │  encryptedBucketKey per user:   │
                              │  • Alice: ECIES(bucketKey, A)   │
                              │  • Bob:   ECIES(bucketKey, B)   │
                              │  • Carol: ECIES(bucketKey, C)   │
                              └────────────────────────────────┘
                                               │
                                               │ user decrypts with
                                               │ their private key
                                               ▼
                                        Bucket Master Key
                                               │
                                               │ used to derive
                                               ▼
                                         Per-File DEKs
                                               │
                                               │ encrypt/decrypt
                                               ▼
                                        File Content
```

### Encryption Algorithms

| Purpose | Algorithm | Key Size | Notes |
|---------|-----------|----------|-------|
| File encryption | AES-256-GCM | 256 bits | Authenticated encryption |
| Key wrapping | ECIES | secp256k1 | Ethereum-compatible |
| Content hashing | SHA-256 | 256 bits | Industry standard |
| Signature | ECDSA secp256k1 | 256 bits | Native EVM verification |

---

## 6. Access Control Flow

### Granting Access

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ALICE GRANTS BOB READ ACCESS                             │
│                                                                              │
│   ALICE'S CLIENT:                                                            │
│                                                                              │
│   1. Fetch Alice's encryptedBucketKey from chain                            │
│      encKey_alice = BucketAccess.getEncryptedBucketKey(bucketId, alice)     │
│                                                                              │
│   2. Decrypt bucket key with Alice's private key                            │
│      bucketKey = ECIES.decrypt(encKey_alice, alice.privateKey)              │
│                                                                              │
│   3. Get Bob's public key from registry                                     │
│      bob.publicKey = PublicKeyRegistry.getPublicKey(bob.address)            │
│                                                                              │
│   4. Encrypt bucket key for Bob                                             │
│      encKey_bob = ECIES.encrypt(bucketKey, bob.publicKey)                   │
│                                                                              │
│   5. Call smart contract                                                     │
│      BucketAccess.grantAccess(bucketId, bob, encKey_bob, READ)              │
│                                                                              │
│   RESULT: Bob can now fetch his encryptedBucketKey, decrypt it, and         │
│           access all files in the bucket.                                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Revoking Access

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ALICE REVOKES BOB'S ACCESS                               │
│                                                                              │
│   1. Alice calls BucketAccess.revokeAccess(bucketId, bob)                   │
│                                                                              │
│   2. Bob's grant is deleted from chain                                      │
│                                                                              │
│   3. Bob can no longer:                                                      │
│      - Fetch his encryptedBucketKey (reverts with "No access")              │
│      - Download files via API (access check fails)                          │
│                                                                              │
│   LIMITATION:                                                                │
│   If Bob previously decrypted and saved the bucket key, he still has it.    │
│   Revocation stops FUTURE downloads through our system, but doesn't         │
│   cryptographically invalidate keys Bob already possesses.                   │
│                                                                              │
│   For true cryptographic revocation, use RE-KEYING (see section 7).         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Re-Keying (Advanced)

For high-security scenarios where revocation must be cryptographically enforced:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CRYPTOGRAPHIC REVOCATION VIA RE-KEY                      │
│                                                                              │
│   1. Generate new bucket key                                                 │
│      newBucketKey = random 256 bits                                         │
│                                                                              │
│   2. Download all files from satellite                                      │
│      files[] = satellite.fetchAll(bucketId)                                 │
│                                                                              │
│   3. Re-encrypt each file with new key                                      │
│      for each file:                                                          │
│        decrypted = decrypt(file, oldBucketKey)                              │
│        reencrypted = encrypt(decrypted, newBucketKey)                       │
│        satellite.store(reencrypted)                                          │
│                                                                              │
│   4. Update encryptedBucketKey for all REMAINING users                      │
│      for each user (except revoked user):                                    │
│        BucketAccess.updateEncryptedBucketKey(bucketId, user, ECIES(new))    │
│                                                                              │
│   5. Revoke the user                                                         │
│      BucketAccess.revokeAccess(bucketId, revokedUser)                       │
│                                                                              │
│   RESULT: Old key is now useless. Files are encrypted with new key.         │
│   Even if revoked user has old key, they cannot decrypt new ciphertext.     │
│                                                                              │
│   COST: O(files) re-encryption + O(users) chain writes                      │
│   USE CASE: High-security documents, small user count                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Custody Proof Flow

### End-to-End Attestation Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CUSTODY ATTESTATION FLOW                             │
│                                                                              │
│   ┌──────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │
│   │  Client  │    │Ground Station│    │  Satellite   │    │  Blockchain  │ │
│   └────┬─────┘    └──────┬───────┘    └──────┬───────┘    └──────┬───────┘ │
│        │                 │                   │                   │          │
│        │  1. Upload      │                   │                   │          │
│        │─────────────────►                   │                   │          │
│        │                 │  2. Relay to      │                   │          │
│        │                 │     satellite     │                   │          │
│        │                 │──────────────────►│                   │          │
│        │                 │                   │                   │          │
│        │                 │                   │  3. Store &       │          │
│        │                 │                   │     generate      │          │
│        │                 │                   │     attestation   │          │
│        │                 │                   │                   │          │
│        │                 │  4. Attestation   │                   │          │
│        │                 │◄──────────────────│                   │          │
│        │                 │                   │                   │          │
│        │                 │  5. Submit to chain                   │          │
│        │                 │───────────────────────────────────────►          │
│        │                 │                   │                   │          │
│        │  6. Verify proof│                   │                   │          │
│        │◄────────────────────────────────────────────────────────│          │
│        │                 │                   │                   │          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Attestation Data Structure

```
Attestation {
    objectId:         0xabc123...              // Links to ObjectRegistry
    bucketId:         0xdef456...              // Parent bucket
    timestamp:        1737388800               // 2026-01-20 14:00:00 UTC
    latitude:         25276987                 // 25.276987° (Dubai)
    longitude:        55296233                 // 55.296233°
    altitude:         550000                   // 550 km
    contentHashAttest: 0x789...                // SHA-256 of stored content
    signature:        0x... (65 bytes)         // ECDSA secp256k1
    submittedAt:      1737389000               // Block timestamp
}
```

### Verification

Anyone can verify an attestation:

1. **Signature verification:** Recover signer from signature, compare to registered `satelliteAddress`
2. **Content integrity:** Compare `contentHashAttest` with expected hash
3. **Position verification:** Cross-reference lat/lon/alt with public TLE data
4. **Timestamp ordering:** Verify `timestamp` is after object upload time

---

## 9. Gas Estimates

| Operation | Estimated Gas | Cost @ 25 gwei |
|-----------|---------------|----------------|
| Create Bucket | ~100,000 | ~$0.06 |
| Initialize Owner Access | ~80,000 | ~$0.05 |
| Grant Access | ~80,000 | ~$0.05 |
| Revoke Access | ~30,000 | ~$0.02 |
| Put Object | ~120,000 | ~$0.07 |
| Delete Object | ~40,000 | ~$0.02 |
| Submit Attestation | ~150,000 | ~$0.09 |
| Register Public Key | ~50,000 | ~$0.03 |

*Note: Madari L1 will have its own gas token and pricing. These estimates assume Ethereum mainnet gas prices for reference.*

---

## 10. Storage Overhead

### Per Bucket
- BucketRegistry: ~180 bytes
- BucketAccess (owner grant): ~220 bytes
- **Total:** ~400 bytes

### Per Object
- ObjectRegistry: ~280 bytes
- **Total:** ~280 bytes

### Per Attestation
- CustodyProofs: ~360 bytes
- **Total:** ~360 bytes

### Per Access Grant
- BucketAccess: ~220 bytes
- **Total:** ~220 bytes

### Example: 10 MB Document

```
Document: 10,485,760 bytes
+ Object registration: 280 bytes
+ 1 attestation: 360 bytes
+ 2 access grants: 440 bytes
─────────────────────────────
Blockchain overhead: 1,080 bytes (0.01%)
```

---

## 11. Security Considerations

### Threat Model

| Threat | Mitigated? | How |
|--------|------------|-----|
| Madari reads user data | ✅ | Client-side encryption |
| Ground station compromise | ✅ | Only sees encrypted bytes |
| Satellite storage breach | ✅ | Only stores encrypted bytes |
| Unauthorized download | ✅ | On-chain access control |
| Forged attestations | ✅ | Satellite signature verification |
| Key theft via chain | ✅ | Keys are ECIES encrypted per-user |
| Replay attestations | ✅ | Unique attestation IDs, timestamps |

### Known Limitations

1. **Revocation delay:** Revoked users retain previously-fetched encrypted keys until re-keying
2. **Signature verification:** Currently disabled in PoC; must be enabled for production
3. **Admin trust:** Bucket admins can grant/revoke arbitrarily
4. **Single satellite:** Initial deployment has one satellite; key compromise = system compromise

---

## 12. Future Enhancements

### Planned

- [ ] Enable signature verification in CustodyProofs
- [ ] Add batch operations for gas efficiency
- [ ] Implement time-limited access grants
- [ ] Add group-based access control

### Potential

- [ ] Cross-chain verification via Avalanche Warp Messaging
- [ ] Multiple satellite support with aggregated attestations
- [ ] Zero-knowledge proofs for private access verification
- [ ] Integration with decentralized identity (DID) systems

---

## 13. References

- [Madari PoC Architecture](../../../poc-architecture.md)
- [Encryption & Access Control Design](../../../encryption-access-control.md)
- [Ground Station Data Specification](../../../ground-station-data-spec.md)
- [Avalanche L1 Documentation](https://docs.avax.network/)
- [AES-GCM (NIST SP 800-38D)](https://csrc.nist.gov/publications/detail/sp/800-38d/final)
- [ECIES (IEEE 1363a)](https://en.wikipedia.org/wiki/Integrated_Encryption_Scheme)

---

*Document prepared by Deca4 Advisory for Madari Space.*

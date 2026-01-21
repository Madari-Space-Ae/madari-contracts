# Madari Smart Contracts

Smart contracts for **Madari Space** - sovereign document custody in orbit with cryptographic proof.

Built with [Foundry](https://book.getfoundry.sh/).

## Overview

Madari provides verifiable document storage on satellites. These contracts run on a custom **Avalanche L1** and handle:

**Key Value Proposition:** Without blockchain, customers must trust Madari's claim that data was stored in space. With blockchain, anyone can independently verify custody using cryptographic proofs signed by the satellite's onboard private key.

**Detailed Design:** See [`docs/smart-contract-design.md`](docs/smart-contract-design.md) for comprehensive documentation on architecture, encryption model, access control flows, and security considerations.

### What These Contracts Enable

| Capability | Contract | Description |
|------------|----------|-------------|
| **Bucket Management** | `BucketRegistry` | S3-style containers for organizing objects |
| **Access Control** | `BucketAccess` | Encrypted key distribution for trustless sharing |
| **Object Tracking** | `ObjectRegistry` | On-chain registry of files stored on satellite |
| **Custody Proofs** | `CustodyProofs` | Immutable record of satellite attestations |
| **Key Exchange** | `PublicKeyRegistry` | User public keys for ECIES encryption |

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTRACT ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐      ┌──────────────────┐                 │
│  │  BucketRegistry  │◄─────│   BucketAccess   │                 │
│  │                  │      │                  │                 │
│  │  • createBucket  │      │  • grantAccess   │                 │
│  │  • deleteBucket  │      │  • revokeAccess  │                 │
│  │  • getBucket     │      │  • getGrant      │                 │
│  └────────┬─────────┘      └────────┬─────────┘                 │
│           │                         │                           │
│           │    references           │                           │
│           ▼                         ▼                           │
│  ┌──────────────────┐      ┌──────────────────┐                 │
│  │  ObjectRegistry  │      │  CustodyProofs   │                 │
│  │                  │      │                  │                 │
│  │  • putObject     │      │  • submitAttest  │                 │
│  │  • deleteObject  │      │  • verifyHash    │                 │
│  │  • getObject     │      │  • getProofs     │                 │
│  └──────────────────┘      └──────────────────┘                 │
│                                                                  │
│  ┌──────────────────┐                                           │
│  │ PublicKeyRegistry│  (standalone - for ECIES key exchange)    │
│  │                  │                                           │
│  │  • registerKey   │                                           │
│  │  • getPublicKey  │                                           │
│  └──────────────────┘                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Contracts

| Contract | Purpose | Key Functions |
|----------|---------|---------------|
| `BucketRegistry` | Manage buckets (containers) | `createBucket`, `deleteBucket`, `listBuckets` |
| `BucketAccess` | Access control & encrypted keys | `grantAccess`, `revokeAccess`, `getEncryptedBucketKey` |
| `ObjectRegistry` | Track objects in buckets | `putObject`, `deleteObject`, `getObject` |
| `CustodyProofs` | Record satellite attestations | `submitAttestation`, `getLatestAttestation`, `verifyContentHash` |
| `PublicKeyRegistry` | Store user public keys for ECIES | `registerPublicKey`, `getPublicKey` |

## Project Structure

```
madari-contracts/
├── src/                      # Contract source files
│   ├── BucketRegistry.sol    # Bucket CRUD operations
│   ├── BucketAccess.sol      # ACL and encrypted key storage
│   ├── ObjectRegistry.sol    # Object tracking
│   ├── CustodyProofs.sol     # Satellite attestations
│   └── PublicKeyRegistry.sol # User public key storage
├── test/                     # Foundry tests (Solidity)
│   └── BucketRegistry.t.sol  # Example test
├── script/                   # Deployment scripts
├── docs/                     # Documentation
│   └── smart-contract-design.md  # Comprehensive design doc
├── lib/                      # Dependencies (forge-std)
├── foundry.toml              # Foundry configuration
└── README.md                 # This file
```

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/smart-contract-design.md`](docs/smart-contract-design.md) | Comprehensive design document covering architecture, encryption model, access control flows, custody proofs, and security considerations |
| [README.md](README.md) | Quick start guide and contract overview (this file) |

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Install

```bash
# Clone the repo
git clone https://github.com/Madari-Space-Ae/madari-contracts.git
cd madari-contracts

# Install dependencies
forge install
```

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test test_CreateBucket

# Run with gas report
forge test --gas-report
```

### Format

```bash
forge fmt
```

## Foundry Commands

| Command | Description |
|---------|-------------|
| `forge build` | Compile contracts |
| `forge test` | Run tests |
| `forge test -vvvv` | Run tests with full trace |
| `forge fmt` | Format code |
| `forge coverage` | Generate coverage report |
| `forge snapshot` | Generate gas snapshots |
| `forge script` | Run deployment scripts |
| `cast` | CLI for interacting with contracts |
| `anvil` | Local testnet node |

## Deployment

### Local (Anvil)

```bash
# Start local node
anvil

# Deploy (in another terminal)
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Avalanche Fuji Testnet

```bash
# Set environment variables
export AVALANCHE_FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc
export PRIVATE_KEY=your_private_key

# Deploy
forge script script/Deploy.s.sol --rpc-url $AVALANCHE_FUJI_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Madari L1 Testnet (AvaCloud)

```bash
# Set environment variables (see .env.example)
export MADARI_TESTNET_RPC_URL=https://subnets.avax.network/madari/testnet/rpc
export PRIVATE_KEY=your_private_key

# Deploy
forge script script/Deploy.s.sol --rpc-url $MADARI_TESTNET_RPC_URL --private-key $PRIVATE_KEY --broadcast

# Verify on explorer
# Explorer: https://explorer-test.avax.network/madari
```

## Network Configuration

### Madari L1 Testnet

| Field | Value |
|-------|-------|
| **Network Name** | Madari L1 Testnet |
| **Public RPC** | `https://subnets.avax.network/madari/testnet/rpc` |
| **Explorer** | https://explorer-test.avax.network/madari |
| **Chain ID** | See AvaCloud console |

> **Note:** Developer RPC endpoints with WebSocket support are available via AvaCloud console (require authentication token).

## Environment Variables

Create a `.env` file (gitignored) - see `.env.example`:

```bash
# Madari L1 Testnet
MADARI_TESTNET_RPC_URL=https://subnets.avax.network/madari/testnet/rpc

# Avalanche Fuji (for testing)
AVALANCHE_FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc

# Deployment
PRIVATE_KEY=your_deployer_private_key

# Verification (optional)
SNOWTRACE_API_KEY=your_snowtrace_api_key
```

## Contract Interaction

### Using Cast

```bash
# Read bucket
cast call $BUCKET_REGISTRY "getBucket(bytes32)" $BUCKET_ID --rpc-url $RPC_URL

# Create bucket (write)
cast send $BUCKET_REGISTRY "createBucket(string,bytes32)" "my-bucket" $(cast keccak "encryption-key") --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### Using Forge Console

```bash
forge console --rpc-url $RPC_URL
```

## Security

### Access Control

- **Bucket ownership**: Only owner or ADMIN can grant/revoke access
- **Write access**: WRITE or ADMIN permission required for object operations
- **Owner protection**: Cannot revoke owner's access

### Cryptographic Model

- Files encrypted client-side with AES-256-GCM
- Encryption keys stored on-chain, encrypted per-user via ECIES
- Satellite signatures verified on-chain (ECDSA secp256k1)

### Audits

> ⚠️ These contracts have not been audited. Use at your own risk.

## Gas Estimates

| Operation | Estimated Gas |
|-----------|---------------|
| Create Bucket | ~100,000 |
| Grant Access | ~80,000 |
| Put Object | ~120,000 |
| Submit Attestation | ~150,000 |
| Register Public Key | ~50,000 |

## License

MIT

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests: `forge test`
4. Format code: `forge fmt`
5. Submit a pull request

---

**Madari Space** - Sovereign custody in orbit

Built by [Deca4 Advisory](https://deca4.com)

# Ground Station Bytes Overhead

**Purpose:** Estimate additional bytes transmitted via ground station link for Madari file operations.

---

## Summary

| Direction | Fixed Overhead | Notes |
|-----------|----------------|-------|
| **Uplink** (file upload) | ~150 bytes | Encryption + metadata |
| **Downlink** (attestation) | ~149 bytes | Per custody attestation |

---

## Uplink: File Upload (Ground → Satellite)

When uploading a file, the following is transmitted:

### Encryption Overhead (AES-256-GCM)

| Component | Bytes |
|-----------|-------|
| IV (nonce) | 12 |
| Authentication tag | 16 |
| **Subtotal** | **28** |

### Metadata (sent with file)

| Component | Bytes | Notes |
|-----------|-------|-------|
| Content hash (SHA-256) | 32 | For integrity verification |
| Bucket ID | 32 | Target bucket identifier |
| Object key (path) | ~50 | Variable, e.g. `/docs/file.pdf` |
| File size | 8 | uint64 |
| **Subtotal** | **~122** |

### Total Uplink Overhead

**~150 bytes fixed** + encrypted file (same size as original)

---

## Downlink: Custody Attestation (Satellite → Ground)

After storing a file, the satellite generates and transmits a custody attestation:

| Component | Bytes | Notes |
|-----------|-------|-------|
| Object ID | 32 | Which object |
| Timestamp | 8 | Attestation time (UTC) |
| Latitude | 4 | Orbital position (scaled 1e6) |
| Longitude | 4 | Orbital position (scaled 1e6) |
| Altitude | 4 | Meters above sea level |
| Content hash | 32 | SHA-256 at attestation time |
| ECDSA signature | 65 | secp256k1 (r, s, v) |
| **Total** | **~149** |

---

## Examples by File Size

| Original File | Encrypted | + Metadata | Total Uplink | Overhead |
|---------------|-----------|------------|--------------|----------|
| 100 B | 128 B | 250 B | **250 B** | +150% |
| 1 KB | 1,052 B | 1,174 B | **~1.2 KB** | +17% |
| 10 KB | 10,268 B | 10,390 B | **~10.4 KB** | +4% |
| 100 KB | 102,428 B | 102,550 B | **~102.5 KB** | +0.5% |
| 1 MB | ~1.00 MB | ~1.00 MB | **~1.00 MB** | <0.1% |

**Key insight:** Fixed overhead of ~150 bytes. Significant for tiny files, negligible for larger files.

---

## Downlink: File Retrieval

When downloading a file from the satellite:

| Component | Bytes |
|-----------|-------|
| Encrypted file | Original size + 28 |
| Content hash | 32 |
| **Total** | **Original + ~60 bytes** |

---

## Quick Reference

```
100-byte file upload:
  File:       100 B
  + Encrypt:   28 B  (IV + auth tag)
  + Metadata: 122 B  (hash, bucket, key, size)
  ─────────────────
  Total:      250 B  transmitted

Attestation (per file):
  Payload:    149 B  transmitted back
```

---

*Prepared by Deca4 Advisory - January 2026*

# 📋 On-chain Notary Service

A decentralized notary service built on Stacks blockchain that allows authorized notaries to notarize documents, verify their authenticity, and maintain an immutable record of document lifecycle.

## 🚀 Features

- **Document Notarization**: Submit document hashes for permanent on-chain notarization
- **Notary Registry**: Authorized notary management with reputation scoring
- **Document Verification**: Multi-party verification system with reputation rewards
- **Document Revocation**: Ability to revoke documents with proper authorization
- **Batch Processing**: Notarize multiple documents in a single transaction
- **Hash Verification**: Built-in document hash verification utilities

## 📊 Contract Overview

The contract manages three main data structures:
- **Documents**: Store notarized document information with timestamps and metadata
- **Notary Registry**: Track authorized notaries and their reputation scores
- **Revocations**: Maintain records of revoked documents and reasons

## 🔧 Usage Instructions

### Becoming a Notary

```clarity
(contract-call? .On-chain-Notary-Service register-notary)
```

### Notarizing a Document

```clarity
(contract-call? .On-chain-Notary-Service notarize-document 
    0x[document-hash] 
    0x[signature] 
    u"Document metadata")
```

### Verifying a Document

```clarity
(contract-call? .On-chain-Notary-Service verify-document 
    0x[document-hash] 
    0x[verifier-signature])
```

### Batch Notarization

```clarity
(contract-call? .On-chain-Notary-Service batch-notarize 
    (list 
        { hash: 0x[hash1], signature: 0x[sig1], metadata: u"Doc 1" }
        { hash: 0x[hash2], signature: 0x[sig2], metadata: u"Doc 2" }
    ))
```

### Reading Document Information

```clarity
(contract-call? .On-chain-Notary-Service get-document-info 0x[document-hash])
```

## 🔍 Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-document-info` | Get complete document information |
| `get-notary-info` | Get notary registration details |
| `is-document-valid` | Check if document is valid (verified and not revoked) |
| `get-notary-documents-count` | Get total documents notarized by a notary |
| `get-notary-reputation` | Get notary reputation score |
| `calculate-document-age` | Get document age in blocks |
| `get-service-fee` | Get current notarization fee |
| `get-total-documents` | Get total notarized documents |
| `get-total-notaries` | Get total registered notaries |

## 💰 Fees

The contract charges a service fee for notarization (default: 1 STX). Fees are transferred to the contract owner and can be updated by the owner.

## 🛡️ Security Features

- **Authorization Checks**: Only authorized notaries can notarize documents
- **Ownership Controls**: Contract owner can revoke notaries and update fees
- **Document Integrity**: Prevents duplicate notarization of same hash
- **Reputation System**: Tracks notary performance with point-based scoring

## 🏗️ Development

### Prerequisites

- Clarinet CLI
- Node.js (for testing)

### Setup

```bash
clarinet check
npm install
npm test
```

### Testing

Run the test suite to verify contract functionality:

```bash
npm test
```

## 📈 Reputation System

- **Registration**: New notaries start with 100 reputation points
- **Verification**: +10 points for document owner, +5 for verifier
- **Challenges**: -5 points when document is challenged
- **Revocations**: -20 points when document is revoked

## 🔒 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `err-owner-only` | Function requires contract owner |
| u101 | `err-document-exists` | Document already notarized |
| u102 | `err-document-not-found` | Document does not exist |
| u103 | `err-invalid-hash` | Invalid document hash provided |
| u104 | `err-unauthorized` | User not authorized for action |
| u105 | `err-invalid-signature` | Invalid signature provided |

## 📝 License

MIT License - feel free to use and modify as needed.

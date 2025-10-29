# CipherVote

> Privacy-preserving voting platform powered by Zama FHEVM

CipherVote enables confidential on-chain voting using Zama’s Fully Homomorphic Encryption Virtual Machine. Ballots remain encrypted during casting, tallying, and verification.

---

## Why CipherVote

Traditional voting dApps expose choices on-chain. CipherVote keeps every vote encrypted while preserving public verifiability of results.

- 🔐 Encrypted ballots end-to-end
- 🔒 Tally on encrypted data (no decryption in contracts)
- 🌐 Verifiable outcomes without revealing individual votes
- 🧩 Fits on-chain governance and privacy-first polls

---

## Zama FHEVM

FHEVM (Fully Homomorphic Encryption Virtual Machine) allows smart contracts to compute over encrypted data. With Zama FHE, CipherVote tallies votes without ever seeing voter choices.

```
Voter → FHE Encrypt → Encrypted Ballot → FHEVM Smart Contract
                                   └─> Encrypted Tally → Verifiable Result
```

Key properties:
- No plaintext ballots on-chain
- Encrypted operations (cast, aggregate, verify)
- Public result proofs without leaking vote details

---

## Getting Started

Prerequisites:
- Node.js 18+
- MetaMask (or compatible Web3 wallet)
- Sepolia ETH (testnet)

Setup:
```bash
git clone https://github.com/sendmeflowersand/CipherVote
cd CipherVote
npm install
cp .env.example .env.local
```

Deploy:
```bash
npm run deploy:sepolia
```

Run:
```bash
npm run dev
```

---

## How It Works

1) Encrypt ballot client-side (FHE public key)
2) Submit encrypted ballot to contract
3) Contract aggregates encrypted ballots (FHE add)
4) Produce encrypted tally; authorized verifier finalizes result
5) Publish verifiable result without revealing individual votes

Privacy model:
- Ballots: Encrypted (never in plaintext on-chain)
- Tally: Computed over ciphertexts
- Result: Public, verifiable, privacy-preserving
- Metadata: Minimized; no link between identity and choice

---

## Tech Stack

- FHE Engine: Zama FHE / FHEVM
- Smart Contracts: Solidity + FHEVM patterns
- Frontend: React, TypeScript
- Tooling: Hardhat, Ethers
- Security: EIP-712 signing, best practices

---

## Example Flows

Casting a vote:
- Prepare ballot locally → FHE encrypt → submit
Tally phase:
- Maintainer triggers tally → contract performs FHE aggregation
Verification:
- Publish final result proof → anyone can verify outcome integrity

---

## Security & Privacy

- Votes never decrypted by contracts
- Zero-knowledge style verification of outcomes
- No plaintext state of ballots on-chain
- Recommended: independent audits of circuits and contracts

Best practices:
- Use testnet keys while developing
- Rotate FHE keys for distinct elections
- Minimize off-chain metadata collection

---

## Use Cases

- DAO governance with private choice
- Community polls without social influence
- Sensitive decisions (HR, procurement, partner selection)
- Classroom/academic voting

---

## Contributing

We welcome contributions:
- FHE performance optimization
- Contract safety and audits
- Frontend UX for private voting flows
- Docs and examples

---

## Resources

- Zama: https://www.zama.ai
- FHEVM Docs: https://docs.zama.ai/fhevm
- Sepolia Explorer: https://sepolia.etherscan.io

---

## License

MIT — see LICENSE.

---

Built with Zama FHEVM — private ballots, verifiable results.
```

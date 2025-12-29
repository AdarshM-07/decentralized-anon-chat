# 🔐 Anonymous Chat System with Zero-Knowledge Proofs

A privacy-preserving decentralized chat system built with **Solidity**, **Noir**, and **Zero-Knowledge Proofs**. Users can deposit funds into a global vault and anonymously fund both **instant messages** and **future-scheduled messages** in chat rooms without revealing their identity.

[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Noir](https://img.shields.io/badge/Powered%20by-Noir-000000.svg)](https://noir-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🌟 Features

- **🎭 Anonymous Funding**: Fund messages without revealing your identity using ZK-SNARKs
- **💬 Dual Chat Modes**: 
  - **Instant Messages**: Send messages immediately to chat rooms
  - **Future Chat**: Schedule messages for delivery at a future date
- **🌳 Merkle Tree Privacy**: Deposits stored in a Merkle tree for efficient privacy-preserving proofs
- **💰 Fixed Denomination**: Standard 0.1 ETH deposits for enhanced anonymity
- **🔒 Nullifier Protection**: Prevents double-spending through cryptographic nullifiers
- **🏠 Decentralized Chat Rooms**: Create and manage multiple chat rooms on-chain
- **⏰ Time-Locked Messages**: Set messages to appear days in the future
- **🛡️ Access Control**: Owner-controlled pause mechanism for emergency situations

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                User Deposits 0.1 ETH                    │
│        commitment = pedersen_hash(secret, nullifier)    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│            Smart Contract (Chatsystem)                  │
│  • Stores commitments in Merkle tree (depth: 3)        │
│  • Tracks Merkle root and nullifiers                    │
│  • Verifies ZK proofs via UltraVerifier                 │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│        User Generates ZK Proof (Noir Circuit)           │
│  Proves:                                                │
│  • Knowledge of secret & nullifier                       │
│  • Commitment is in the Merkle tree                      │
│  • Nullifier hasn't been used before                     │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│       Anonymous Withdrawal to Fund Messages             │
│  • Verifier validates ZK proof                          │
│  • 0.1 ETH sent to chatroom for message funding         │
│  • Nullifier marked as spent                            │
└─────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) - Smart contract development
- [Noir](https://noir-lang.org/docs/getting_started/installation) - Zero-knowledge proof language
- [Barretenberg](https://github.com/AztecProtocol/aztec-packages/tree/master/barretenberg) (`bb`) - Proof backend
- [Node.js](https://nodejs.org/) v16+ (for helper scripts)

## 🚀 Quick Start

### Installation

```shell
# Clone the repository
git clone https://github.com/yourusername/dAnonyChatSys.git
cd dAnonyChatSys

# Install dependencies
forge install

# Compile circuit
cd circuit
nargo compile

# Generate verifier contract from circuit (REQUIRED STEP!)
bb write_vk -b ./target/chat_privacy_circuit.json -o ./target/vk
bb write_solidity_verifier -k ./target/vk -o ../src/UltraVerifier.sol
cd ..

# Build contracts (now that verifier is generated)
forge build
```
# Compile circuit
cd circuit && nargo compile && cd ..
```

### Testing

```shell
# Run all smart contract tests
forge test -vv

# Run with gas reports
forge test --gas-report

# Test specific functionality
forge test --match-test testDepositToVault -vvvv

# Test circuit
cd circuit && nargo test && cd ..
```

**Test Results:** ✅ All 11 tests passing

## 📖 Usage Guide

### 1. Deploy Contracts

```shell
# Start local blockchain
anvil

# In another terminal, deploy
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

Save the output addresses:
- `Verifier`: 0x...
- `Chatsystem`: 0x...

### 2. Make a Deposit

```shell
CHAT_SYSTEM=0x... # Your Chatsystem address

# Generate commitment (save secret & nullifier privately!)
COMMITMENT=$(cast keccak "your_commitment_data")

# Deposit 0.1 ETH
cast send $CHAT_SYSTEM \
  "depositToGlobalVault(bytes32)" $COMMITMENT \
  --value 0.1ether \
  --rpc-url http://localhost:8545 \
  --private-key <PRIVATE_KEY>

# Check deposit
cast call $CHAT_SYSTEM "nextLeafIndex()(uint256)" --rpc-url http://localhost:8545
```

### 3. Create Chat Room & Post Messages

```shell
cast send $CHAT_SYSTEM \
  "createChatRoom(string,string)" "MyRoom" "Description" \
  --rpc-url http://localhost:8545 \
  --private-key <PRIVATE_KEY>

# Get room address
ROOM=$(cast call $CHAT_SYSTEM "getRoomAdd(string)(address)" "MyRoom" --rpc-url http://localhost:8545)

# Post instant message
cast send $CHAT_SYSTEM \
  "postMessageRelayed(address,string,string)" \
  $ROOM "Hello World!" "Anonymous" \
  --rpc-url http://localhost:8545 \
  --private-key <PRIVATE_KEY>

# Post future message (scheduled for 7 days from now)
cast send $CHAT_SYSTEM \
  "postMessageRelayed(address,string,string,uint256)" \
  $ROOM "Future Hello!" "TimeTraveler" 7 \
  --rpc-url http://localhost:8545 \
  --private-key <PRIVATE_KEY>
```

### 4. Generate ZK Proof & Withdraw Anonymously

```shell
cd circuit

# Update Prover.toml with:
# - secret, nullifier (your private values)
# - nullifier_hash, root, index, hash_path (from contract)

# Generate proof
nargo execute
bb prove -b ./target/chat_privacy_circuit.json \
         -w ./target/chat_privacy_circuit.gz \
         -o ./target/proof

# Submit proof to withdraw anonymously
# (See TESTING_GUIDE.md for detailed instructions)
```

## 🔐 How It Works

### Privacy Protocol

1. **Deposit**: User computes `commitment = pedersen_hash([secret, nullifier])` and deposits 0.1 ETH
2. **Merkle Tree**: Commitment is added to on-chain Merkle tree
3. **Chat Activity**: Users can post instant or future-scheduled messages to chat rooms
4. **Proof Generation**: User proves knowledge of secret/nullifier and Merkle membership
5. **Anonymous Withdrawal**: Contract verifies proof and sends 0.1 ETH to fund specific messages
6. **Nullifier**: Prevents double-spending by marking nullifier as used

### Message Types

**Instant Messages**: Posted immediately to chat rooms and visible right away
```solidity
postMessageRelayed(address room, string content, string alias)
```

**Future Chat**: Messages scheduled for future delivery
```solidity
postMessageRelayed(address room, string content, string alias, uint256 daysToSend)
```
Messages are time-locked and only become visible after the specified number of days

### Privacy Guarantees

- **Deposit-Withdrawal Unlinkability**: Cannot link withdrawals to specific deposits
- **Anonymity Set**: Privacy increases with each additional deposit
- **Front-Running Protection**: Nullifiers prevent replay attacks
- **Fixed Denominations**: Uniform amounts prevent tracking

## 📁 Project Structure

```
dAnonyChatSys/
├── src/
│   ├── chatSystem.sol       # Main vault & Merkle tree contract
│   ├── chatRoom.sol          # Chat room logic
│   ├── message.sol           # Message structure
│   └── UltraVerifier.sol     # ZK proof verifier (generated)
├── circuit/
│   ├── src/main.nr           # Noir ZK circuit
│   ├── Prover.toml           # Proof inputs
│   └── Nargo.toml            # Circuit config
├── test/
│   └── ChatSystem.t.sol      # Foundry tests
├── script/
│   └── Deploy.s.sol          # Deployment script
└── TESTING_GUIDE.md          # Detailed testing instructions
```

## 🔬 Circuit Details

**Public Inputs:**
- `root` - Merkle tree root
- `nullifier_hash` - Hash of the nullifier

**Private Inputs:**
- `secret` - Random secret value
- `nullifier` - Random nullifier value
- `index` - Leaf position in tree
- `hash_path` - Merkle proof (3 siblings)

**Constraints:**
1. Verify `commitment = pedersen_hash([secret, nullifier])`
2. Verify `nullifier_hash = pedersen_hash([nullifier])`
3. Verify Merkle proof from commitment to root
4. Assert computed root equals public root

## ⚠️ Security Notice

### Current Status: Experimental

This is a proof-of-concept and **NOT production-ready**.

**Known Limitations:**
- **Contract Size**: HonkVerifier (~32KB) exceeds EIP-170 limit (24KB). Deploy to networks that support large contracts or use a proxy pattern
- Hash function placeholder (keccak256 instead of proper Pedersen)
- Small Merkle tree (max 8 deposits)
- Not professionally audited
- No relayer infrastructure

### Before Mainnet Deployment

- [ ] Implement proper Pedersen hash matching Noir
- [ ] Professional security audit
- [ ] Increase Merkle tree depth
- [ ] Add relayer network
- [ ] Gas optimization
- [ ] Comprehensive integration tests
- [ ] Emergency mechanisms

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/name`)
3. Write tests for new features
4. Run `forge test` and `forge fmt`
5. Submit Pull Request

## 📚 Documentation

- [TESTING_GUIDE.md](./TESTING_GUIDE.md) - Comprehensive testing instructions
- [CIRCUIT_COMPATIBILITY.md](./CIRCUIT_COMPATIBILITY.md) - Circuit integration details
- [QUICK_START_TESTING.md](./QUICK_START_TESTING.md) - Quick testing reference

## 📚 Learn More

- [Noir Documentation](https://noir-lang.org/docs)
- [Foundry Book](https://book.getfoundry.sh/)
- [Zero-Knowledge Proofs](https://z.cash/technology/zksnarks/)
- [Tornado Cash](https://tornado.cash/) - Inspiration

## 📄 License

MIT License - see [LICENSE](LICENSE) file

## 🙏 Acknowledgments

- **Noir** - ZK proof language by Aztec
- **Foundry** - Smart contract framework
- **Barretenberg** - Proof system backend
- **Tornado Cash** - Privacy protocol inspiration

---

**⚠️ Disclaimer**: Experimental software. Use at your own risk. Not audited for production.

**Built for privacy and decentralization** 🔐

# Testing Guide for Anonymous Chat System with ZK Proofs

## Quick Start Testing

### 1. Run Basic Smart Contract Tests
```bash
cd /Users/mauryadarsh07gmail.com/Downloads/blockchain/dAnonyChatSys
forge test -vv
```

This tests:
- Contract deployment
- Deposits to the vault
- Merkle tree updates
- Chat room creation
- Pause functionality

### 2. Test ZK Circuit Alone
```bash
cd circuit

# Compile circuit
nargo compile

# Generate proof with test inputs from Prover.toml
nargo prove

# Verify proof locally
nargo verify
```

## Full Integration Test Flow

### Step 1: Prepare the Circuit

```bash
cd circuit

# Make sure Prover.toml has valid test data
cat Prover.toml
```

The Prover.toml should have:
- `secret`: Your private secret value
- `nullifier`: Your private nullifier value  
- `nullifier_hash`: pedersen_hash([nullifier])
- `root`: Current Merkle root from contract
- `index`: Position of your commitment in the tree
- `hash_path`: Merkle proof path (3 siblings for depth 3)

### Step 2: Generate Proof

```bash
# Compile and generate proof
nargo compile
nargo prove

# This creates: target/proof
```

### Step 3: Test Locally with Foundry

```bash
cd ..

# Run all tests
forge test -vv

# Run specific test
forge test --match-test testDepositToVault -vvvv

# Run with gas reports
forge test --gas-report
```

### Step 4: Deploy to Local Network

Terminal 1 - Start local blockchain:
```bash
anvil
```

Terminal 2 - Deploy contracts:
```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Save the output addresses:
# Verifier address: 0x...
# Chatsystem address: 0x...
```

### Step 5: Interact with Deployed Contracts

Using `cast` commands:

```bash
CHAT_SYSTEM=0x... # Your deployed address
VERIFIER=0x...

# Check initial state
cast call $CHAT_SYSTEM "nextLeafIndex()(uint256)"
cast call $CHAT_SYSTEM "currentRoot()(bytes32)"

# Generate a commitment (simplified - should use actual pedersen)
COMMITMENT=$(cast keccak "$(cast abi-encode "encode(uint256,uint256)" 7 11)")

# Deposit to vault
cast send $CHAT_SYSTEM "depositToGlobalVault(bytes32)" $COMMITMENT \
  --value 0.1ether \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Check updated state
cast call $CHAT_SYSTEM "nextLeafIndex()(uint256)"
cast call $CHAT_SYSTEM "currentRoot()(bytes32)"
cast call $CHAT_SYSTEM "commitments(uint256)(bytes32)" 0
```

## Generate Real Proof for Contract

### 1. Get Merkle Proof Data

After depositing, you need:
- Current Merkle root from contract
- Your commitment's index
- Merkle path (siblings)

You can create a script to calculate this:

```javascript
// getMerkleProof.js - pseudo code
const commitments = await chatSystem.commitments();
const myCommitmentIndex = commitments.findIndex(c => c === myCommitment);
const siblings = calculateMerklePath(commitments, myCommitmentIndex, TREE_HEIGHT);
const root = await chatSystem.currentRoot();
```

### 2. Update Prover.toml

```toml
root = "0x..." # from contract
nullifier_hash = "0x..." # pedersen_hash([nullifier])
secret = "7"
nullifier = "11" 
index = 0 # your leaf index
hash_path = [
    "0x...", # sibling at depth 0
    "0x...", # sibling at depth 1
    "0x..."  # sibling at depth 2
]
```

### 3. Generate and Extract Proof

```bash
cd circuit
nargo prove

# The proof is in target/proof (binary format)
# You need to convert it to bytes for Solidity

# With bb (Barretenberg):
bb proof_as_fields -p ./target/proof > proof_fields.txt
```

### 4. Call anonymousFund

```bash
# Read proof bytes
PROOF=$(cat circuit/target/proof | xxd -p | tr -d '\n')
ROOT=$(cast call $CHAT_SYSTEM "currentRoot()(bytes32)")
NULLIFIER_HASH="0x..." # your nullifier hash

# Create a chatroom first
cast send $CHAT_SYSTEM "createChatRoom(string,string)" "TestRoom" "Description" \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

ROOM=$(cast call $CHAT_SYSTEM "getRoomAdd(string)(address)" "TestRoom")

# Call anonymousFund with proof
cast send $CHAT_SYSTEM \
  "anonymousFund(address,address,bytes,bytes32,bytes32)" \
  $ROOM \
  0x0000000000000000000000000000000000000123 \
  0x$PROOF \
  $NULLIFIER_HASH \
  $ROOT \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## Automated Test Script

Run the provided test script:
```bash
chmod +x test.sh
./test.sh
```

## Debugging Tips

### Circuit Issues
```bash
# Check circuit compiles
nargo check

# Execute circuit with inputs
nargo execute

# Get detailed info
nargo info
```

### Contract Issues
```bash
# Trace failing transactions
forge test --match-test testName -vvvv

# Debug specific function
forge test --debug testName

# Check gas usage
forge snapshot
```

### Common Issues

**"Root mismatch: proof expired"**
- The Merkle root changed after you generated the proof
- Generate a new proof with the current root

**"Note already spent"**
- The nullifier was already used
- Use a different nullifier for a new withdrawal

**"Invalid ZK Proof"**
- Proof doesn't match the public inputs
- Verify all inputs in Prover.toml are correct
- Ensure hash functions match between circuit and contract

**"Vault full"**
- Maximum 8 commitments (TREE_HEIGHT = 3)
- Deploy a new contract or increase TREE_HEIGHT

## Next Steps

1. **Fix Pedersen Hash**: Replace placeholder with actual Pedersen implementation
2. **Create Client Library**: Build JS/TS library for proof generation
3. **Add Events**: Emit events for deposits and withdrawals
4. **Gas Optimization**: Optimize Merkle tree operations
5. **Security Audit**: Review nullifier tracking and proof verification

## Resources

- Noir Documentation: https://noir-lang.org/docs
- Foundry Book: https://book.getfoundry.sh/
- Barretenberg: https://github.com/AztecProtocol/barretenberg

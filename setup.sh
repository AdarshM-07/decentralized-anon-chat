#!/bin/bash
# Setup script for decentralized-anon-chat

set -e

echo "🚀 Setting up Decentralized Anonymous Chat System..."
echo ""

# Install Foundry dependencies
echo "📦 Installing Foundry dependencies..."
forge install
echo "✓ Dependencies installed"
echo ""

# Compile circuit
echo "🔨 Compiling Noir circuit..."
cd circuit
nargo compile
echo "✓ Circuit compiled"
echo ""

# Generate verifier
echo "⚡ Generating ZK verifier contract..."
bb write_vk -b ./target/chat_privacy_circuit.json -o ./target/vk
bb write_solidity_verifier -k ./target/vk -o ../src/UltraVerifier.sol
cd ..
echo "✓ Verifier generated at src/UltraVerifier.sol"
echo ""

# Build contracts
echo "🏗️  Building smart contracts..."
forge build
echo "✓ Contracts built"
echo ""

# Run tests
echo "🧪 Running tests..."
forge test -vv
echo ""

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Deploy: forge script script/Deploy.s.sol --rpc-url <RPC_URL> --broadcast"
echo "  2. Run tests: forge test -vv"
echo "  3. See README.md for usage instructions"

#!/usr/bin/env node

// Helper script to compute correct values for Prover.toml
// This uses the same hash as the circuit (placeholder keccak for now)

const crypto = require('crypto');

function fieldToBytes32(value) {
    const hex = BigInt(value).toString(16).padStart(64, '0');
    return '0x' + hex;
}

function keccakHash(...values) {
    // Placeholder - should use actual Pedersen in production
    const packed = values.map(v => {
        const hex = BigInt(v).toString(16).padStart(64, '0');
        return Buffer.from(hex, 'hex');
    });
    const hash = crypto.createHash('sha256').update(Buffer.concat(packed)).digest('hex');
    return '0x' + hash;
}

// Test values
const secret = 7;
const nullifier = 11;
const index = 0;

// Compute commitment = hash(secret, nullifier)
const commitment = keccakHash(secret, nullifier);
console.log('Commitment:', commitment);

// Compute nullifier_hash = hash(nullifier)
const nullifierHash = keccakHash(nullifier);
console.log('Nullifier Hash:', nullifierHash);

// Build Merkle tree with one leaf
const zeros = [fieldToBytes32(0)];
for (let i = 1; i < 3; i++) {
    const prev = zeros[i - 1];
    zeros.push(keccakHash(BigInt(prev), BigInt(prev)));
}

console.log('\nZero values:');
zeros.forEach((z, i) => console.log(`  zeros[${i}]:`, z));

// Merkle path for first deposit (index 0)
const hashPath = [];
let currentHash = commitment;
let currentIndex = index;

for (let level = 0; level < 3; level++) {
    if (currentIndex % 2 === 0) {
        // We are left child, sibling is right (zero)
        hashPath.push(zeros[level]);
        currentHash = keccakHash(BigInt(currentHash), BigInt(zeros[level]));
    } else {
        // We are right child, sibling is left
        hashPath.push(zeros[level]); // would be filledSubtrees[level]
        currentHash = keccakHash(BigInt(zeros[level]), BigInt(currentHash));
    }
    currentIndex = Math.floor(currentIndex / 2);
}

const root = currentHash;

console.log('\nMerkle Proof:');
console.log('  Index:', index);
console.log('  Hash Path:', hashPath);
console.log('  Root:', root);

console.log('\n=== Prover.toml ===');
console.log(`root = "${root}"`);
console.log(`nullifier_hash = "${nullifierHash}"`);
console.log(`secret = "${secret}"`);
console.log(`nullifier = "${nullifier}"`);
console.log(`index = ${index}`);
console.log(`hash_path = [`);
hashPath.forEach((h, i) => {
    console.log(`    "${h}"${i < hashPath.length - 1 ? ',' : ''}`);
});
console.log(`]`);

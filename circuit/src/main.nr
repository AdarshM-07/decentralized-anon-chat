use dep::std;

fn main(
    root: pub Field,           // Merkle root
    nullifier_hash: pub Field, // Public nullifier hash
    index: u32,                // Leaf index
    hash_path: [Field; 3],     // Merkle proof
    secret: Field,             // Private secret
    nullifier: Field           // Private nullifier
) {
    // ------------------------------------------------
    // 1. Commitment = Poseidon(secret, nullifier)
    // ------------------------------------------------
    let commitment = std::hash::pedersen_hash([secret, nullifier]);

    // ------------------------------------------------
    // 2. Nullifier hash = Poseidon(nullifier)
    // ------------------------------------------------
    let computed_nullifier_hash = std::hash::pedersen_hash([nullifier]);
    assert(computed_nullifier_hash == nullifier_hash);

    // ------------------------------------------------
    // 3. Merkle Tree Verification
    // ------------------------------------------------
    let mut current = commitment;
    let mut idx = index;

    for i in 0..3 {
        let sibling = hash_path[i];

        if idx % 2 == 0 {
            current = std::hash::pedersen_hash([current, sibling]);
        } else {
            current = std::hash::pedersen_hash([sibling, current]);
        }

        idx = idx / 2;
    }

    // ------------------------------------------------
    // 4. Root check
    // ------------------------------------------------
    assert(current == root);
}
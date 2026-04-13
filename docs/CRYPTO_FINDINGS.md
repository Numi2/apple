# Cryptographic Engineering Findings

This log records security-relevant implementation findings and the work completed to close them. It is not a production security audit.

## 2026-04-13: Accelerator Trust And Buffer Hygiene Hardening

Findings:

- Strided GPU hash and Keccak-F permutation APIs returned the full caller-declared output stride. Kernels write only the digest or state bytes, so unwritten padding could retain stale reusable-buffer contents.
- `SharedUploadRing` accepted copies smaller than a slot capacity without clearing the unused slot tail.
- Public tests differentially checked GPU results, but callers had no explicit CPU-verified API for deployments where accelerator execution is not trusted.
- The M31 fold kernels used generic integer remainder for field reduction and also modulo-reduced uploaded values during round evaluation. The public array API already enforces canonical M31 input, so modulo-reducing inputs in-kernel masked malformed uploaded buffers and kept a generic division-like operation in the private-data path.
- Several buffer-size checks depended on unchecked offset or arena arithmetic after earlier validation.

Work completed:

- Fixed-rate SHA3/Keccak hash plans and Keccak-F permutation plans now clear unwritten strided-output padding before returning host-visible `Data`.
- `SharedUploadRing.copy` now clears unused slot tails, and shared-buffer clearing uses an explicit zeroing primitive on Darwin.
- Added CPU-verified accelerator APIs: fixed-rate hash `hashVerified`, Keccak-F `permuteVerified`, raw Merkle `commitRawLeavesVerified` and plan `commitVerified`, planned Merkle `commitVerified`, and M31 sum-check `executeVerified`.
- Replaced the M31 GPU fold path with the `2^31 - 1` Mersenne reduction for canonical M31 values and removed input modulo reduction from round coefficient logging and folding.
- Added overflow-checked buffer offset, arena allocation, and planner layout arithmetic.
- Regression coverage now checks verified APIs, strided-output padding clearing, upload-ring tail clearing, and CPU/GPU M31 chunk equivalence after the reduction change.

Residual risk:

- Verified APIs require CPU-visible inputs. They do not validate private buffers that exist only on the GPU unless the caller also supplies a CPU copy or an independent expected result.
- This work does not defend against a compromised OS, malicious kernel driver, physical memory inspection, or hostile same-device co-tenants.

## 2026-04-13: Transcript Challenge Squeeze Expansion

Finding:

- `SHA3Oracle.TranscriptState.squeezeUInt32` and the GPU `transcript_squeeze_challenges` kernel derived challenge words from a repeated subset of the transcript state. The CPU path wrapped with `index & 15`; the GPU path used the same 16-word window. That was correct for the current one-challenge sum-check round tests, but it was not a sound general transcript squeeze for larger challenge batches.

Work completed:

- CPU challenge squeezing now walks the full SHA3-256 rate as `34` little-endian `UInt32` candidates per block.
- Squeezing beyond the first rate block applies Keccak-F1600 before continuing, matching the sponge construction used by the rest of the SHA3 code.
- CPU and GPU challenge reduction now uses rejection sampling instead of direct modulo reduction, so field elements are unbiased for the requested modulus.
- GPU transcript squeezing now matches the CPU oracle across the first squeeze-block boundary.
- Regression coverage now includes a fixed 40-challenge transcript vector and a GPU/CPU differential test over the same 40-challenge stream.
- The M31 sum-check chunk transcript now absorbs a versioned chunk header, per-round coefficient frame, and per-round challenge frame before deriving challenges.
- Regression coverage now includes a fixed framed M31 sum-check vector.

Reference:

- NIST FIPS 202, SHA-3 Standard: Permutation-Based Hash and Extendable-Output Functions: https://csrc.nist.gov/pubs/fips/202/final

## 2026-04-13: Merkle Opening Extraction And Verification

Finding:

- The Merkle commitment path produced CPU-verified roots, but there was no first-class opening proof API. Callers would have needed to read back or reconstruct intermediate levels outside the reusable GPU plan to answer inclusion queries.

Work completed:

- Added `MerkleOpeningProof` as a public proof object containing the leaf index, leaf bytes, bottom-up sibling hashes, and root.
- Added independent CPU SHA3 Merkle opening construction and verification. Verification hashes the leaf, folds each sibling according to the leaf-index bits, rejects malformed sibling/root layouts, and compares the recomputed root.
- Added a GPU raw-leaf opening path that hashes leaves on the GPU, extracts exactly one sibling node per level with `sha3_256_merkle_extract_sibling_32`, reduces the tree on resident private buffers, and reads back only the sibling path plus root.
- Added `openRawLeafVerified`, which compares the GPU opening against the CPU oracle and also verifies the returned proof against its root before accepting it.
- Regression coverage now checks CPU tamper detection, invalid leaf indices, single-leaf trees, strided fixed-rate leaves, and GPU/CPU opening equality for several leaf positions.

Residual risk:

- The target lower treelet is currently hashed once in the all-subtree root pass and once in the opening-extraction pass. This keeps the implementation simple and fully verified, but leaves a tuning opportunity for a future combined root/opening kernel.

## 2026-04-13: Race-Free Merkle Treelets

Finding:

- The threadgroup-local Merkle treelet and fused-upper kernels compacted parent nodes into the same scratch span that sibling threads could still be reading as child input. CPU/GPU tests passed on the benchmark host, but the layout depended on implicit execution ordering inside a threadgroup and was not an acceptable cryptographic implementation invariant.

Work completed:

- Reworked `sha3_256_merkle_treelet_leaves_specialized` and `sha3_256_merkle_fuse_upper_32` to use two threadgroup scratch halves and swap read/write bases after each level.
- Updated Swift feasibility and dispatch sizing so treelet and fused-upper kernels reserve 64 bytes per live node instead of 32 bytes.
- Added a treelet-aware opening kernel that extracts the lower sibling path from the selected subtree using the same ping-pong reduction discipline.
- Made automatic subtree selection conservative after refreshed Apple M4 / Apple9 smoke data: near-rate 135- and 136-byte SHA3 leaves can select 64-leaf treelets; shorter leaves require explicit fixed mode or planner tuning records.

Residual risk:

- Ping-pong scratch doubles threadgroup memory use and changes the benchmark profile. More devices and tree sizes need measured plan records before promoting additional automatic treelet shapes.

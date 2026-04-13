# Security Model

AppleZKProver is not production proving software yet. It is a GPU-accelerated cryptographic proving backend under active development. The security model below defines the bar that future code must meet before the project claims production-grade proof security.

## Assets

- private witness bytes uploaded to GPU buffers,
- intermediate hash states,
- Merkle leaves and internal nodes,
- future field/codeword buffers,
- future transcript challenges,
- final commitments, openings, and proofs.

## Attacker Model

The primary attacker can:

- supply malformed public inputs,
- request unusually shaped workloads,
- observe public outputs and timings,
- run verifier code on untrusted proof bytes,
- trigger repeated prover executions on the same machine.

The current model does not defend against:

- a compromised operating system,
- a malicious kernel driver,
- physical access to GPU memory,
- same-machine privileged inspection,
- fault injection,
- side-channel attacks from hostile co-tenants on the same device.

Those exclusions must be revisited before any production deployment claim.

## Trust Boundaries

- CPU API boundary: untrusted callers provide byte arrays, counts, lengths, and strides.
- GPU command boundary: Swift encoders pass trusted buffer layouts to Metal kernels.
- CPU oracle boundary: CPU reference code is the correctness source for tests, not an optimized prover path.
- Verifier boundary: verifier code must never trust prover-generated metadata without checking it.

## Current Guarantees

The current package aims to guarantee:

- SHA3-256 CPU oracle matches known test vectors,
- Keccak-256 CPU oracle matches known test vectors and is domain-separated from SHA3-256,
- GPU SHA3 one-block output matches the CPU oracle for tested inputs,
- GPU Keccak-256 one-block output matches the CPU oracle for tested inputs,
- GPU Merkle roots match CPU Merkle roots for tested layouts,
- invalid non-power-of-two Merkle leaf counts are rejected,
- fixed-rate GPU SHA3 rejects inputs longer than 136 bytes,
- CPU Merkle oracle layout failures and one-block hash length failures return typed errors instead of process traps,
- zero-length one-block messages are handled as valid SHA3 input,
- CPU and GPU transcript squeeze paths consume the full SHA3-256 rate, advance through additional squeeze blocks with Keccak-F1600, and use rejection sampling for field reduction,
- the M31 sum-check chunk transcript uses versioned header, round, and challenge frames with stable CPU vectors and GPU differential coverage,
- reusable hash and Merkle plans expose explicit buffer clearing methods.

These are correctness guarantees for the implemented slice. They are not a full proof-system security claim.

## Required Cryptographic Rules

All future protocol code must follow these rules:

- every hash use must have an explicit domain tag,
- SHA3-256 and Keccak-256 must never be treated as interchangeable because their padding domains differ,
- leaf hash, parent hash, transcript hash, challenge derivation, and proof serialization must use distinct domains,
- Fiat-Shamir transcripts must absorb all public commitments and protocol parameters in a deterministic order,
- verifier code must recompute challenges independently,
- proof formats must version all cryptographic choices,
- malformed proof inputs must fail closed,
- CPU verifier code must not depend on GPU execution.

## GPU Memory Rules

GPU buffers can contain private witness data. Runtime code must therefore make buffer lifetime and clearing explicit.

Required rules:

- public APIs must document whether each input is public, private, or derived,
- reusable plans and future arenas must support clearing private regions before reuse,
- benchmarks must not log witness-derived buffers,
- only final public commitments and requested openings should be copied back by default,
- debug paths that read intermediate buffers must be opt-in and clearly marked.

## Timing And Side-Channel Rules

The current SHA3/Merkle kernels operate on public lengths and regular memory layouts. Future private-witness code must avoid:

- secret-dependent branch divergence,
- secret-dependent memory addressing,
- secret-dependent command topology,
- logging or serializing private intermediate data.

When avoiding those patterns is impossible, the API must document the leakage and the code must not be used for private-witness production proving.

## Input Validation Rules

Every GPU-facing API must validate:

- count bounds,
- stride and length consistency,
- power-of-two requirements where applicable,
- maximum one-block hash length,
- output stride requirements,
- integer multiplication overflow before buffer sizing.

Malformed inputs must return typed errors rather than trapping in library code.

## Review Gates

Before this project claims production security:

- all proof verifiers must be CPU-only and deterministic,
- fuzzing must cover public deserialization and verifier inputs,
- GPU/CPU differential tests must run over randomized workloads,
- cryptographic parameter choices must be documented,
- an external cryptography review must be completed.

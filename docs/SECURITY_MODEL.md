# Security Model

AppleZKProver is not production proving software yet. It is a GPU-accelerated cryptographic proving backend under active development. The security model below defines the bar that future code must meet before the project claims production-grade proof security.

## Assets

- private witness bytes uploaded to GPU buffers,
- intermediate hash states,
- Merkle leaves and internal nodes,
- future field/codeword buffers,
- future transcript challenges,
- final commitments, openings, and proofs.
- public PCS statements and verifier decisions.

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
- GPU threadgroup Merkle treelets and fused upper reductions use disjoint ping-pong scratch spans for child reads and parent writes,
- CPU Merkle opening verification recomputes the SHA3 leaf hash and all parent hashes from the supplied bottom-up sibling path,
- GPU Merkle opening extraction for raw SHA3 leaves matches the independent CPU opening oracle for tested layouts,
- invalid non-power-of-two Merkle leaf counts are rejected,
- fixed-rate GPU SHA3 rejects inputs longer than 136 bytes,
- CPU Merkle oracle layout failures and one-block hash length failures return typed errors instead of process traps,
- zero-length one-block messages are handled as valid SHA3 input,
- CPU and GPU transcript squeeze paths consume the full SHA3-256 rate, advance through additional squeeze blocks with Keccak-F1600, and use rejection sampling for field reduction,
- M31 vector add, subtract, negate, multiply, square, and inverse plans match the independent CPU oracle for tested canonical inputs and edge values, with public inverse inputs required to be nonzero,
- M31 dot-product plans match the independent CPU oracle for tested canonical inputs, edge values, and non-power-of-two vector lengths,
- the M31 sum-check chunk transcript uses versioned header, round, and challenge frames with stable CPU vectors and GPU differential coverage,
- QM31 FRI fold-chain transcript modes use versioned, domain-separated frames and rejection-sampled secure-field challenge limbs,
- the Merkle-bound QM31 FRI chain mode commits each current resident QM31 layer before deriving that layer's fold challenge and verifies generated roots against an independent CPU oracle in the public checked path,
- the linear QM31 FRI proof format uses versioned serialization, binds commitments and final values into query sampling, verifies every queried Merkle decommitment, and checks fold consistency with a CPU-only verifier,
- the resident Circle PCS/FRI proof emitter returns canonical proof bytes from an already-resident evaluation/codeword buffer, keeps the materialized committed-layer log private, and `proveVerified` decodes those bytes before checking them with the independent CPU verifier,
- the Circle FFT codeword plan validates canonical bounded `P(x) + yQ(x)` coefficients, rejects overlapping coefficient/output resident ranges, writes codewords into resident buffers with FFT stages, and is checked against a direct CPU Circle-domain oracle before feeding the resident proof emitter in the verified path,
- the composed Circle coefficient-to-proof plan accepts Circle FFT-basis coefficient buffers, keeps the generated codeword and intermediate FRI layers private, and reads back only public proof material: commitments, final layer, queried leaves, sibling paths, and encoded proof bytes,
- `CirclePCSFRIParameterSetV1.conservative128` fixes the V1 Circle PCS/FRI verifier profile at `logBlowupFactor = 4`, `queryCount = 36`, `foldingStep = 1`, and `grindingBits = 0`; lower-level V1 proof and transcript surfaces support verifier-checked nonzero grinding through an 8-byte nonce, but the conservative public profile claims no grinding credit,
- `CirclePCSFRIArtifactManifestV1.current` records the implemented PCS slice and explicitly marks witness/AIR, sumcheck/GKR artifact integration, resident witness-to-Circle-FFT-basis production, and fused/tiled codeword-to-commitment scheduling as unsupported,
- `CirclePCSFRIContractVerifierV1` is the public CPU-only verifier contract for the implemented Circle PCS/FRI slice. It enforces the profile, canonical domain, exact round count, terminal constant final layer, combined coefficient budget, transcript binding, Merkle openings, structured polynomial claims, and claimed first-layer evaluation openings,
- the checked-in Circle PCS/FRI corpus pins canonical accepted proof bytes, expected proof digests, and tamper/rejection vectors for the strict contract,
- Keccak-F1600 permutation-only batch plans are differentially tested against the CPU permutation oracle for scalar and opt-in simdgroup kernels,
- reusable hash, Keccak-F permutation, Merkle, M31 vector, and M31 sum-check plans expose explicit buffer clearing methods; Merkle and M31 clearing includes shared upload ring slots and private scratch buffers,
- shared upload ring copies clear unused slot tails before reuse, and strided GPU result buffers clear unwritten padding before returning `Data`,
- verified accelerator APIs are available for fixed-rate SHA3/Keccak hashes, Keccak-F1600 permutation batches, raw-leaf Merkle commitments, raw-leaf Merkle openings, planned Merkle commitments, M31 vector arithmetic, M31 dot products, M31 sum-check chunks, QM31 vector arithmetic, QM31 FRI folds, QM31 FRI fold chains, Circle codeword generation, and resident Circle PCS/FRI proof emission,
- the M31 GPU fold path uses the `2^31 - 1` Mersenne reduction instead of generic integer remainder for canonical M31 values.

These are correctness guarantees for the implemented slice. They are not a full proof-system security claim.

## Malicious Accelerator Handling

The GPU is not a cryptographic verifier. A production verifier must be CPU-only and deterministic. When a caller does not trust accelerator execution, it must use the verified APIs so the CPU oracle independently recomputes the GPU result before accepting it.

The verified APIs defend against incorrect accelerator results for CPU-visible inputs. They do not defend against a compromised OS, malicious kernel driver, or a caller that supplies only GPU-resident private buffers without a CPU copy or independently known expected result.

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
- reusable plans and arenas must support clearing private regions before reuse, including shared upload ring slots,
- shared upload staging must clear stale tail bytes when a shorter copy reuses a larger slot,
- result buffers with public strides must clear unwritten padding before returning host-visible bytes,
- benchmarks must not log witness-derived buffers,
- only final public commitments and requested openings should be copied back by default,
- debug paths that read intermediate buffers must be opt-in and clearly marked.

## Timing And Side-Channel Rules

The current SHA3/Merkle kernels operate on public lengths and regular memory layouts. Future private-witness code must avoid:

- secret-dependent branch divergence,
- secret-dependent memory addressing,
- secret-dependent command topology,
- logging or serializing private intermediate data.

The M31 sum-check and dot-product uploaded-buffer APIs assume canonical field elements already reside in the buffer. They intentionally do not modulo-reduce uploaded values in the GPU path; callers that need CPU-side input validation must use the public array API. M31 vector inversion rejects zero through the public array API before dispatch because zero has no field inverse.

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
- Circle witness/AIR/sumcheck/GKR outputs must be integrated into the same proof artifact before any full proof-system claim,
- lattice-based parameter choices, if added later, must include an independent lattice-estimator reproduction artifact,
- an external cryptography review must be completed.

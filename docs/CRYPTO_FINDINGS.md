# Cryptographic Engineering Findings

This log records security-relevant implementation findings and the work completed to close them. It is not a production security audit.

## 2026-04-14: QM31 FRI Proof Benchmark Gate And Resident Circle Coefficients

Findings:

- The linear QM31 FRI proof/decommitment surface had deterministic serialization and an independent verifier, but no benchmark mode that exercised the complete proof artifact lifecycle. That made proof-size, query-opening count, strict decode cost, and verifier cost invisible to the measurement discipline.
- The Circle codeword prover benchmark used public polynomial convenience calls in timed regions. Those calls allocate and upload coefficient buffers even though the direct evaluator already supports caller-owned resident coefficient buffers, so the timed rows included avoidable host allocation work.

Work completed:

- Added `zkmetal-bench --qm31-fri-proof`, which builds the current linear radix-2 QM31 FRI proof, serializes it with deterministic sorted-key JSON, deserializes it through the strict decoder, verifies it with `QM31FRIProofVerifier`, and reports proof size, query-opening count, final-layer/proof digests, verifier acceptance, and CPU match status.
- Added `CircleCodewordPCSFRIProverV1.proveResidentCoefficients`, which composes resident coefficient buffers, resident Circle codeword generation, and resident PCS/FRI proof emission without allocating coefficient buffers in the timed path.
- Added `CircleCodewordPCSFRIProverV1.proveResidentCoefficientsVerified`, which keeps the same CPU oracle and independent verifier gate for callers that still have the polynomial on the CPU.
- Extended the Circle domain test flow to cover resident coefficient-buffer codeword generation and resident coefficient-buffer proof emission against the CPU proof builder/verifier.

Residual risk:

- `--qm31-fri-proof` benchmarks the CPU proof artifact for the current linear radix-2 layout. It is not a GPU proof emitter, not a Circle-domain proof benchmark, and not a production soundness-parameter claim.
- The QM31 proof format remains deterministic developer JSON. A compact binary format should be specified before treating it as a wire-format commitment.
- Resident coefficient-buffer execution assumes the caller has already produced canonical QM31 coefficient limbs. The verified convenience method checks the resulting proof against a CPU polynomial oracle, but the resident-only path intentionally avoids reading private buffers back for canonicality checks.
- The Circle codeword prover remains a direct `P(x) + yQ(x)` evaluator, not an optimized Circle FFT or full committed-polynomial PCS verifier.

## 2026-04-13: Linear QM31 FRI Query Proof Format And Verifier

Finding:

- The Merkle-bound QM31 FRI chain now generated roots from each folded layer before deriving challenges, but it still had no verifier-facing proof object. A caller could benchmark or CPU-check the folded roots, but there was no serialized artifact containing sampled query positions, Merkle decommitments, folded-value consistency checks, or a deterministic verifier contract.

Work completed:

- Added `QM31FRIProof`, `QM31FRIQueryProof`, and `QM31FRILayerQueryProof` as versioned `Codable` proof types. `QM31FRIProof.serialized()` emits deterministic sorted-key JSON, and `QM31FRIProof.deserialize(_:)` fails closed with the package's typed layout error for malformed input.
- Added `QM31FRIProofBuilder.prove`, which commits every current QM31 radix-2 layer as 16-byte little-endian SHA3 Merkle leaves, replays the domain-separated fold-chain transcript, absorbs the serialized final layer, samples query pair indices from the Fiat-Shamir state, and extracts left/right Merkle openings along the queried fold path.
- Added `QM31FRIProofVerifier.verify`, an independent CPU verifier that re-derives fold challenges and query indices from the proof transcript, verifies every Merkle opening against the committed roots, decodes canonical QM31 leaves, checks each folded value appears in the next opened layer, and checks the last folded value against the serialized final layer.
- Made QM31/CM31 field elements and `MerkleOpeningProof` codable so proof objects can be serialized without ad hoc byte munging.
- Added regression coverage for deterministic serialization/deserialization, successful proof verification, final-layer tamper rejection, Merkle leaf tamper rejection, malformed proof shape rejection, and malformed JSON rejection.

Residual risk:

- This is a linear radix-2 QM31 FRI proof format for the layer order consumed by the current fold scheduler. It is not a Circle-domain FRI/PCS proof: Circle twiddle generation, coset/bit-reversal layout, and Circle-specific query mapping remain open protocol work.
- The verifier takes inverse-domain layers as public verifier parameters. A full PCS format still needs a stable domain descriptor that commits to those parameters and to the codeword layout.
- Query count is caller-selected, and this change does not claim a production soundness parameter set. It establishes the typed proof/decommitment surface that future protocol configurations can bind.
- The proof format uses JSON for deterministic developer-facing serialization. A compact binary PCS format remains future work once the Circle-domain layout is fixed.

References:

- S-two Book, FRI prover commitment flow, where each inner layer is folded, committed, and appended to the Fiat-Shamir channel: https://docs.starknet.io/learn/S-two-book/how-it-works/circle-fri/fri_prover
- S-two Book, FRI verifier flow, where commitments are mixed before folding randomness and query positions are sampled afterward: https://docs.starknet.io/learn/S-two-book/how-it-works/circle-fri/fri_verifier
- Stwo core FRI verifier/config source, including secure-field challenges, query count configuration, and fold-step structure: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fri.rs

## 2026-04-13: Merkle-Bound QM31 FRI Fold Chain Roots

Finding:

- The transcript-derived QM31 FRI chain bound challenges to 32-byte commitment roots, but those roots were supplied by the caller. That still left a protocol composition gap: the implementation did not prove that the absorbed roots were produced from the resident evaluation layer being folded in that round.

Work completed:

- Added `QM31FRIMerkleFoldChainOracle`, an independent CPU oracle that serializes each current QM31 layer as 16-byte little-endian raw SHA3 Merkle leaves, commits that layer, absorbs the resulting root into the same domain-separated fold-chain transcript, derives the QM31 challenge, and then folds to the next layer.
- Exposed an internal `SHA3RawLeavesMerkleCommitPlan.encodeCommitmentRoot` encoder so higher-level command plans can write Merkle roots into caller-owned GPU buffers inside an existing command buffer instead of forcing a standalone Merkle command submission.
- Extended `QM31FRIFoldChainPlan` with `executeMerkleTranscriptDerived`, `executeMerkleTranscriptDerivedVerified`, and `executeMerkleTranscriptDerivedResident`. The resident path commits the current layer buffer, absorbs the generated root, squeezes the challenge on GPU, folds into the next resident layer, and repeats. The public verified path checks final values, commitments, and challenges against the CPU oracle.
- Added resident commitment-root output for the Merkle-bound path, so verifier-facing proof construction can consume the generated roots without trusting detached caller-supplied commitment bytes.
- Added CPU and GPU tests for current-layer root binding, root/challenge mutation sensitivity, padded resident root output, malformed layouts, and alias rejection. Added `zkmetal-bench --qm31-fri-fold-chain-merkle` with `challengeMode: "merkle-transcript"` and CPU verification that checks both final folded values and generated roots.

Residual risk:

- The Merkle-bound mode commits the linearly ordered QM31 layer buffers that the current radix-2 fold scheduler consumes. It is not yet a full Circle-domain layout: Circle FFT twiddles, bit-reversal/coset ordering, and domain-specific query mapping remain separate work.
- A linear verifier-facing proof format now samples query positions, extracts Merkle decommitments, serializes proof data, and verifies fold consistency independently. Circle-domain query mapping and a full PCS proof remain separate work.
- The resident path assumes the input and inverse-domain buffers are canonical and protocol-correct by construction. Public array APIs still CPU-check canonicality; private composition must preserve those invariants before this becomes a production proof system.

References:

- S-two Book, FRI prover commitment flow, where each inner layer is folded, committed, and appended to the Fiat-Shamir channel: https://docs.starknet.io/learn/S-two-book/how-it-works/circle-fri/fri_prover
- S-two Book, FRI verifier flow, where roots are mixed before folding randomness and query positions are sampled afterward: https://docs.starknet.io/learn/S-two-book/how-it-works/circle-fri/fri_verifier
- Stwo core FRI verifier/config source, including secure-field challenges and fold-step structure: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fri.rs

## 2026-04-13: Transcript-Derived QM31 FRI Chain Challenges

Finding:

- The chained QM31 FRI fold executor accepted caller-supplied challenges. That was useful for resident composition, but in a FRI protocol each folded-layer commitment must be mixed into the Fiat-Shamir transcript before deriving the next secure-field challenge. Leaving challenge arrays as host material was a composition risk and did not prove that transcript squeeze output could feed the fold kernel without CPU materialization.

Work completed:

- Added `QM31FRIFoldTranscriptOracle`, an independent CPU oracle with a domain-separated framing contract for the QM31 FRI fold chain. The transcript absorbs a versioned header, per-round metadata, the caller-provided 32-byte round commitment root, and a per-round challenge request before squeezing four M31 limbs into one canonical QM31 challenge by rejection sampling.
- Extended `QM31FRIFoldChainPlan` with transcript frame uploads, a commitment-root upload ring, private transcript state, challenge scratch/log buffers, and public `executeTranscriptDerived` / `executeTranscriptDerivedVerified` APIs.
- Added a resident transcript-derived execution path that accepts caller-owned evaluation, inverse-domain, commitment-root, and output buffers. Each round absorbs the current commitment root, squeezes the QM31 challenge on GPU, and passes the challenge buffer directly into the fold kernel before moving to the next layer.
- Added the `qm31_fri_fold_challenge_buffer` Metal kernel so folded layers can consume transcript-derived resident challenge words instead of CPU-supplied challenge structs.
- Added CPU/GPU differential tests covering transcript challenge derivation, commitment mutation sensitivity, malformed roots, resident padded commitment strides, final-output correctness, and alias rejection. Added `zkmetal-bench --qm31-fri-fold-chain-transcript` with JSON reporting that records `challengeMode: "transcript"`.

Residual risk:

- A Merkle-bound mode now builds roots from the resident folded buffers before deriving challenges. The detached-root transcript mode remains useful for integration with an external commitment system, but callers must not treat detached roots as proof that the current buffer was committed unless the higher-level protocol enforces that binding.
- Linear query sampling, decommitment extraction, proof serialization, and an independent verifier now exist for the QM31 radix-2 FRI proof surface. Circle-domain twiddle/layout generation and full PCS binding remain separate protocol work.
- The resident path assumes evaluation, inverse-domain, and commitment-root buffers are protocol-correct and canonical by construction. Public APIs retain CPU oracle checks; private-buffer protocol composition must enforce those invariants at the layer that constructs the roots and layouts.

References:

- S-two Book, FRI verifier flow, where layer commitments are mixed into the channel before drawing secure-field folding randomness: https://docs.starknet.io/learn/S-two-book/how-it-works/circle-fri/fri_verifier
- Stwo core FRI verifier/config source, including secure-field challenges and fold-step structure: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fri.rs
- Stwo CPU FRI folding source, using inverse butterflies and `f0 + alpha * f1` for line and circle-to-line folds: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/prover/backend/cpu/fri.rs

## 2026-04-13: QM31 Multi-Round Resident FRI Fold Chain

Finding:

- The single-layer QM31 FRI fold primitive removed one CPU round-trip, but a real FRI reduction performs repeated folds. Without a chained resident plan, higher-level code would still need to resubmit and synchronize each intermediate layer from the host, or each caller would need to hand-roll scratch-buffer choreography around the field kernel.

Work completed:

- Added `QM31FRIFoldRound` and `QM31FRIFoldChainOracle`, an independent CPU oracle that applies the audited single-layer fold formula repeatedly and preserves the same canonicality, even-input, nonzero inverse-domain, and challenge validation rules.
- Added `QM31FRIFoldChainPlan`, a reusable Metal plan that accepts an input layer size and round count, precomputes every output-layer size and inverse-domain offset, allocates private scratch for intermediate layers, and encodes every fold round into a single command buffer.
- Added a resident `executeResident` API that consumes caller-owned evaluation and concatenated inverse-domain buffers plus per-round QM31 challenges, rejects final-output aliasing with the full input and inverse-domain ranges, and writes only the final folded layer to the caller output buffer. Intermediate layers never leave the private residency arena.
- Added CPU-verified public execution, explicit reusable-buffer clearing, checked sizing for chained inverse-domain buffers, CLI validation for `--fri-fold-rounds`, and benchmark reporting via `zkmetal-bench --qm31-fri-fold-chain`.
- Added deterministic tests for CPU chain equivalence to repeated single-layer folds, malformed round layouts, zero inverse-domain points, noncanonical challenges, GPU/CPU equality, plan reuse after clearing, resident hot-path execution, invalid resident buffer sizes, challenge-count mismatch, and output/input alias rejection.

Residual risk:

- The explicit-challenge chain remains a fold executor for caller-supplied per-round inverse-domain points and Fiat-Shamir challenges. A separate transcript-derived challenge mode now absorbs caller-supplied commitment roots and derives challenges on GPU, but the project still does not compute Circle-domain twiddles, commit folded layers into Merkle trees inside the same plan, choose/query positions, or emit a verifier-facing FRI/PCS proof.
- Resident buffers are treated as already canonical. The public array path validates canonical QM31 limbs and nonzero inverse-domain points; the resident path intentionally avoids CPU readback, so protocol layers using private buffers must maintain those invariants by construction.
- The scratch schedule is linear radix-2 folding over adjacent pairs. Any Circle FFT bit-reversal, coset ordering, or batched codeword layout policy must be introduced as a separately tested layer before this is used in a complete prover.

References:

- Stwo CPU FRI folding source, using inverse butterflies and `f0 + alpha * f1` for line and circle-to-line folds: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/prover/backend/cpu/fri.rs
- Stwo core FRI verifier/config source, including secure-field challenges and fold-step structure: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fri.rs
- Stwo QM31 source, defining `SECURE_EXTENSION_DEGREE = 2`, `R = 2 + i`, and `CM31[x] / (x^2 - R)`: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fields/qm31.rs

## 2026-04-13: QM31 Resident FRI Fold Composition Primitive

Finding:

- The QM31 field lane closed the secure-field arithmetic gap, but the next trust boundary was composition: higher-level codeword/FRI work still needed a way to consume resident QM31 buffers and write the next layer without forcing CPU readback. Without a verified fold primitive, FRI/PCS integration would either copy intermediate layers to the host or duplicate unaudited field formulas inside future command plans.

Work completed:

- Added `QM31FRIFoldOracle`, an independent CPU oracle for one radix-2 FRI fold layer over QM31. The oracle validates canonical limbs, requires an even non-empty input, rejects zero inverse-domain points, and computes `(f(x) + f(-x))/2 + alpha * (f(x) - f(-x)) * inv(point) / 2` for each adjacent pair.
- Added `QM31FRIFoldPlan`, a reusable Metal command plan backed by a private `ResidencyArena`, ring-buffered staging for public array execution, and a caller-owned resident execution path. `executeVerified` compares GPU output against the CPU oracle; `executeResident` accepts caller `MTLBuffer` inputs and writes a caller `MTLBuffer` output while returning only timing stats.
- Added the `qm31_fri_fold` Metal kernel. It reuses the existing QM31 add/subtract/multiply primitives and multiplies by `1/2 = 1073741824 mod 2^31 - 1`.
- Added deterministic regression coverage for the closed-form pair `(1,2,3,4),(4,5,6,7)` with scalar challenge `2`, identical-pair folding, malformed canonical limbs, odd/mismatched layouts, zero inverse-domain rejection, GPU/CPU equality, plan clear/reuse, and the no-readback resident-buffer path.
- Added `zkmetal-bench --qm31-fri-fold`, with schema v1 JSON/text output, CPU digest verification, folded-elements/sec, and input bandwidth reporting. The timed benchmark path uses `executeResident`, so it measures the composition API rather than the public convenience array/readback path.

Residual risk:

- This is one radix-2 fold layer. A separate chained command plan now composes repeated radix-2 folds, but the project still does not implement a complete Circle FFT, transcript-bound FRI protocol, PCS commitment scheme, query/decommitment flow, or verifier-facing proof format.
- `executeResident` assumes the caller already owns canonical QM31 buffers and supplies inverse-domain points in the exact pair order expected by the surrounding domain layout. It rejects output ranges that overlap either input range, but it does not validate canonical limbs inside resident buffers. Callers that cannot prove those invariants must use the public array API or an independent CPU witness during integration.
- The primitive currently accepts precomputed inverse-domain points. A full Circle FFT/FRI composition plan still needs audited domain/twiddle generation, bit-reversal policy, transcript framing, Merkle commitment chaining, and query opening integration.

References:

- Stwo CPU FRI folding source, using inverse butterflies and `f0 + alpha * f1` for line and circle-to-line folds: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/prover/backend/cpu/fri.rs
- Stwo core FRI verifier/config source, including secure-field challenges and fold-step structure: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fri.rs
- Stwo QM31 source, defining `SECURE_EXTENSION_DEGREE = 2`, `R = 2 + i`, and `CM31[x] / (x^2 - R)`: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fields/qm31.rs

## 2026-04-13: QM31 Quartic Secure-Field Primitive

Finding:

- CM31 closed the first quadratic extension-field gap, but Stwo/Circle-STARK verifier-facing challenge arithmetic uses the quartic secure field QM31. Without a first-class QM31 oracle and GPU lane, future Circle FFT, FRI, PCS, and verifier transcript work would either fall back to CPU code or risk implementing incompatible ad hoc field formulas.

Work completed:

- Added `QM31Element` and `QM31Field` for `CM31[u] / (u^2 - 2 - i)`, represented as `(a + bi) + (c + di)u`. The CPU oracle validates canonical M31 limbs and implements add, subtract, negate, multiply, square, inverse, and prefix/suffix batch inversion.
- Added `CM31Field.inverse(_:)` because QM31 inversion reduces through a CM31 denominator.
- Added `QM31VectorOperation` and `QM31VectorArithmeticPlan`, a reusable Metal plan for interleaved four-limb QM31 vectors. The public array path validates canonical input and rejects zero for inversion; `executeUploadedVectors` provides the first resident-buffer hot path for QM31 composition when a caller already owns canonical GPU buffers.
- Added a Metal `qm31_vector_arithmetic` kernel covering add, subtract, negate, multiply, square, and inverse. Multiplication follows the Stwo field model with nonresidue `2 + i`; inversion uses `(A - Bu) / (A^2 - (2+i)B^2)`.
- Added deterministic regression coverage using Stwo-style edge vectors, including `(1,2,3,4) * (4,5,6,7) = (-71,93,-16,50)`, inverse identity checks, batch inversion checks, malformed canonical limbs, zero-inverse rejection, GPU/CPU equality for every QM31 vector operation, explicit clear/reuse, and uploaded-buffer execution.
- Added `zkmetal-bench --qm31-multiply` and `zkmetal-bench --qm31-inverse`, with schema v1 JSON/text output, CPU digest verification, QM31 elements/sec, and input bandwidth reporting.

Residual risk:

- This is a standalone secure-field primitive plus uploaded-vector hot path. A separate resident radix-2 FRI fold primitive now exists, but the project still does not implement Circle FFT, a full multi-round FRI protocol, PCS commitment composition, query/decommitment flow, or verifier-facing proof serialization.
- The GPU inverse path is per-lane. Future FRI/PCS code should compare it against a resident batch-inversion scan once denominator layout and batching are fixed.
- Uploaded-buffer execution assumes canonical QM31 limbs. Callers that cannot prove canonicality must use the public array API or carry an independent CPU witness for verification.

References:

- Stwo QM31 source, defining `SECURE_EXTENSION_DEGREE = 2`, `R = 2 + i`, and `CM31[x] / (x^2 - R)`: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fields/qm31.rs
- Stwo CM31 source, defining `M31[x] / (x^2 + 1)`: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fields/cm31.rs
- Stwo Book, "Mersenne Primes", sections on M31, CM31, and QM31: https://zksecurity.github.io/stwo-book/how-it-works/mersenne-prime.html

## 2026-04-13: CM31 Extension Field Multiplication Primitive

Finding:

- The Phase 3 field-lane roadmap required extension-field multiplication, but the implemented reusable vector surface stopped at base M31 arithmetic. Circle-STARK/Stwo-style paths need the quadratic extension CM31 before Circle FFT, secure challenge packing, and later quartic-field work can be represented without falling back to ad hoc CPU code.

Work completed:

- Added `CM31Element` and `CM31Field`, an independent CPU oracle for `M31[X]/(X^2 + 1)` with canonical validation, componentwise add/subtract/negate, direct-form multiplication, and squaring.
- Added `CM31VectorOperation` and `CM31VectorArithmeticPlan`, a reusable Metal plan for interleaved `real, imaginary` CM31 vectors. The public path validates canonical CM31 elements, copies through ring-buffered shared staging, keeps resident private buffers in a `ResidencyArena`, reads back only the output vector, and exposes `executeVerified` for CPU/GPU equality checks.
- Added a Metal `cm31_vector_arithmetic` kernel. Multiplication uses the three-base-multiply Karatsuba form for `i^2 = -1`; the CPU oracle intentionally uses the direct four-product formula for differential independence.
- Added deterministic CPU regression coverage for edge values `0`, `1`, `i`, `-1`, and `-1 - i`, malformed canonical limbs, binary/unary layout errors, GPU/CPU equality for every CM31 vector operation, and clear/reuse behavior.
- Added `zkmetal-bench --cm31-multiply`, with schema v1 JSON/text output, CPU digest verification, CM31 elements/sec, and input bandwidth reporting.

Residual risk:

- This is a quadratic CM31 lane, not the full QM31 secure-field stack. The next extension step should build quartic multiplication over CM31 with independent test vectors before using extension challenges in a verifier-facing proof format.
- The reusable plan is an uploaded-vector/readback primitive. It does not yet compose CM31 buffers directly into Circle FFT, FRI fold, PCS, or sum-check command plans.

Reference:

- Stwo Book, "Mersenne Primes", sections on M31, CM31, and QM31: https://zksecurity.github.io/stwo-book/how-it-works/mersenne-prime.html

## 2026-04-13: M31 Vector Inversion Primitive

Finding:

- The M31 field-lane roadmap had elementwise arithmetic and dot products, but no inverse primitive. Inversion is required by FRI/PCS denominators, normalization steps, and future batch evaluation code.

Work completed:

- Added `M31Field.inverse(_:)` and `M31Field.batchInverse(_:)`. The batch oracle uses the standard prefix/suffix product method so a nonzero vector is inverted with one field inversion plus linear-time multiplications.
- Added `.inverse` to `M31VectorOperation` and wired the reusable Metal vector arithmetic plan to compute one inverse per nonzero lane using a fixed Fermat exponentiation schedule over the M31 prime field.
- Public vector execution rejects zero and non-canonical values before dispatch. The GPU path remains a canonical-field hot path and does not mask malformed field inputs.
- Added deterministic regression coverage for exact edge inverses of `1`, `2`, `3`, `p - 2`, and `p - 1`, zero rejection, non-canonical rejection, CPU batch-oracle equality, GPU/CPU equality, and plan clear/reuse coverage through the existing vector arithmetic test matrix.
- Added `zkmetal-bench --m31-inverse`, with schema v1 JSON/text output, CPU digest verification, elements/sec, input bandwidth, and device capability reporting.

Residual risk:

- The first GPU path uses per-lane Fermat exponentiation, not a parallel prefix/suffix batch-inversion kernel. It is correct and benchmarked, but future PCS workloads should compare it against a true resident batch-inversion scan once the surrounding codeword layout is fixed.
- The vector inverse public API rejects zero. Protocol layers that need zero-preserving inversion masks must implement and verify that policy explicitly instead of relying on this primitive.

## 2026-04-13: M31 Dot-Product Reduction Primitive

Finding:

- The M31 field-lane roadmap had elementwise vector operations, but it still lacked a reusable dot-product/reduction primitive. Dot products are a core building block for multilinear evaluations, sum-check reductions, PCS work, and codeword pipelines.

Work completed:

- Added `M31Field.dotProduct(lhs:rhs:)`, an independent CPU oracle that validates canonical inputs and accumulates products through the M31 add/multiply operations.
- Added `M31DotProductPlan`, a reusable Metal plan that uploads two vectors, computes per-threadgroup dot-product partials, ping-pongs resident partial reductions, and reads back only the final canonical field element.
- Added `executeVerified`, which compares the GPU result against the CPU oracle before accepting it, plus `executeUploadedVectors` for future GPU-resident composition when the caller already owns canonical private buffers.
- Added explicit reusable-buffer clearing for upload rings, partial buffers, private vector storage, and the one-word readback buffer.
- Added deterministic regression coverage for edge values around `0`, `1`, `p - 2`, and `p - 1`, non-power-of-two vector lengths, uploaded-buffer execution, invalid layouts, and CPU/GPU equality.
- Added `zkmetal-bench --m31-dot-product`, with JSON/text output, CPU verification gating, elements/sec, input bandwidth, threadgroup geometry, and device capability reporting.

Residual risk:

- The initial GPU reduction is a scalar threadgroup-reduction path. It is correct and measured, but it is not yet a simdgroup-specialized or Apple9-atomic accumulation variant.
- Uploaded-buffer execution assumes the buffer already contains canonical M31 elements. Callers that need canonicality checks must use the public array API or keep an independent CPU copy for verification.

## 2026-04-13: M31 Vector Arithmetic Foundation

Finding:

- The sum-check chunk used M31 arithmetic internally, but the field lane roadmap still lacked a first-class reusable vector arithmetic surface with explicit CPU oracle coverage.

Work completed:

- Added canonical M31 CPU oracle operations for add, subtract, negate, multiply, and square using the `2^31 - 1` Mersenne reduction.
- Added `M31VectorArithmeticPlan`, a reusable Metal plan for vector add, subtract, negate, multiply, and square over canonical M31 elements.
- Public array execution validates canonical input before dispatch; `executeVerified` compares the GPU output against the CPU oracle before accepting it.
- Regression coverage now checks edge values around `0`, `1`, `p - 2`, and `p - 1`, non-power-of-two vector lengths, invalid canonical layouts, explicit clear/reuse, and CPU/GPU equality for every implemented operation.

Residual risk:

- This is a standalone field-lane primitive. It does not yet compose field vectors directly into FRI/codeword or PCS command plans, and it does not claim constant-time behavior against a hostile GPU driver or physical observer.

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

Follow-up:

- The later combined treelet root/opening kernel removed the duplicate target-treelet hash while keeping the same CPU opening oracle gate.

## 2026-04-13: Race-Free Merkle Treelets

Finding:

- The threadgroup-local Merkle treelet and fused-upper kernels compacted parent nodes into the same scratch span that sibling threads could still be reading as child input. CPU/GPU tests passed on the benchmark host, but the layout depended on implicit execution ordering inside a threadgroup and was not an acceptable cryptographic implementation invariant.

Work completed:

- Reworked `sha3_256_merkle_treelet_leaves_specialized` and `sha3_256_merkle_fuse_upper_32` to use two threadgroup scratch halves and swap read/write bases after each level.
- Updated Swift feasibility and dispatch sizing so treelet and fused-upper kernels reserve 64 bytes per live node instead of 32 bytes.
- Added a treelet-aware opening kernel that extracts the lower sibling path from the selected subtree using the same ping-pong reduction discipline. Opening mode now uses a combined variant that writes every selected subtree root and emits the requested lower sibling path during the same treelet reduction.
- Made automatic subtree selection conservative after refreshed Apple M4 / Apple9 smoke data: near-rate 135- and 136-byte SHA3 leaves can select 64-leaf treelets; shorter leaves require explicit fixed mode or planner tuning records.

Residual risk:

- Ping-pong scratch doubles threadgroup memory use and changes the benchmark profile. More devices and tree sizes need measured plan records before promoting additional automatic treelet shapes.

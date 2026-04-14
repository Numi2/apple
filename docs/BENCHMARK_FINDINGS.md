# Benchmark Findings

Date: 2026-04-14

Host used for the smoke run: Apple M4, Apple9 Metal family available.

## Work Completed

- Captured the first checked-in optimized suite baseline:
  `BenchmarkBaselines/apple-m4-apple9-suite-2026-04-13.json`.
- Captured an opt-in simdgroup hash suite baseline:
  `BenchmarkBaselines/apple-m4-apple9-suite-simdgroup-2026-04-13.json`.
- Captured the first checked-in Circle first-fold baseline:
  `BenchmarkBaselines/apple-m4-circle-fri-fold-2026-04-13.json`.
- Captured the first checked-in Circle fold-chain baseline:
  `BenchmarkBaselines/apple-m4-circle-fri-fold-chain-2026-04-14.json`.
- Captured the first checked-in Circle Merkle-transcript fold-chain baseline:
  `BenchmarkBaselines/apple-m4-circle-fri-fold-chain-merkle-2026-04-14.json`.
- Captured the first checked-in Circle codeword prover baseline:
  `BenchmarkBaselines/apple-m4-circle-codeword-prover-2026-04-14.json`.
- Reworked the benchmark CLI argument parser so valid argument parsing does not rely on optimized Swift throwing control flow.
- Reworked the CPU SHA3 block absorber to use direct contiguous byte indexing instead of generic slice traversal, and added a 1024-leaf CPU Merkle regression vector.
- Added the first real Apple7+ simdgroup Keccak-F1600 path, CPU differential tests, and selectable fixed-width SHA3-256 / Keccak-256 batch hash kernels. This path is not used for Merkle or planner candidate selection.
- Batched the simdgroup fixed-hash dispatcher so one threadgroup can carry multiple independent Keccak states, added a validated `--hash-simdgroups-per-threadgroup` benchmark knob, and recorded the effective packing in schema v4 JSON reports.
- Added `zkmetal-bench --suite` so benchmark runs can cover the fixed-rate matrix instead of one leaf size and one standalone hash at a time.
- The default suite matrix is SHA3-256 and Keccak-256 over leaf lengths `0`, `32`, `64`, `128`, `135`, and `136`.
- Suite JSON reports use a top-level suite envelope with the exact matrix configuration and schema v4 per-case `BenchmarkReport` payloads.
- Suite validation rejects any leaf length outside the current fixed-rate SHA3/Keccak GPU contract of `0...136` bytes before Metal work is created.
- Suite allocation checks use the largest selected suite leaf length, so oversized benchmark matrices fail during argument validation instead of reaching buffer construction.
- Text output now has a compact suite summary with each case's target, minimum hash wall time, minimum Merkle wall time, and CPU verification status.
- CPU verification is now a hard benchmark gate: when enabled, any false or missing CPU match emits the report, writes a mismatch summary to stderr, and exits with status `2`.
- Added a dedicated Keccak-F1600 permutation-only benchmark mode for Plonky3-style raw permutation relevance. It emits schema v1 JSON reports separate from the existing hash/Merkle schema v4 reports and verifies the output digest against the CPU permutation oracle.
- Added a dedicated M31 dot-product benchmark mode. It emits schema v1 JSON reports with field-specific elements/sec and input bandwidth, records threadgroup geometry, and verifies the one-word GPU reduction against the CPU M31 oracle.
- Added a dedicated M31 vector inverse benchmark mode. It emits schema v1 JSON reports with field-specific elements/sec and input bandwidth, and verifies the GPU output digest against the CPU M31 batch-inversion oracle.
- Added a dedicated CM31 vector multiplication benchmark mode. It emits schema v1 JSON reports with CM31 elements/sec and input bandwidth, and verifies the GPU output digest against the independent CPU CM31 oracle.
- Added dedicated QM31 vector multiplication and inverse benchmark modes. They emit schema v1 JSON reports with QM31 elements/sec and input bandwidth, and verify GPU output digests against the independent CPU QM31 oracle.
- Added a dedicated QM31 radix-2 FRI fold benchmark mode. It emits schema v1 JSON reports with folded-elements/sec and input bandwidth, verifies the resident fold output digest against the independent CPU FRI fold oracle, and times the no-internal-readback `executeResident` command path.
- Added a dedicated Circle first-fold benchmark mode. It emits schema v1 JSON reports with canonical Circle domain metadata, folded-elements/sec, input bandwidth for evaluation plus public inverse-`y` twiddle reads, verifies the resident output digest against the independent Circle fold oracle, and times the no-internal-readback `CircleFRIFoldPlan.executeResident` command path.
- Added a dedicated Circle FRI fold-chain benchmark mode. It emits schema v1 JSON reports with canonical Circle domain metadata, round count, total inverse-domain elements, final-output elements/sec, and input bandwidth, verifies the resident multi-round output digest against the independent Circle layer oracle, and times the no-intermediate-readback `CircleFRIFoldChainPlan.executeResident` command path.
- Added a Circle V1 Merkle-transcript mode for the same benchmark shape. It emits `challengeMode: "circle-v1-merkle-transcript"`, commits each current Circle/line FRI layer on GPU, absorbs the generated root into the Circle proof V1 transcript before squeezing the round challenge, verifies generated roots, final values, extracted query openings, and full resident proof emission against the independent CPU proof builder/verifier, and times the composed resident commit-root/transcript/fold command path, resident query extraction from materialized FRI layers, and canonical proof emission.
- Added a direct Circle codeword prover benchmark mode. It emits schema v1 JSON for `P(x) + yQ(x)` codeword generation into resident buffers, resident proof emission from that generated codeword buffer, full polynomial-to-proof execution, proof size, codeword/proof digests, and independent CPU verifier acceptance.
- Retimed the Circle codeword prover benchmark through pre-uploaded resident coefficient buffers for the codeword-generation and full-prover rows, and added a resident coefficient-buffer entry point on `CircleCodewordPCSFRIProverV1`. This removes avoidable coefficient-buffer allocation from those timed benchmark regions without changing the CPU proof/verifier gate.
- Added a dedicated chained QM31 radix-2 FRI fold benchmark mode. It emits schema v1 JSON reports with final-output elements/sec and input bandwidth, verifies the resident multi-round output digest against the independent CPU chain oracle, and times one command buffer that keeps intermediate fold layers in private GPU scratch.
- Added a transcript-derived chained QM31 radix-2 FRI fold benchmark mode. It emits the same chain report shape with `challengeMode: "transcript"`, derives per-round QM31 challenges from 32-byte commitment-root frames on GPU, verifies against the independent CPU transcript oracle, and times the resident path where transcript challenge output feeds the fold kernel without CPU challenge materialization.
- Added a Merkle-bound chained QM31 radix-2 FRI fold benchmark mode. It emits `challengeMode: "merkle-transcript"`, commits each current resident QM31 layer as SHA3 raw leaves before deriving the next challenge, verifies generated roots and final values against the independent CPU oracle, and times the composed commit-root/transcript/fold command path.
- Added a verifier-facing linear QM31 FRI proof format with transcript-sampled query decommitments, deterministic serialization, and an independent CPU verifier.
- Added `zkmetal-bench --qm31-fri-proof` for the verifier-facing linear QM31 FRI proof format. It reports proof construction, deterministic serialization, strict deserialization, independent verification, proof size, query-opening count, final-layer/proof digests, verifier acceptance, and a CPU match gate.
- Added a multi-layer CPU Circle FRI proof builder and verifier for the V1 binary artifact. The first round uses Circle inverse-`y` twiddles, later rounds use line-domain inverse-`x` twiddles over checked `x, -x` pairs, and the tests pin both first-fold and three-round proof digests.
- Extended the lower Merkle treelet path from 32-byte leaves to the full fixed-rate SHA3 leaf contract (`0...136` bytes). The new treelet remains a SHA3 Merkle commitment path: standalone Keccak-256 suite rows still use SHA3 for the Merkle root, matching the existing commitment API.
- Added `zkmetal-bench --merkle-opening` for raw-leaf SHA3 opening extraction. It emits a schema v1 opening report with root, proof digest, sibling count, CPU proof match, and opening timing without dumping proof nodes.
- Reworked threadgroup-local Merkle treelet and fused-upper reductions to use ping-pong scratch halves, eliminating the intra-threadgroup read/write overlap that parent compaction could otherwise create.
- Added treelet-aware opening extraction: selected lower treelets now write the requested lower sibling path on GPU, then the upper path is extracted from the resident subtree-root tree.
- Combined the opening-mode lower treelet pass so selected treelets write subtree roots for the upper tree and the target treelet writes its lower sibling path during the same reduction. This removes the previous duplicate target-treelet hash in GPU opening extraction.

## Verification Commands

```bash
swift build
swift test
swift test -c release -Xswiftc -Osize
swift run zkmetal-bench --suite --leaves 256 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-suite.json
swift run zkmetal-bench --suite --suite-leaf-bytes 32 --suite-hashes sha3-256 --leaves 128 --iterations 1 --warmups 0 --no-pipeline-archive
swift run zkmetal-bench --suite --suite-leaf-bytes 32,137 --leaves 128 --iterations 1 --warmups 0 --no-pipeline-archive --json
swift run zkmetal-bench --suite --suite-leaf-bytes 0,136 --leaves 2305843009213693952 --iterations 1 --warmups 0 --no-pipeline-archive --json
swift run zkmetal-bench --keccakf-permutation --states 128 --iterations 1 --warmups 0 --no-pipeline-archive --json
swift run zkmetal-bench --keccakf-permutation --states 64 --permutation-kernel simdgroup --iterations 1 --warmups 0 --no-pipeline-archive --json
swift run zkmetal-bench --m31-dot-product --elements 4097 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-m31-dot-product.json
.build/release/zkmetal-bench --m31-dot-product --elements 16384 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-m31-dot-product.json
swift run zkmetal-bench --m31-inverse --leaves 4097 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-m31-inverse.json
.build/release/zkmetal-bench --m31-inverse --leaves 16384 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-m31-inverse.json
swift run zkmetal-bench --cm31-multiply --elements 4097 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-cm31-multiply.json
.build/release/zkmetal-bench --cm31-multiply --elements 16384 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-cm31-multiply.json
swift run zkmetal-bench --qm31-multiply --elements 4097 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-qm31-multiply.json
swift run zkmetal-bench --qm31-inverse --elements 4097 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-qm31-inverse.json
swift run zkmetal-bench --qm31-fri-fold --elements 4096 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-qm31-fri-fold-debug.json
swift run zkmetal-bench --circle-fri-fold --elements 1024 --iterations 2 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-circle-fri-fold-debug.json
swift run zkmetal-bench --circle-fri-fold-chain --elements 1024 --fri-fold-rounds 3 --iterations 2 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-circle-fri-fold-chain-debug.json
swift run zkmetal-bench --circle-fri-fold-chain-merkle --elements 1024 --fri-fold-rounds 3 --iterations 2 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-circle-fri-fold-chain-merkle-debug.json
swift run zkmetal-bench --circle-codeword-prover --elements 1024 --fri-fold-rounds 3 --iterations 2 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-circle-codeword-prover-debug.json
swift run zkmetal-bench --qm31-fri-proof --elements 1024 --fri-fold-rounds 3 --fri-query-count 3 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-qm31-fri-proof.json
swift run zkmetal-bench --qm31-fri-fold-chain --elements 4096 --fri-fold-rounds 3 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-qm31-fri-fold-chain-debug.json
swift run zkmetal-bench --qm31-fri-fold-chain-transcript --elements 4096 --fri-fold-rounds 3 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-qm31-fri-fold-chain-transcript-debug.json
swift run zkmetal-bench --qm31-fri-fold-chain-merkle --elements 4096 --fri-fold-rounds 3 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-qm31-fri-fold-chain-merkle-debug.json
.build/release/zkmetal-bench --qm31-multiply --elements 16384 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-qm31-multiply.json
.build/release/zkmetal-bench --qm31-inverse --elements 16384 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-qm31-inverse.json
.build/release/zkmetal-bench --qm31-fri-fold --elements 16384 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-qm31-fri-fold.json
.build/release/zkmetal-bench --circle-fri-fold --elements 16384 --iterations 5 --warmups 1 --no-pipeline-archive --json > BenchmarkBaselines/apple-m4-circle-fri-fold-2026-04-13.json
.build/release/zkmetal-bench --circle-fri-fold-chain --elements 16384 --fri-fold-rounds 3 --iterations 5 --warmups 1 --no-pipeline-archive --json > BenchmarkBaselines/apple-m4-circle-fri-fold-chain-2026-04-14.json
.build/release/zkmetal-bench --circle-fri-fold-chain-merkle --elements 16384 --fri-fold-rounds 3 --iterations 5 --warmups 1 --no-pipeline-archive --json > BenchmarkBaselines/apple-m4-circle-fri-fold-chain-merkle-2026-04-14.json
.build/release/zkmetal-bench --circle-codeword-prover --elements 16384 --fri-fold-rounds 3 --iterations 5 --warmups 1 --no-pipeline-archive --json > BenchmarkBaselines/apple-m4-circle-codeword-prover-2026-04-14.json
.build/release/zkmetal-bench --qm31-fri-fold-chain --elements 16384 --fri-fold-rounds 3 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-qm31-fri-fold-chain.json
.build/release/zkmetal-bench --qm31-fri-fold-chain-transcript --elements 16384 --fri-fold-rounds 3 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-qm31-fri-fold-chain-transcript.json
.build/release/zkmetal-bench --qm31-fri-fold-chain-merkle --elements 4096 --fri-fold-rounds 3 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-release-qm31-fri-fold-chain-merkle.json
swift run zkmetal-bench --suite --suite-leaf-bytes 64,128,135,136 --suite-hashes sha3-256,keccak-256 --leaves 256 --iterations 1 --warmups 0 --no-pipeline-archive --merkle-subtree-leaves 16 --json > /tmp/applezk-treelet-fixedrate-suite.json
swift run zkmetal-bench --merkle-opening --leaves 1024 --leaf-bytes 135 --opening-leaf-index 777 --merkle-subtree-auto --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-merkle-opening.json
swift test --filter CircleDomainTests/testCircleCodewordPlanMatchesCPUOracleAndFeedsResidentProver
swift run zkmetal-bench --circle-codeword-prover --elements 1024 --fri-fold-rounds 3 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-circle-codeword-prover-resident-coefficients.json
swift build -c release -Xswiftc -Osize
.build/release/zkmetal-bench --suite --suite-leaf-bytes 64,128,135,136 --suite-hashes sha3-256 --leaves 16384 --iterations 5 --warmups 1 --no-pipeline-archive --no-merkle-subtree --json > /tmp/applezk-release-scalar-fixedrate-suite.json
.build/release/zkmetal-bench --suite --suite-leaf-bytes 64,128,135,136 --suite-hashes sha3-256 --leaves 16384 --iterations 5 --warmups 1 --no-pipeline-archive --merkle-subtree-auto --json > /tmp/applezk-release-auto-fixedrate-suite.json
.build/release/zkmetal-bench --merkle-opening --leaves 16384 --leaf-bytes 135 --opening-leaf-index 7777 --merkle-subtree-auto --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-merkle-opening.json
.build/release/zkmetal-bench --merkle-opening --leaves 16384 --leaf-bytes 135 --opening-leaf-index 7777 --merkle-subtree-auto --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-merkle-opening-combined.json
.build/release/zkmetal-bench --suite --leaves 16384 --iterations 10 --json > BenchmarkBaselines/apple-m4-apple9-suite-2026-04-13.json
.build/release/zkmetal-bench --suite --leaves 16384 --iterations 10 --hash-kernel simdgroup --hash-simdgroups-per-threadgroup 2 --json > BenchmarkBaselines/apple-m4-apple9-suite-simdgroup-2026-04-13.json
```

Observed result: `swift test -c release -Xswiftc -Osize` passed 43 tests at baseline capture time. Both optimized JSON suites produced 12 benchmark reports and every report had `verification.matchedCPU == true`. The invalid `137`-byte suite input failed during argument validation with the expected fixed-rate range error. The oversized suite failed during argument validation with the expected leaf-buffer size error. Later Keccak-F1600 scalar and simdgroup smoke reports produced schema v1 JSON with `verification.matchedCPU == true`; these smoke runs are correctness checks, not checked-in performance baselines.

After the fixed-rate Merkle treelet expansion, `swift test` and `swift test -c release -Xswiftc -Osize` passed 60 tests. The fixed-rate treelet smoke suite produced 8 benchmark reports and every report had `verification.matchedCPU == true`.

After Merkle opening extraction was added, `swift test` passed 65 tests. After the race-free treelet scratch and treelet-aware opening work, `swift test` and `swift test -c release -Xswiftc -Osize` passed 66 tests. The debug opening smoke report had `verification.matchedCPU == true`, 10 siblings for 1,024 leaves, and selected a 64-leaf opening treelet. The optimized opening smoke report had `verification.matchedCPU == true`, 14 siblings for 16,384 leaves, and selected a 64-leaf opening treelet.

After the combined treelet root/opening kernel, `swift test` and `swift test -c release -Xswiftc -Osize` passed 67 tests. The updated optimized opening smoke report had `verification.matchedCPU == true`, 14 siblings for 16,384 leaves, selected a 64-leaf opening treelet, and produced matching root/proof digests against the CPU oracle.

After the M31 dot-product primitive, `swift test` and `swift test -c release -Xswiftc -Osize` passed 73 tests. The debug dot-product smoke report for 4,097 elements had `verification.matchedCPU == true` and selected 256 threads per threadgroup and 1,024 elements per threadgroup. The release `-Osize` smoke report for 16,384 elements had `verification.matchedCPU == true`, the same reduction geometry, 372,011,357.55 elements/sec, and 2,976,090,860.37 input bytes/sec. This is a smoke measurement, not a checked-in release baseline.

After the M31 vector inverse primitive, `swift test` and `swift test -c release -Xswiftc -Osize` passed 73 tests. The debug inverse smoke report for 4,097 elements had `verification.matchedCPU == true` and matching CPU/GPU output digests. The release `-Osize` smoke report for 16,384 elements had `verification.matchedCPU == true`, 167,825,862.18 elements/sec, and 671,303,448.74 input bytes/sec. This is a smoke measurement, not a checked-in release baseline.

After the CM31 vector multiplication primitive, `swift test` and `swift test -c release -Xswiftc -Osize` passed 76 tests. The debug CM31 multiply smoke report for 4,097 elements had `verification.matchedCPU == true` and matching CPU/GPU output digests. The release `-Osize` smoke report for 16,384 CM31 elements had `verification.matchedCPU == true`, 398,395,134.07 elements/sec, and 6,374,322,145.07 input bytes/sec. This is a smoke measurement, not a checked-in release baseline.

After the QM31 secure-field primitive, `swift test` and `swift test -c release -Xswiftc -Osize` passed 79 tests. The debug QM31 multiply and inverse smoke reports for 4,097 elements had `verification.matchedCPU == true` and matching CPU/GPU output digests. The release `-Osize` smoke report for 16,384 QM31 multiplications had `verification.matchedCPU == true`, 272,877,163.06 elements/sec, and 8,732,069,217.83 input bytes/sec. The release `-Osize` smoke report for 16,384 QM31 inversions had `verification.matchedCPU == true`, 124,121,211.15 elements/sec, and 1,985,939,378.43 input bytes/sec. These are smoke measurements, not checked-in release baselines.

After the QM31 radix-2 FRI fold primitive, `swift test` and `swift test -c release -Xswiftc -Osize` passed 82 tests. The debug FRI fold smoke report for 4,096 input QM31 elements produced 2,048 folded outputs, had `verification.matchedCPU == true`, and matching CPU/GPU output digests. The release `-Osize` smoke report for 16,384 input QM31 elements produced 8,192 folded outputs, had `verification.matchedCPU == true`, 228,348,453.17 folded elements/sec, and 10,960,725,751.93 input bytes/sec. This is a smoke measurement of the resident `executeResident` command path, not a checked-in release baseline.

After the Circle first-fold Metal plan, explicit-challenge Circle fold-chain plan, Circle V1 Merkle-transcript fold-chain plan, resident FRI query extractor, resident proof emitter, direct Circle codeword plan, composed codeword prover, and multi-layer CPU verifier, `swift test --filter CircleDomainTests`, `swift test`, `swift test -c release -Xswiftc -Osize`, `swift run zkmetal-bench --circle-fri-fold --elements 1024 --iterations 2 --warmups 1 --no-pipeline-archive --json`, `swift run zkmetal-bench --circle-fri-fold-chain --elements 1024 --fri-fold-rounds 3 --iterations 2 --warmups 1 --no-pipeline-archive --json`, `swift run zkmetal-bench --circle-fri-fold-chain-merkle --elements 1024 --fri-fold-rounds 3 --iterations 2 --warmups 1 --no-pipeline-archive --json`, and `swift run zkmetal-bench --circle-codeword-prover --elements 1024 --fri-fold-rounds 3 --iterations 2 --warmups 1 --no-pipeline-archive --json` passed. The Circle tests include pinned first-fold and three-round proof digest vectors plus resident proof-emission parity, direct codeword parity for mixed, x-only, and y-only Circle functions, and tampered commitment/opening/final-layer/public-input rejection cases. The checked-in Apple M4 release `-Osize` baseline for 16,384 input QM31 elements over a canonical `logSize = 14` Circle domain produced 8,192 folded outputs, had `verification.matchedCPU == true`, 225,209,618.95 folded elements/sec, and 10,810,061,709.81 input bytes/sec. The refreshed checked-in three-round explicit Circle fold-chain baseline for the same input size produced 2,048 final outputs, has `verification.matchedCPU == true`, and recorded 30,117,649.75 final-output elements/sec. The Circle V1 Merkle-transcript chain baseline produced the same final-output size, generated GPU roots from resident layers before each challenge, materialized committed FRI layers for selected openings, has `verification.matchedCPU == true`, recorded 415,373.69 final-output elements/sec for the root/transcript/fold/materialization path, recorded 3,509.71 transcript-sampled leaf openings/sec for resident query extraction, recorded 120.70 complete proofs/sec for resident proof emission, emitted 43,844-byte proofs, and emitted final output digest `55a8b09536097dba6e3869c69c12787580bf65af2f776dd1e620436708084c7c`. The direct Circle codeword prover baseline used 8 `P(x)` coefficients, 7 `Q(x)` coefficients, generated a 16,384-element codeword, emitted the same 2,048-element final FRI layer shape, had `verification.matchedCPU == true` and `verification.verifierAccepted == true`, recorded 170,444,725.71 codeword evaluations/sec, 32.70 resident proofs/sec from the generated codeword buffer, 33.83 full polynomial-to-proof executions/sec, emitted 43,844-byte proofs, codeword digest `0a4ff8f860f6e64dd54aa2261d8cbc4d929c6e7c7c124f30b3531772997b58be`, and proof digest `80e8b093680f5662b57aed2ede38d82f8e6e5eb906a7c046198c603203aa5569`. The explicit baseline times resident folds with precomputed public inverse-domain buffers; the Merkle-transcript baseline includes current-layer Merkle roots, transcript absorption/squeeze, folds, materialized FRI layer retention, query extraction, and proof emission from an already-resident evaluation buffer; the codeword-prover baseline includes direct resident codeword generation but is not an optimized Circle FFT.

After the chained QM31 radix-2 FRI fold plan, `swift test` and `swift test -c release -Xswiftc -Osize` passed 85 tests. The debug chain smoke report for 4,096 input QM31 elements, 3 rounds, and 512 final output elements had `verification.matchedCPU == true` and matching CPU/GPU output digests. The release `-Osize` smoke report for 16,384 input QM31 elements, 3 rounds, and 2,048 final output elements had `verification.matchedCPU == true`, 30,303,327.94 final output elements/sec, and 7,272,798,704.66 input bytes/sec. This is a smoke measurement of a single resident command buffer that keeps intermediate fold layers in private GPU scratch, not a checked-in release baseline.

After the transcript-derived QM31 FRI chain challenge path, `swift test` and `swift test -c release -Xswiftc -Osize` passed 87 tests. The debug explicit and transcript chain smoke reports for 4,096 input QM31 elements, 3 rounds, and 512 final output elements had `verification.matchedCPU == true` and matching CPU/GPU output digests. The refreshed release `-Osize` explicit chain smoke report for 16,384 input QM31 elements, 3 rounds, and 2,048 final output elements had `verification.matchedCPU == true`, 20,029,339.84 final output elements/sec, and 4,807,041,562.23 input bytes/sec. The release transcript-derived chain smoke report for the same shape had `verification.matchedCPU == true`, 1,681,617.58 final output elements/sec, and 403,667,044.11 input bytes/sec. These are smoke measurements, not checked-in release baselines.

After the Merkle-bound QM31 FRI chain path, `swift test` and `swift test -c release -Xswiftc -Osize` passed 89 tests. The debug and release Merkle-bound chain smoke reports for 4,096 input QM31 elements, 3 rounds, and 512 final output elements had `verification.matchedCPU == true` and matching CPU/GPU output digests. The release smoke report had 171,332.96 final output elements/sec and 41,152,035.69 input bytes/sec. This is a smoke measurement of the composed current-layer Merkle commitment, transcript squeeze, and fold path, not a checked-in release baseline.

After the linear QM31 FRI proof/decommitment format and verifier were added, `swift test` and `swift test -c release -Xswiftc -Osize` passed 90 tests. The first proof-surface benchmark now exists under `--qm31-fri-proof`; it measures the CPU proof artifact path for the current linear radix-2 layout, while the timed GPU path remains the Merkle-bound chained fold benchmark above.

After the QM31 proof benchmark and Circle resident-coefficient prover path were added, `swift build`, `swift test --filter CircleDomainTests/testCircleCodewordPlanMatchesCPUOracleAndFeedsResidentProver`, `swift run zkmetal-bench --qm31-fri-proof --elements 1024 --fri-fold-rounds 3 --fri-query-count 3 --iterations 1 --warmups 0 --no-pipeline-archive --json`, and `swift run zkmetal-bench --circle-codeword-prover --elements 1024 --fri-fold-rounds 3 --iterations 1 --warmups 0 --no-pipeline-archive --json` passed. The QM31 proof smoke report had `verification.matchedCPU == true`, `verification.verifierAccepted == true`, 25,173-byte deterministic JSON proofs, 18 Merkle openings, final-layer digest `4bd8e2ea994f369f6de902b91e8b7290ed5b375d7d07afd0f46a360d5954a00a`, proof digest `7a4041b027aa234b45504d9bf5567defd506dca2a20453f9b0856dbbccf6eabc`, 6.169341 seconds proof-build wall time, 0.000599584 seconds serialization wall time, 0.000440459 seconds deserialization wall time, and 0.050755417 seconds verifier wall time. The Circle resident-coefficient debug smoke report had `verification.matchedCPU == true`, `verification.verifierAccepted == true`, 10,052-byte binary proofs, codeword digest `1c59bed170630273457bc537023119fdce3c348c1ce2066d0901f5db4ab9fee3`, proof digest `b9a2107ad95ee6eeeba0e4e765751913c43f67ef7610af1319b4fb6bf9198fa2`, 2,831,336.42 codeword evaluations/sec, 32.05 resident proofs/sec, and 38.55 full resident coefficient polynomial-to-proof executions/sec. These are debug smoke measurements, not release baselines.

The default SwiftPM release optimization mode (`-O`) currently triggers a Swift optimized-codegen failure on this host around throwing-return handling in the benchmark executable and release test bundle. The optimized verification command therefore uses `-Osize` until the toolchain issue is either isolated further or no longer reproduces. This is an explicit measurement constraint, not a cryptographic relaxation.

## Smoke Matrix

The smoke suite used debug builds, one timed iteration, no warmup, and pipeline archives disabled. These numbers prove the harness and correctness checks execute end to end; they are not a performance baseline.

| Hash | Leaf bytes | Hash min wall seconds | Merkle min wall seconds |
| --- | ---: | ---: | ---: |
| SHA3-256 | 0 | 0.002471583 | 0.001891917 |
| Keccak-256 | 0 | 0.002736292 | 0.000799208 |
| SHA3-256 | 32 | 0.003344583 | 0.001298250 |
| Keccak-256 | 32 | 0.002096958 | 0.003030459 |
| SHA3-256 | 64 | 0.002324792 | 0.001002417 |
| Keccak-256 | 64 | 0.001599250 | 0.000823167 |
| SHA3-256 | 128 | 0.002190250 | 0.002033083 |
| Keccak-256 | 128 | 0.002755375 | 0.000791041 |
| SHA3-256 | 135 | 0.002426375 | 0.001020459 |
| Keccak-256 | 135 | 0.003249791 | 0.001322875 |
| SHA3-256 | 136 | 0.002503292 | 0.000982083 |
| Keccak-256 | 136 | 0.001757708 | 0.001012000 |

## Fixed-Rate Merkle Auto Smoke

The fixed-rate Merkle smoke used release `-Osize`, 16,384 leaves, one warmup, five timed iterations, CPU verification enabled, pipeline archives disabled, and SHA3-256 standalone hash rows so the Merkle timings compare the same commitment workload. These are not checked-in release baselines. After switching treelet reductions to race-free ping-pong scratch, automatic subtree selection is intentionally conservative: it selected no treelet for 64- and 128-byte leaves on this host, and selected 64-leaf treelets for the near-rate 135- and 136-byte cases below.

| Leaf bytes | Selected subtree leaves | Scalar Merkle min wall seconds | Auto Merkle min wall seconds | Wall speedup | Scalar Merkle min GPU seconds | Auto Merkle min GPU seconds | GPU speedup |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 135 | 64 | 0.001348959 | 0.000722208 | 1.87x | 0.000749125 | 0.000493250 | 1.52x |
| 136 | 64 | 0.001771000 | 0.000996834 | 1.78x | 0.001132667 | 0.000567042 | 2.00x |

Interpretation: race-free treelets remain beneficial for near-rate SHA3 leaves on this Apple M4 / Apple9 host. Shorter fixed-rate leaves require explicit `--merkle-subtree-leaves` or planner tuning records rather than automatic promotion, because the scalar path was faster in the refreshed smoke data.

## Merkle Opening Smoke

The opening smoke used release `-Osize`, 16,384 leaves, 135-byte leaves, leaf index 7,777, one warmup, five timed iterations, CPU verification enabled, and pipeline archives disabled. The configured subtree mode was automatic and selected a 64-leaf treelet; lower siblings were extracted inside the selected treelet and upper siblings were extracted from the resident subtree-root tree.

| Leaf bytes | Leaf index | Selected subtree leaves | Siblings | Opening min wall seconds | Opening min GPU seconds | CPU proof match |
| ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 135 | 7777 | 64 | 14 | 0.001612791 | 0.000938375 | true |

Interpretation: this is the current measurement gate for treelet-aware GPU opening extraction. The opening-mode treelet kernel now produces subtree roots for the upper tree and the requested lower sibling path in one pass, so the target treelet is no longer hashed twice. The previous race-free opening smoke minimums for the same command shape were 0.001980750 wall seconds and 0.001435917 GPU seconds.

## CM31 Vector Multiply Smoke

The CM31 smoke used release `-Osize`, 16,384 CM31 elements, one warmup, five timed iterations, CPU verification enabled, and pipeline archives disabled. The input bandwidth counts both CM31 input vectors, so each logical element contributes four 32-bit M31 limbs.

| Elements | Operation | Min wall seconds | Min GPU seconds | Elements/sec | Input bytes/sec | CPU digest match |
| ---: | --- | ---: | ---: | ---: | ---: | --- |
| 16,384 | multiply | 0.000418166 | 0.000041125 | 398,395,134.07 | 6,374,322,145.07 | true |

Interpretation: this is the first measurement gate for extension-field multiplication. It validates the benchmark harness, kernel dispatch, and CPU digest check, but it is not a checked-in release baseline and does not yet measure resident composition with FRI or PCS kernels.

## QM31 Vector Smoke

The QM31 smoke used release `-Osize`, 16,384 QM31 elements, one warmup, five timed iterations, CPU verification enabled, and pipeline archives disabled. Multiplication input bandwidth counts both QM31 input vectors; inverse input bandwidth counts one QM31 input vector.

| Elements | Operation | Min wall seconds | Min GPU seconds | Elements/sec | Input bytes/sec | CPU digest match |
| ---: | --- | ---: | ---: | ---: | ---: | --- |
| 16,384 | multiply | 0.000332125 | 0.000060042 | 272,877,163.06 | 8,732,069,217.83 | true |
| 16,384 | inverse | 0.000578833 | 0.000132000 | 124,121,211.15 | 1,985,939,378.43 | true |

Interpretation: this is the first measurement gate for the quartic secure-field lane. It proves the kernel, CPU oracle, and digest verification path execute end to end, while the separate FRI fold smoke below measures the first resident composition layer.

## QM31 FRI Fold Smoke

The QM31 FRI fold smoke used release `-Osize`, 16,384 input QM31 elements, 8,192 folded output elements, one warmup, five timed iterations, CPU verification enabled, and pipeline archives disabled. Input bandwidth counts the input evaluation vector plus the inverse-domain vector; the timed path calls `executeResident`, so it does not use the public array/readback convenience path.

| Input elements | Output elements | Min wall seconds | Min GPU seconds | Folded elements/sec | Input bytes/sec | CPU digest match |
| ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 16,384 | 8,192 | 0.000300292 | 0.000035875 | 228,348,453.17 | 10,960,725,751.93 | true |

Interpretation: this is the first measurement gate for resident QM31 FRI composition. It proves one radix-2 fold layer can consume caller-owned field buffers and write the next layer without an internal CPU readback. It is not a full Circle FFT, multi-round FRI protocol, PCS commitment flow, or proof/query benchmark.

## QM31 FRI Fold Chain Smoke

The explicit and detached-root transcript rows used release `-Osize`, 16,384 input QM31 elements, 3 fold rounds, 2,048 final output elements, one warmup, five timed iterations, CPU verification enabled, and pipeline archives disabled. The Merkle-bound row is the first release smoke for the stronger current-layer commitment path and uses 4,096 input elements, no warmup, and one timed iteration. Explicit-challenge input bandwidth counts the input evaluation vector plus all concatenated per-round inverse-domain vectors. Transcript-derived input bandwidth additionally counts the 32-byte per-round commitment-root frames that are absorbed before each GPU challenge squeeze. All timed paths keep intermediate fold layers resident and expose only final proof material.

| Challenge mode | Input elements | Rounds | Output elements | Inverse-domain elements | Min wall seconds | Min GPU seconds | Final output elements/sec | Input bytes/sec | CPU digest match |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| explicit | 16,384 | 3 | 2,048 | 14,336 | 0.000770375 | 0.000102250 | 20,029,339.84 | 4,807,041,562.23 | true |
| transcript | 16,384 | 3 | 2,048 | 14,336 | 0.001795333 | 0.001217875 | 1,681,617.58 | 403,667,044.11 | true |
| merkle-transcript | 4,096 | 3 | 512 | 3,584 | 0.005045208 | 0.002988333 | 171,332.96 | 41,152,035.69 | true |

Interpretation: the explicit mode removes host synchronization between three radix-2 fold layers for caller-supplied inverse-domain points and challenges. The transcript mode additionally derives each QM31 challenge from a domain-separated transcript that absorbs a 32-byte round commitment root and feeds the GPU challenge buffer into the fold kernel without CPU challenge materialization. The Merkle-bound mode generates those roots from the current resident layer buffers before challenge derivation, so it measures a stronger composition path; the row uses a smaller debug smoke shape and should not be compared directly with the release rows above. This is still not a full Circle FFT, PCS query/decommitment benchmark, or verifier proof-format benchmark.

## QM31 FRI Proof Smoke

The proof smoke used a debug build, 1,024 input QM31 elements, three fold rounds, 128 final-layer elements, three transcript-sampled query pairs, no warmup, one timed iteration, CPU verification enabled, and pipeline archives disabled. It measures the CPU proof artifact path for the current linear radix-2 layout: proof construction, deterministic JSON serialization, strict deserialization, and independent verification.

| Input elements | Rounds | Queries | Openings | Proof bytes | Build wall seconds | Serialize wall seconds | Deserialize wall seconds | Verify wall seconds | CPU proof match | Verifier accepted |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 1,024 | 3 | 3 | 18 | 25,173 | 6.169341 | 0.000599584 | 0.000440459 | 0.050755417 | true | true |

Interpretation: this is a correctness-gated proof-surface benchmark, not a GPU throughput claim. The expensive build time is dominated by the current CPU proof builder repeatedly materializing Merkle layers and openings for the developer JSON proof. That is now visible in machine-readable benchmark output instead of hidden behind unit tests.

## Release Baseline

The checked-in release baselines used `swift build -c release -Xswiftc -Osize`, 16,384 leaves, one warmup, 10 timed iterations, CPU verification enabled, and the default read/write Metal binary archive. The simdgroup suite used two simdgroups per threadgroup; scalar reports leave that field empty because it is not applicable.

### Scalar Hash Kernel

| Hash | Leaf bytes | Hash min wall seconds | Hash min GPU seconds | Merkle min wall seconds |
| --- | ---: | ---: | ---: | ---: |
| SHA3-256 | 0 | 0.000658417 | 0.000436958 | 0.001669667 |
| Keccak-256 | 0 | 0.000544875 | 0.000275875 | 0.001481959 |
| SHA3-256 | 32 | 0.000522916 | 0.000259375 | 0.001585917 |
| Keccak-256 | 32 | 0.000322417 | 0.000124292 | 0.001290166 |
| SHA3-256 | 64 | 0.000342416 | 0.000123375 | 0.000577000 |
| Keccak-256 | 64 | 0.000347792 | 0.000170625 | 0.000727958 |
| SHA3-256 | 128 | 0.000407542 | 0.000176667 | 0.000705375 |
| Keccak-256 | 128 | 0.000444583 | 0.000225000 | 0.000835625 |
| SHA3-256 | 135 | 0.000672958 | 0.000265541 | 0.001241833 |
| Keccak-256 | 135 | 0.000451042 | 0.000217500 | 0.000819875 |
| SHA3-256 | 136 | 0.000571917 | 0.000328875 | 0.001190750 |
| Keccak-256 | 136 | 0.000873583 | 0.000228375 | 0.001098208 |

### SIMD-Group Hash Kernel

| Hash | Leaf bytes | Hash min wall seconds | Hash min GPU seconds | Merkle min wall seconds |
| --- | ---: | ---: | ---: | ---: |
| SHA3-256 | 0 | 0.002997667 | 0.002785625 | 0.000554000 |
| Keccak-256 | 0 | 0.004067666 | 0.003779125 | 0.000912208 |
| SHA3-256 | 32 | 0.004815792 | 0.004464000 | 0.000957000 |
| Keccak-256 | 32 | 0.005909417 | 0.002846375 | 0.001048000 |
| SHA3-256 | 64 | 0.003110792 | 0.002820500 | 0.000616375 |
| Keccak-256 | 64 | 0.003102417 | 0.002822417 | 0.000654167 |
| SHA3-256 | 128 | 0.003229208 | 0.002826750 | 0.000820042 |
| Keccak-256 | 128 | 0.003087166 | 0.002822250 | 0.000669208 |
| SHA3-256 | 135 | 0.003097208 | 0.002828750 | 0.000644750 |
| Keccak-256 | 135 | 0.003101125 | 0.002822042 | 0.000660583 |
| SHA3-256 | 136 | 0.006724583 | 0.006425250 | 0.000772833 |
| Keccak-256 | 136 | 0.006258708 | 0.005917875 | 0.000752000 |

## Interpretation

- The benchmark surface now catches correctness regressions across the fixed-rate boundary, including the full-rate 136-byte path and the 135-byte near-boundary path.
- The suite keeps Merkle commitments in SHA3-256 regardless of the standalone hash selection, matching the current API contract and avoiding a silent commitment-domain change.
- The first simdgroup fixed-hash path is correct but slower than the scalar baseline on this Apple M4 / Apple9 run. Two simdgroups per threadgroup improves several fixed-rate cases versus the first baseline, but launch packing is not the dominant bottleneck. It remains opt-in and planner-ineligible.
- Meaningful throughput claims should be collected from release builds with higher `--iterations`, warmups enabled, pipeline archive mode recorded, and the resulting JSON checked into `BenchmarkBaselines/`.

# Benchmark Findings

Date: 2026-04-13

Host used for the smoke run: Apple M4, Apple9 Metal family available.

## Work Completed

- Captured the first checked-in optimized suite baseline:
  `BenchmarkBaselines/apple-m4-apple9-suite-2026-04-13.json`.
- Captured an opt-in simdgroup hash suite baseline:
  `BenchmarkBaselines/apple-m4-apple9-suite-simdgroup-2026-04-13.json`.
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
.build/release/zkmetal-bench --qm31-multiply --elements 16384 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-qm31-multiply.json
.build/release/zkmetal-bench --qm31-inverse --elements 16384 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-qm31-inverse.json
.build/release/zkmetal-bench --qm31-fri-fold --elements 16384 --iterations 5 --warmups 1 --no-pipeline-archive --json > /tmp/applezk-release-qm31-fri-fold.json
swift run zkmetal-bench --suite --suite-leaf-bytes 64,128,135,136 --suite-hashes sha3-256,keccak-256 --leaves 256 --iterations 1 --warmups 0 --no-pipeline-archive --merkle-subtree-leaves 16 --json > /tmp/applezk-treelet-fixedrate-suite.json
swift run zkmetal-bench --merkle-opening --leaves 1024 --leaf-bytes 135 --opening-leaf-index 777 --merkle-subtree-auto --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-merkle-opening.json
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

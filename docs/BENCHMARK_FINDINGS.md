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
swift build -c release -Xswiftc -Osize
.build/release/zkmetal-bench --suite --leaves 16384 --iterations 10 --json > BenchmarkBaselines/apple-m4-apple9-suite-2026-04-13.json
.build/release/zkmetal-bench --suite --leaves 16384 --iterations 10 --hash-kernel simdgroup --hash-simdgroups-per-threadgroup 2 --json > BenchmarkBaselines/apple-m4-apple9-suite-simdgroup-2026-04-13.json
```

Observed result: `swift test -c release -Xswiftc -Osize` passed 43 tests at baseline capture time. Both optimized JSON suites produced 12 benchmark reports and every report had `verification.matchedCPU == true`. The invalid `137`-byte suite input failed during argument validation with the expected fixed-rate range error. The oversized suite failed during argument validation with the expected leaf-buffer size error. Later Keccak-F1600 scalar and simdgroup smoke reports produced schema v1 JSON with `verification.matchedCPU == true`; these smoke runs are correctness checks, not checked-in performance baselines.

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

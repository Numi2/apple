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
- Added `zkmetal-bench --suite` so benchmark runs can cover the fixed-rate matrix instead of one leaf size and one standalone hash at a time.
- The default suite matrix is SHA3-256 and Keccak-256 over leaf lengths `0`, `32`, `64`, `128`, `135`, and `136`.
- Suite JSON reports use a top-level suite envelope with the exact matrix configuration and the per-case `BenchmarkReport` payloads unchanged.
- Suite validation rejects any leaf length outside the current fixed-rate SHA3/Keccak GPU contract of `0...136` bytes before Metal work is created.
- Suite allocation checks use the largest selected suite leaf length, so oversized benchmark matrices fail during argument validation instead of reaching buffer construction.
- Text output now has a compact suite summary with each case's target, minimum hash wall time, minimum Merkle wall time, and CPU verification status.
- CPU verification is now a hard benchmark gate: when enabled, any false or missing CPU match emits the report, writes a mismatch summary to stderr, and exits with status `2`.

## Verification Commands

```bash
swift build
swift test
swift test -c release -Xswiftc -Osize
swift run zkmetal-bench --suite --leaves 256 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-suite.json
swift run zkmetal-bench --suite --suite-leaf-bytes 32 --suite-hashes sha3-256 --leaves 128 --iterations 1 --warmups 0 --no-pipeline-archive
swift run zkmetal-bench --suite --suite-leaf-bytes 32,137 --leaves 128 --iterations 1 --warmups 0 --no-pipeline-archive --json
swift run zkmetal-bench --suite --suite-leaf-bytes 0,136 --leaves 2305843009213693952 --iterations 1 --warmups 0 --no-pipeline-archive --json
swift build -c release -Xswiftc -Osize
.build/release/zkmetal-bench --suite --leaves 16384 --iterations 10 --json > BenchmarkBaselines/apple-m4-apple9-suite-2026-04-13.json
.build/release/zkmetal-bench --suite --leaves 16384 --iterations 10 --hash-kernel simdgroup --json > BenchmarkBaselines/apple-m4-apple9-suite-simdgroup-2026-04-13.json
```

Observed result: `swift test -c release -Xswiftc -Osize` passed 42 tests. Both optimized JSON suites produced 12 benchmark reports and every report had `verification.matchedCPU == true`. The invalid `137`-byte suite input failed during argument validation with the expected fixed-rate range error. The oversized suite failed during argument validation with the expected leaf-buffer size error.

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

The checked-in release baselines used `swift build -c release -Xswiftc -Osize`, 16,384 leaves, one warmup, 10 timed iterations, CPU verification enabled, and the default read/write Metal binary archive.

### Scalar Hash Kernel

| Hash | Leaf bytes | Hash min wall seconds | Hash min GPU seconds | Merkle min wall seconds |
| --- | ---: | ---: | ---: | ---: |
| SHA3-256 | 0 | 0.000522708 | 0.000186750 | 0.000999458 |
| Keccak-256 | 0 | 0.000604375 | 0.000197583 | 0.001096875 |
| SHA3-256 | 32 | 0.000689250 | 0.000265250 | 0.001142708 |
| Keccak-256 | 32 | 0.000789084 | 0.000382125 | 0.001812833 |
| SHA3-256 | 64 | 0.000812583 | 0.000300000 | 0.001847208 |
| Keccak-256 | 64 | 0.000882291 | 0.000532000 | 0.001886708 |
| SHA3-256 | 128 | 0.000520458 | 0.000228125 | 0.000944958 |
| Keccak-256 | 128 | 0.000506208 | 0.000225750 | 0.000876042 |
| SHA3-256 | 135 | 0.000580917 | 0.000257125 | 0.001028875 |
| Keccak-256 | 135 | 0.000685083 | 0.000330875 | 0.001202625 |
| SHA3-256 | 136 | 0.000954833 | 0.000508417 | 0.001447084 |
| Keccak-256 | 136 | 0.000642166 | 0.000332000 | 0.000999250 |

### SIMD-Group Hash Kernel

| Hash | Leaf bytes | Hash min wall seconds | Hash min GPU seconds | Merkle min wall seconds |
| --- | ---: | ---: | ---: | ---: |
| SHA3-256 | 0 | 0.004691166 | 0.004423375 | 0.000842708 |
| Keccak-256 | 0 | 0.004499666 | 0.003921625 | 0.000855750 |
| SHA3-256 | 32 | 0.004703208 | 0.004137125 | 0.000792792 |
| Keccak-256 | 32 | 0.004287625 | 0.003930125 | 0.000776416 |
| SHA3-256 | 64 | 0.004204042 | 0.003926292 | 0.000743458 |
| Keccak-256 | 64 | 0.004260791 | 0.003931667 | 0.000828000 |
| SHA3-256 | 128 | 0.004332208 | 0.003927000 | 0.000858375 |
| Keccak-256 | 128 | 0.005044292 | 0.004509875 | 0.000927625 |
| SHA3-256 | 135 | 0.004859000 | 0.004466500 | 0.000883292 |
| Keccak-256 | 135 | 0.004825583 | 0.004460375 | 0.000946917 |
| SHA3-256 | 136 | 0.007026709 | 0.006703500 | 0.000898625 |
| Keccak-256 | 136 | 0.005979292 | 0.005666250 | 0.000697041 |

## Interpretation

- The benchmark surface now catches correctness regressions across the fixed-rate boundary, including the full-rate 136-byte path and the 135-byte near-boundary path.
- The suite keeps Merkle commitments in SHA3-256 regardless of the standalone hash selection, matching the current API contract and avoiding a silent commitment-domain change.
- The first simdgroup fixed-hash path is correct but slower than the scalar baseline on this Apple M4 / Apple9 run. It remains opt-in and planner-ineligible.
- Meaningful throughput claims should be collected from release builds with higher `--iterations`, warmups enabled, pipeline archive mode recorded, and the resulting JSON checked into `BenchmarkBaselines/`.

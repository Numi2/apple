# Benchmark Findings

Date: 2026-04-12

Host used for the smoke run: Apple M4, Apple9 Metal family available.

## Work Completed

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
swift run zkmetal-bench --suite --leaves 256 --iterations 1 --warmups 0 --no-pipeline-archive --json > /tmp/applezk-suite.json
swift run zkmetal-bench --suite --suite-leaf-bytes 32 --suite-hashes sha3-256 --leaves 128 --iterations 1 --warmups 0 --no-pipeline-archive
swift run zkmetal-bench --suite --suite-leaf-bytes 32,137 --leaves 128 --iterations 1 --warmups 0 --no-pipeline-archive --json
swift run zkmetal-bench --suite --suite-leaf-bytes 0,136 --leaves 2305843009213693952 --iterations 1 --warmups 0 --no-pipeline-archive --json
```

Observed result: `swift test` passed 27 tests. The JSON suite produced 12 benchmark reports and every report had `verification.matchedCPU == true`. The invalid `137`-byte suite input failed during argument validation with the expected fixed-rate range error. The oversized suite failed during argument validation with the expected leaf-buffer size error.

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

## Interpretation

- The benchmark surface now catches correctness regressions across the fixed-rate boundary, including the full-rate 136-byte path and the 135-byte near-boundary path.
- The suite keeps Merkle commitments in SHA3-256 regardless of the standalone hash selection, matching the current API contract and avoiding a silent commitment-domain change.
- Meaningful throughput claims should be collected from release builds with higher `--iterations`, warmups enabled, pipeline archive mode recorded, and the resulting JSON checked into `BenchmarkBaselines/`.

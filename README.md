# AppleZKProver

AppleZKProver is a SwiftPM package for building Apple-silicon-first proving
primitives on top of Metal. It focuses on the parts of transparent proof systems
that are naturally GPU-resident: SHA3/Keccak hashing, Merkle commitments,
Keccak-F1600 permutation batches, transcript work, M31/CM31/QM31 field
reductions, resident QM31 FRI fold layers, linear QM31 FRI proof
serialization, and early M31 sum-check execution.

The project is intentionally narrow, measured, and correctness-gated. It is not
a broad cryptography catalog and does not claim production proof-system security
yet. The current goal is a high-quality accelerator substrate that can compose
hash-heavy prover stages without unnecessary CPU synchronization or buffer
round-trips.

## Highlights

| Area | Current capability |
| --- | --- |
| Language and platform | Swift 6 package targeting macOS 14+ |
| Accelerator | Metal compute kernels tuned for Apple GPU families |
| Hashing | CPU SHA3-256 and Keccak-256 oracles; GPU fixed-rate SHA3-256 and Keccak-256 for `0...136` byte messages |
| Merkle commitments | GPU leaf hashing, fixed-rate lower treelets, GPU parent reduction, upper-tree fusion, final-root and requested-opening readback only |
| Keccak-F1600 | Reusable scalar permutation plans plus opt-in Apple7+ simdgroup benchmarks |
| M31/CM31/QM31 field lanes | CPU oracle plus reusable GPU M31 vector add, subtract, negate, multiply, square, inverse, and dot-product plans; CM31 vector add, subtract, negate, multiply, and square plans; QM31 vector add, subtract, negate, multiply, square, inverse, single-layer/chained radix-2 FRI fold plans with explicit, transcript-derived, or Merkle-bound transcript challenges, and a linear QM31 FRI proof/decommitment verifier |
| Sum-check | GPU-resident canonical M31 chunk: round evaluation, transcript absorb, challenge squeeze, and fold/halve in one command buffer |
| Runtime | Pipeline caching, optional Metal binary archives, reusable execution plans, shared upload rings, private residency arenas, device-scoped planning |
| Verification | CPU-differential tests and verified accelerator APIs for the implemented slice |
| Measurement | `zkmetal-bench` CLI with warmups, repeated samples, JSON output, CPU verification gates, and checked-in Apple M4 / Apple9 baselines |

## Why This Exists

Transparent proof systems spend significant time moving through regular,
parallel work:

- hashing leaves, parents, transcripts, and sponge states,
- committing large evaluation/codeword buffers,
- folding field vectors,
- producing Fiat-Shamir challenges,
- preserving intermediate state across proof stages.

AppleZKProver treats those operations as resident GPU workflows instead of a
sequence of isolated CPU calls. The design bias is simple:

- keep intermediate buffers on the GPU,
- make every accelerator result testable against an independent CPU oracle,
- specialize hot kernel shapes,
- measure full proof-step supersteps instead of isolated micro-kernels,
- persist only correctness-gated tuning decisions.

## Current Scope

Implemented today:

- CPU SHA3-256, Keccak-256, and SHA3 Merkle root oracles.
- GPU SHA3-256 and Keccak-256 fixed-rate batch hashing for one SHA3 rate block
  (`0...136` bytes), including specialized `32`, `64`, `128`, and `136` byte
  kernels.
- GPU Keccak-F1600 permutation-only batch plans for Plonky3-style raw
  permutation benchmarking.
- GPU SHA3 Merkle commitment from raw leaves or prehashed leaves, with parent
  levels kept resident and only the final 32-byte root copied back. Fixed-rate
  raw-leaf treelets can fuse leaf hashing plus the first local Merkle levels for
  SHA3 inputs in the supported `0...136` byte range using race-free ping-pong
  threadgroup scratch. Automatic treelets are currently conservative and promote
  only the near-rate shapes supported by local smoke data.
- GPU raw-leaf Merkle opening extraction for SHA3 commitments. The opening path
  reads back only the requested sibling path plus the root, extracts lower
  siblings inside selected treelets while producing the subtree roots needed for
  the upper path, and is checked against an independent CPU opening oracle by
  the verified API.
- Reusable hash, permutation, Merkle, and sum-check plans with explicit clearing
  for private buffers.
- Canonical M31 field arithmetic oracles and reusable GPU vector plans for add,
  subtract, negate, multiply, square, inverse, and dot product. Inputs are
  validated as canonical field elements before CPU-backed APIs accept the
  result, and inversion rejects zero at the public API boundary.
- CM31 extension-field arithmetic over `M31[X]/(X^2 + 1)`, including CPU
  oracle coverage and reusable GPU vector add, subtract, negate, multiply, and
  square plans with CPU-verified execution.
- QM31 secure-field arithmetic over `CM31[U]/(U^2 - 2 - i)`, including CPU
  oracle coverage and reusable GPU vector add, subtract, negate, multiply,
  square, and inverse plans. The QM31 plan also accepts uploaded GPU buffers
  when a caller already owns canonical resident field vectors.
- A QM31 radix-2 FRI fold primitive with CPU oracle coverage, Metal execution,
  CPU-verified public execution, and a resident `executeResident` path that
  consumes caller-owned field buffers and writes the folded layer without an
  internal readback.
- A chained QM31 radix-2 FRI fold plan that consumes one resident evaluation
  buffer plus concatenated per-round inverse-domain buffers, encodes every fold
  round into one command buffer, ping-pongs private scratch between intermediate
  layers, and writes only the final folded layer to the caller output buffer.
  The chain can use caller-supplied explicit challenges or absorb 32-byte
  per-round commitment roots into domain-separated transcript frames, squeeze
  QM31 challenge limbs on GPU, and feed the resident challenge buffer directly
  into each fold round without CPU challenge materialization. The Merkle-bound
  mode commits each current QM31 layer buffer as 16-byte SHA3 raw leaves inside
  the composed command plan before deriving that round's challenge, so the
  absorbed roots are produced from the resident layer buffers rather than
  supplied independently by the caller.
- A verifier-facing linear QM31 FRI proof object with deterministic sorted-key
  JSON serialization, transcript-sampled query pairs, SHA3 Merkle decommitments
  for every queried folded layer, final-layer binding, and an independent
  CPU-only verifier. This proof format targets the current linear radix-2
  layout; it is not a Circle-domain PCS proof.
- `MetalProofPlanner` for correctness-gated Merkle plan races, SQLite plan
  history, drift observation, and M31 sum-check plan construction.
- GPU transcript helpers for canonical packing, Keccak absorb, and challenge
  squeezing.
- A benchmark CLI that emits reproducible JSON and fails closed on CPU/GPU
  mismatches.

Still intentionally constrained:

- macOS 14+ is required.
- Apple-silicon Macs are the intended accelerator target.
- GPU fixed-rate SHA3/Keccak accepts messages up to `136` bytes.
- Merkle builders expect power-of-two leaf counts.
- Internal Merkle parent hashing is specialized to
  `32-byte left || 32-byte right -> 32-byte parent`.
- Sum-check execution currently targets canonical M31 values and power-of-two
  lane counts.

These constraints keep the first performance path auditable.

## Installation

Use the package directly from a checkout:

```bash
swift build
swift test
```

Or add the repository to another Swift package:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Numi2/apple.git", branch: "main")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AppleZKProver"]
    )
]
```

## Quick Start

```swift
import Foundation
import AppleZKProver

let context = try MetalContext()
let committer = SHA3MerkleCommitter(context: context)

let leafCount = 1 << 12
let leafLength = 32
let leaves = Data((0..<(leafCount * leafLength)).map {
    UInt8(truncatingIfNeeded: $0)
})

let commitment = try committer.commitRawLeavesVerified(
    leaves: leaves,
    leafCount: leafCount,
    leafStride: leafLength,
    leafLength: leafLength
)

print(commitment.root.hexString)
```

Use verified APIs when accelerator correctness is not part of the trusted
computing base:

- `hashVerified`
- `permuteVerified`
- `commitRawLeavesVerified`
- `openRawLeafVerified`
- planned Merkle `commitVerified`
- M31 sum-check `executeVerified`
- M31 vector dot-product `executeVerified`
- CM31 vector arithmetic `executeVerified`
- QM31 vector arithmetic `executeVerified`
- QM31 FRI fold `executeVerified`
- QM31 FRI fold chain `executeVerified`
- QM31 transcript-derived FRI fold chain `executeTranscriptDerivedVerified`
- QM31 Merkle-bound transcript FRI fold chain `executeMerkleTranscriptDerivedVerified`
- QM31 linear FRI proof `QM31FRIProofVerifier.verify`

These APIs recompute the result with the CPU oracle and throw
`AppleZKProverError.correctnessValidationFailed` if the GPU result diverges.

## Benchmarking

Run the benchmark executable from SwiftPM:

```bash
swift run zkmetal-bench --leaves 16384 --leaf-bytes 32
swift run zkmetal-bench --leaves 16384 --leaf-bytes 32 --iterations 10 --json
swift run zkmetal-bench --suite --leaves 16384 --iterations 5 --json
swift run zkmetal-bench --keccakf-permutation --states 16384 --iterations 5 --json
swift run zkmetal-bench --m31-dot-product --elements 16384 --iterations 5 --json
swift run zkmetal-bench --m31-inverse --elements 16384 --iterations 5 --json
swift run zkmetal-bench --cm31-multiply --elements 16384 --iterations 5 --json
swift run zkmetal-bench --qm31-multiply --elements 16384 --iterations 5 --json
swift run zkmetal-bench --qm31-inverse --elements 16384 --iterations 5 --json
swift run zkmetal-bench --qm31-fri-fold --elements 16384 --iterations 5 --json
swift run zkmetal-bench --qm31-fri-fold-chain --elements 16384 --fri-fold-rounds 3 --iterations 5 --json
swift run zkmetal-bench --qm31-fri-fold-chain-transcript --elements 16384 --fri-fold-rounds 3 --iterations 5 --json
swift run zkmetal-bench --qm31-fri-fold-chain-merkle --elements 16384 --fri-fold-rounds 3 --iterations 5 --json
```

Useful benchmark variants:

```bash
swift run zkmetal-bench --leaves 16384 --leaf-bytes 32 --hash keccak-256 --json
swift run zkmetal-bench --leaves 16384 --leaf-bytes 32 --hash-kernel simdgroup --hash-simdgroups-per-threadgroup 2 --json
swift run zkmetal-bench --leaves 16384 --leaf-bytes 136 --merkle-subtree-auto --json
swift run zkmetal-bench --merkle-opening --leaves 16384 --leaf-bytes 135 --opening-leaf-index 7777 --json
swift run zkmetal-bench --suite --suite-leaf-bytes 32,64,128,136 --suite-hashes sha3-256,keccak-256 --json
```

`zkmetal-bench` uses a device-scoped Metal binary archive under
`.build/applezkprover-pipeline-archives/` by default. Use
`--no-pipeline-archive` to disable it or `--pipeline-archive PATH` to choose an
explicit archive path.

When CPU verification is enabled, any mismatch is a benchmark failure. The CLI
prints the requested report, writes the mismatch summary to stderr, and exits
with status `2`.

### Release Baseline Snapshot

Checked-in release baselines live in `BenchmarkBaselines/`. The first Apple M4 /
Apple9 baseline was captured on 2026-04-13 with:

```bash
swift build -c release -Xswiftc -Osize
.build/release/zkmetal-bench --suite --leaves 16384 --iterations 10 --json
```

Selected scalar-kernel minimums from that run:

| Hash | Leaf bytes | Hash wall time | Hash GPU time | Merkle wall time |
| --- | ---: | ---: | ---: | ---: |
| SHA3-256 | 32 | 0.000522916s | 0.000259375s | 0.001585917s |
| Keccak-256 | 32 | 0.000322417s | 0.000124292s | 0.001290166s |
| SHA3-256 | 64 | 0.000342416s | 0.000123375s | 0.000577000s |
| SHA3-256 | 128 | 0.000407542s | 0.000176667s | 0.000705375s |
| Keccak-256 | 136 | 0.000873583s | 0.000228375s | 0.001098208s |

See [docs/BENCHMARK_FINDINGS.md](docs/BENCHMARK_FINDINGS.md) for the full
matrix, measurement caveats, simdgroup results, and reproduction commands.

## Architecture

```text
CPU caller
  |
  | validates public layout and workload shape
  v
MetalProofPlanner / reusable execution plans
  |
  | selects specialized kernels and reusable buffers
  v
Metal command buffer
  |
  | hash -> reduce -> transcript -> challenge -> fold
  v
GPU-resident intermediate state
  |
  | final public material only
  v
CPU result / optional CPU verification
```

Important runtime pieces:

- `MetalContext` owns device discovery, capability detection, pipeline lookup,
  nonuniform dispatch helpers, and optional binary archive serialization.
- `KernelSpec` keys pipeline variants by family, function constants, and queue
  mode instead of plain function names.
- `SharedUploadRing` stages repeated public uploads without reallocating shared
  buffers.
- `ResidencyArena` keeps private scratch and transcript state in reusable Metal
  buffers.
- `PlanDatabase` persists correctness-gated tuning rows and observed drift in
  SQLite.

See [docs/PLANNER.md](docs/PLANNER.md) for the planner contract and eligibility
rules.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `Sources/AppleZKProver/SHA3Oracle.swift` | CPU SHA3-256 and Keccak-256 reference code |
| `Sources/AppleZKProver/MerkleOracle.swift` | CPU Merkle oracle |
| `Sources/AppleZKProver/SHA3BatchHasher.swift` | GPU fixed-rate SHA3-256 batching |
| `Sources/AppleZKProver/Keccak256BatchHasher.swift` | GPU fixed-rate Keccak-256 batching |
| `Sources/AppleZKProver/KeccakF1600PermutationBatcher.swift` | GPU Keccak-F1600 permutation batches |
| `Sources/AppleZKProver/MerkleCommitter.swift` | GPU SHA3 Merkle commitments |
| `Sources/AppleZKProver/M31VectorArithmetic.swift` | GPU M31 vector arithmetic |
| `Sources/AppleZKProver/M31DotProduct.swift` | GPU M31 dot-product reductions |
| `Sources/AppleZKProver/SumcheckOracle.swift` | CPU M31 sum-check chunk oracle |
| `Sources/AppleZKProver/Planner/` | Planning, tuning, transcript, and residency runtime |
| `Sources/AppleZKProver/Resources/HashMerkleKernels.metal` | Metal kernels |
| `Sources/zkmetal-bench/main.swift` | Benchmark and smoke-test CLI |
| `Tests/AppleZKProverTests/` | CPU/GPU differential and planner tests |
| `BenchmarkBaselines/` | Checked-in reproducibility artifacts |
| `docs/` | Planner, roadmap, benchmark, security, and cryptography notes |

## Development Commands

```bash
swift build
swift test
swift test -c release -Xswiftc -Osize
swift run zkmetal-bench --suite --leaves 256 --iterations 1 --warmups 0 --no-pipeline-archive --json
swift run zkmetal-bench --m31-dot-product --elements 4097 --iterations 1 --warmups 0 --no-pipeline-archive --json
```

The `-Osize` release test mode is intentional for the current benchmark host:
the default SwiftPM release optimization mode has reproduced a Swift optimized
throwing-codegen issue in this codebase. This is tracked as a measurement
constraint, not a cryptographic relaxation.

## Security Posture

AppleZKProver is not production proving software yet. The implemented slice is
designed to be testable and conservative:

- CPU oracles define expected results for the supported hash, Merkle,
  permutation, transcript, M31 vector, M31 dot-product, and M31 sum-check paths.
- Malformed public layout parameters return typed `AppleZKProverError` values
  where they cross public API boundaries.
- Reusable plans expose explicit buffer clearing for private workloads.
- Shared upload slots clear unused tails before reuse.
- Strided GPU result buffers clear unwritten padding before returning `Data`.
- A production verifier must remain CPU-only and deterministic.

See [docs/SECURITY_MODEL.md](docs/SECURITY_MODEL.md) for assets, attacker model,
trust boundaries, current guarantees, and pre-production review gates.

## Roadmap

The roadmap is deliberately staged:

1. Measurement discipline and reproducible JSON baselines.
2. Runtime substrate: reusable plans, binary archives, upload rings, residency
   arenas, and device-scoped tuning.
3. Hash and Merkle leadership on Apple GPUs.
4. Prime-field lanes for transparent proving systems.
5. Codeword, FRI, and PCS kernels that feed commitments without CPU readback.
6. Wider sum-check and GKR integration.
7. A documented end-to-end transparent proof with stable vectors and an
   independent CPU verifier.

The full plan and exit gates are in [docs/ROADMAP.md](docs/ROADMAP.md).

## Engineering Rules

- No performance claim without JSON benchmark output.
- No new cryptographic API without a CPU oracle.
- No GPU kernel without deterministic and randomized differential tests.
- No secret-bearing buffer reuse without an explicit clearing policy.
- No protocol shortcut without domain separation and transcript tests.
- No production security claim before external cryptography review.

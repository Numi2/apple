# AppleZKProver

`AppleZKProver` is a first-stage SwiftPM package for Apple-silicon-first transparent proving workloads.

The implemented vertical slice is intentionally narrow and throughput-oriented:

- CPU oracle: full SHA3-256, Keccak-256, and SHA3 Merkle root computation.
- GPU batch hash: SHA3-256 and Keccak-256 for fixed-size rate-bounded messages of length `0...136` bytes, with exact-width kernels for common `32`, `64`, `128`, and full-rate `136` byte prover inputs.
- GPU Merkle commit: hash leaves on GPU, reduce internal layers on GPU, fuse small upper-tree reductions in threadgroup memory, and read back only the final 32-byte root. A 32-byte lower-subtree kernel is available as an explicit benchmark option while autotuning data is collected.
- GPU sum-check chunk: canonical M31 lane chunks execute round evaluation, transcript absorb, challenge squeeze, and fold/halve in one command buffer, with only final proof material read back.
- Runtime: Apple GPU family detection, nonuniform dispatch, reusable hash/Merkle execution plans, in-process pipeline caching, and optional Metal binary archive persistence.
- Bench harness: repeated warmup/measurement runs with text or JSON output.

## Why this exact slice

This package is the first concrete lane from a larger prover stack:

1. Hash / Merkle engine first.
2. Streaming encoder / matrix engine second.
3. Batched field arithmetic third.
4. Sum-check fold kernels fourth.
5. Transparent protocol layer only after the above are stable.

The code therefore optimizes for large regular kernels, GPU residency, and low synchronization count.

## Current constraints

- Platform target: macOS 14+.
- Metal path: Apple-silicon Macs preferred.
- Hash path currently supports fixed-size SHA3-256 and Keccak-256 messages up to one full SHA3-256 rate block (`<= 136` bytes).
- Merkle builder currently expects a power-of-two leaf count.
- Internal node hashing is specialized to `32-byte left || 32-byte right -> 32-byte parent`.
- Sum-check chunk execution currently supports canonical M31 inputs with power-of-two lane counts and multi-block transcript absorb.

These constraints are deliberate for the first high-value commit path.

## Package layout

- `Sources/AppleZKProver/SHA3Oracle.swift`: CPU SHA3-256 oracle.
- `Sources/AppleZKProver/MerkleOracle.swift`: CPU Merkle oracle.
- `Sources/AppleZKProver/MetalContext.swift`: device discovery, shader compilation, dispatch helpers.
- `Sources/AppleZKProver/SHA3BatchHasher.swift`: fixed-size one-block SHA3 batch hashing, fixed-width kernel selection, and reusable hash plans.
- `Sources/AppleZKProver/Keccak256BatchHasher.swift`: fixed-size one-block Keccak-256 batch hashing with the same reusable-plan discipline.
- `Sources/AppleZKProver/MerkleCommitter.swift`: GPU leaf hashing + GPU tree reduction with reusable raw-leaf commit plans, benchmark-selectable 32-byte leaf subtree fusion, and upper-tree fusion.
- `Sources/AppleZKProver/SumcheckOracle.swift`: CPU M31 sum-check chunk oracle used for deterministic differential checks.
- `Sources/AppleZKProver/Planner/`: `MetalProofPlanner`, specialization keys, SQLite plan history, residency arena, execution-plan records, and GPU transcript engine.
- `Sources/AppleZKProver/Resources/HashMerkleKernels.metal`: SHA3 and Merkle Metal kernels.
- `Sources/zkmetal-bench/main.swift`: bench / smoke-test CLI.
- `docs/ROADMAP.md`: phased development plan and exit gates.
- `docs/SECURITY_MODEL.md`: current guarantees, threat model, and required security gates.

## Quick start

```swift
import Foundation
import AppleZKProver

let context = try MetalContext()
let committer = SHA3MerkleCommitter(context: context)

let leafCount = 1 << 12
let leafLength = 32
let leaves = Data((0..<(leafCount * leafLength)).map { UInt8(truncatingIfNeeded: $0) })

let commitment = try committer.commitRawLeaves(
    leaves: leaves,
    leafCount: leafCount,
    leafStride: leafLength,
    leafLength: leafLength
)

print(commitment.root.hexString)
```

## Build and test

```bash
swift test
swift run zkmetal-bench --leaves 16384 --leaf-bytes 32
swift run zkmetal-bench --leaves 16384 --leaf-bytes 32 --iterations 10 --json
swift run zkmetal-bench --leaves 16384 --leaf-bytes 32 --hash keccak-256 --json
swift run zkmetal-bench --leaves 16384 --leaf-bytes 32 --merkle-subtree-leaves 64 --json
swift run zkmetal-bench --suite --leaves 16384 --iterations 5 --json
```

`zkmetal-bench` uses a device-scoped Metal binary archive under `.build/applezkprover-pipeline-archives/` by default. Pass `--no-pipeline-archive` to disable it, or `--pipeline-archive PATH` to choose an explicit archive path.

`--suite` runs the supported fixed-rate matrix for SHA3-256 and Keccak-256 over leaf lengths `0`, `32`, `64`, `128`, `135`, and `136`. Use `--suite-leaf-bytes` and `--suite-hashes` to narrow a reproducibility run while preserving the same JSON schema.

The lower Merkle subtree kernel is disabled by default because current Apple9 measurements show the upper-tree fusion path is faster for the default 16k x 32-byte benchmark. Use `--merkle-subtree-auto` or `--merkle-subtree-leaves N` to collect device-specific tuning data without changing the library default.

The benchmark constructs reusable hash and Merkle plans before warmup so timed iterations measure command execution and required readback, not avoidable buffer allocation or pipeline creation.

When CPU verification is enabled, any root mismatch is a benchmark failure. The CLI emits the requested text or JSON report first, writes the mismatch summary to stderr, and exits with status `2`.

Reusable plans retain their Metal buffers by design. Call `clearReusableBuffers()` after private-witness workloads when the plan will be reused or released across a security boundary.

CPU Merkle oracle entry points and one-block hash shortcuts throw `AppleZKProverError` for malformed public layout parameters. Internal invariants may still use Swift preconditions, but caller-controlled cryptographic input validation is typed.

Benchmark JSON includes the selected Merkle subtree leaf count, upper-fusion node limit, and device threadgroup memory size so results can be compared across Apple GPU families.

`--hash keccak-256` changes only the standalone batch-hash benchmark. Merkle commitments remain SHA3-256 in this stage so commitment semantics do not change silently. A Keccak-domain Merkle tree should be added as a separate, domain-tagged API when the protocol layer needs it.

`MetalProofPlanner` can run a correctness-gated Merkle short race, persist every Merkle candidate in SQLite, and construct the current GPU-resident M31 sum-check chunk plan. See `docs/PLANNER.md` for the current planner contract and eligibility rules.

## What to build next

The next step is not another protocol wrapper. The next step is a better kernel set:

- a simdgroup-cooperative Keccak path for the fixed-width hash and fused Merkle kernels on Apple7+,
- function-constant-specialized or generated leaf hash kernels for larger common widths beyond the hand-specialized `32`, `64`, `128`, and `136` byte paths,
- a multi-block SHA3 absorb path,
- tuned scalar, simdgroup, and fused sum-check families after the resident scalar chunk has broader randomized test coverage,
- private-buffer upload staging with ring-buffered command submission,
- binary archive caching for pipeline creation,
- streaming codeword / matrix kernels that keep the exact same GPU residency discipline.

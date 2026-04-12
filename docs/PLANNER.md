# MetalProofPlanner

`MetalProofPlanner` owns device-scoped proof-step planning for the GPU resident path. Its first production lane is SHA3 Merkle commitment. The first sum-check lane is a deliberately narrow M31 chunk that proves the transcript/fold residency model before broader protocol integration.

## Current Guarantees

- Pipeline lookup is keyed by `KernelSpec`, not by a plain function name.
- Function constants are part of the specialization key.
- The shader source hash and OS build are part of persisted plan lookup.
- Compiled compute descriptors attach the configured `MTLBinaryArchive`.
- Merkle tuning races whole commitment supersteps, not isolated parent kernels.
- A candidate is timed only after its output matches the CPU Merkle oracle.
- The tuner stores every race candidate in SQLite and marks the measured winner.
- Live observations can update an EMA for a persisted winner and mark the plan stale after sustained relative drift.
- `MetalPlannedMerkleCommitPlan` records live observations automatically when it was built from a persisted winner.
- Upload and final root readback may use shared buffers. Intermediate Merkle state lives in reusable private buffers through `ResidencyArena`.
- `MetalSumcheckChunkPlan` executes `round_eval -> coeff_pack -> transcript_absorb -> challenge_squeeze -> fold_halve` inside one command buffer for the supported M31 chunk shape.
- Sum-check chunk execution reads back only final proof material: the final folded vector, coefficient words, and challenges after the superstep completes.

## Current Merkle Race

The Merkle short race uses:

- one deterministic CPU oracle root for the supplied workload,
- top heuristic candidates after feasibility filtering,
- one untimed differential gate per candidate,
- configurable warmups, defaulting to 2,
- configurable measured runs, defaulting to 5,
- randomized winner validation batches, defaulting to 3, before persistence,
- median GPU time, p95 GPU time, median CPU submit time, readback count, and confidence.

The objective is superstep cost: median GPU time plus median CPU submit time, with p95 GPU time as a tie breaker. Readback count is still stored because future candidates may differ there. Race rows are persisted only after the measured winner passes independent deterministic-random leaf batches against the CPU oracle.

## Honest Eligibility

The planner only races implementations that are currently distinct and correctness-gated. Today that means:

- scalar Merkle commitment,
- binary treelet Merkle commitment for 32-byte leaves, starting at depth 3 and depth 4 where feasible.

Apple7 simdgroup Merkle and tuned sum-check families remain design targets, but they are not eligible for measured winner persistence until their kernels are real cooperative implementations with deterministic and randomized differential tests. This avoids storing misleading records for a label that does not correspond to different GPU work.

## Stores

There are two separate stores:

- Metal binary archives for compiled pipeline functions.
- SQLite plan history for race records and winners.

Plan lookup is keyed by:

```text
device registry ID,
OS build,
stage,
field,
input log2 bucket,
leaf bytes,
arity,
rounds per superstep,
fixed-width case,
shader hash,
protocol hash
```

The database stores all race rows, not only winners, so later drift detection can compare historical alternatives.

## Drift Detection

`PlanDatabase.recordLiveObservation` accepts live GPU and CPU-submit timings for a persisted `PlanRecord`. It maintains an exponential moving average keyed by the same device, workload, shader, protocol, and winning kernel specialization.

The default policy is:

- EMA alpha: 0.2,
- relative drift threshold: 25%,
- minimum samples before stale: 8.

A stale status is a signal to rerun the short race for that workload. It does not silently change the selected plan.

Planned Merkle commits return the drift status beside the commitment through `commitWithObservation`. The convenience `commit` API still returns only the commitment.

## Transcript Path

`TranscriptEngine` now provides GPU command encoders for:

- canonical byte packing,
- Keccak transcript absorb,
- challenge squeeze into field-sized words.

It owns a private transcript-state arena slice. The engine is intentionally low-level: protocol code should chain its encoders inside a command buffer between round evaluation and fold/halve kernels. It should not read coefficients or challenges back to the CPU except through explicit debug taps.

## Current Sum-Check Chunk

`MetalSumcheckChunkPlan` supports one field backend today: canonical M31 elements (`0 <= x < 2^31 - 1`). The transcript absorb path now handles multi-block coefficient byte strings, so the chunk limit is driven by buffer sizing and validation rather than SHA3 rate truncation:

- lane count must be a power of two,
- rounds per superstep must be in `1...log2(laneCount)`,
- public array convenience APIs reject non-canonical M31 input,
- uploaded-buffer APIs assume the caller already populated canonical field elements.

For each round, the GPU writes canonical pair coefficients, packs those `UInt32` words in little-endian transcript order, absorbs them into the private Keccak state, squeezes the next challenge, and folds the vector in private memory. The tests compare final vectors, coefficient logs, and challenges against the independent CPU oracle.

## Research Notes

The implementation follows the relevant Apple Metal boundaries:

- `MTLBinaryArchive` is the persistence mechanism for compiled pipeline functions.
- `MTLFunctionConstantValues` drives per-variant specialization.
- `MTLCommandBuffer.gpuStartTime` and `gpuEndTime` provide GPU interval timing when Metal reports it.

Apple documentation pages currently require JavaScript in a browser, but the canonical API references are:

- https://developer.apple.com/documentation/metal/mtlbinaryarchive
- https://developer.apple.com/documentation/metal/mtlfunctionconstantvalues
- https://developer.apple.com/documentation/metal/mtlcommandbuffer/gpustarttime

## Next Gates

1. Implement a real Apple7 simdgroup Keccak-F1600 family before enabling simdgroup candidates.
2. Add randomized larger-lane sum-check batches and persist eligible sum-check winners once distinct scalar, simdgroup, and fused implementations exist.
3. Add tuned sum-check candidate families only when the scalar resident chunk is stable and the cooperative kernels perform distinct GPU work.

# Circle Domain And Proof Format V1

Status: implementation foundation, not a complete Circle PCS prover/verifier.

This note records the consensus-facing Circle-domain and proof-artifact surface added in
`CircleDomain.swift` and `CircleProofFormat.swift`.

## References

- Circle STARK domain model: circle points form an additive group on `x^2 + y^2 = 1`.
- Stwo's `CircleDomain` defines a domain as a half-coset followed by its conjugate.
- Stwo's canonical coset uses `G_2n + <G_n>` and represents it as
  `G_4n + <G_n/2>` plus the conjugate half.
- Stwo's FRI verifier folds Circle evaluations in bit-reversed Circle-domain order and
  uses the inverse `y` coordinate of the queried Circle point for the first Circle-to-line
  fold.

## Domain

The implemented M31 Circle constants are:

- M31 modulus: `2^31 - 1`
- Circle group log order: `31`
- M31 Circle generator: `(2, 1268011823)`
- Supported canonical Circle-domain log size: `1...30`

`CircleDomainDescriptor.canonical(logSize:)` is the only descriptor accepted by the V1
binary proof codec. It fixes:

- half-coset: `G_4n + <G_n>` with `halfCosetLogSize = logSize - 1`
- domain order: half-coset points, then conjugate half-coset points
- resident proof storage order: bit-reversed Circle-domain order

The descriptor codec binds version, modulus, group log order, generator, domain log size,
half-coset initial index, half-coset log size, and storage order. Decoding rejects trailing
bytes, unknown storage order, noncanonical cosets, and mismatched constants.

## Layout

The implemented layout helpers are:

- Circle-domain natural index to coset index
- coset index to Circle-domain natural index
- coset-natural order to Circle-domain natural order
- coset-natural order to bit-reversed Circle-domain order
- bit-reversed query folding index

For `logSize = 3`, Circle natural order over the canonical coset is:

```text
[1, 5, 9, 13, 15, 11, 7, 3] * 2^27
```

The coset-to-Circle index map is:

```text
[0, 2, 4, 6, 7, 5, 3, 1]
```

The coset-natural to bit-reversed Circle-domain permutation is:

```text
[0, 7, 4, 3, 2, 5, 6, 1]
```

## First Circle FRI Fold

`CircleDomainOracle.firstFoldInverseYTwiddles(for:)` emits one QM31-embedded M31 value
per adjacent pair in bit-reversed Circle-domain order:

```text
p = domain.at(bitReverse(pairIndex << 1, logSize))
twiddle = p.y^-1
```

`CircleFRIFoldOracle.foldCircleIntoLine` reuses the existing QM31 radix-2 fold formula
with those inverse-`y` twiddles. This is the CPU oracle surface for migrating the current
linear fold plan to a true Circle first layer.

`CircleFRIFoldPlan` is the Metal first-fold execution surface. It accepts only canonical
bit-reversed Circle domains, precomputes the public inverse-`y` twiddle vector once at plan
construction, keeps that vector in a Metal buffer, and then executes either:

- CPU-upload convenience folds with oracle verification
- resident folds from an existing evaluation buffer directly into an output buffer

The resident path does not read the input layer or folded output back to CPU. Tests compare
both paths against `CircleFRIFoldOracle`.

`zkmetal-bench --circle-fri-fold` measures this path and emits schema v1 JSON with the
canonical domain log size, storage order, CPU/GPU digest match, folded-elements/sec, and
input bandwidth. The first checked-in release baseline is
`BenchmarkBaselines/apple-m4-circle-fri-fold-2026-04-13.json`.

## Binary Proof Format

`CirclePCSFRIProofV1` is a strict binary container with:

- proof version
- transcript version
- canonical Circle-domain descriptor bytes
- security parameters: log blowup factor, query count, folding step, grinding bits
- 32-byte public-input digest
- 32-byte Merkle commitments
- canonical QM31 final layer
- query openings with layer index, pair index, left/right leaf indices, left/right QM31
  values, and left/right 32-byte sibling paths

All integer fields are little-endian. All variable-length sections are length-prefixed or
count-prefixed. Decoding rejects trailing bytes, malformed lengths, noncanonical QM31 limbs,
bad commitment/hash lengths, malformed query shape, non-pair query openings, and mismatches
between declared query count and provided queries.

The format is intentionally stricter than the current developer JSON. It is suitable for
stable vectors. The currently implemented verifier semantics cover a multi-layer Circle
FRI artifact whose first round is Circle-to-line and whose remaining rounds are line-domain
radix-2 folds.

## Multi-Layer Proof And Verification

`CircleFRIProofBuilderV1` builds deterministic CPU proofs for one or more FRI rounds:

1. Commit the bit-reversed Circle evaluation layer as 16-byte QM31 SHA3 Merkle leaves.
2. Derive the first QM31 folding challenge from the V1 transcript.
3. Fold the Circle layer into the line layer with inverse-`y` twiddles.
4. For each later round, commit the current line layer, derive the next challenge, and fold
   adjacent `x, -x` pairs with inverse-`x` twiddles.
5. Bind the final layer in the transcript and sample initial query pair indices.
6. Emit left/right Merkle openings for each sampled fold pair at every committed layer.

The line-domain schedule is generated by `CircleFRILayerOracleV1`: after the first Circle
fold, each adjacent line pair is checked as `x, -x`, and the next domain coordinate is
`2x^2 - 1`.

`CircleFirstFoldPCSProofBuilderV1` remains as a compatibility wrapper over
`CircleFRIProofBuilderV1` with `roundCount = 1`.

`CirclePCSFRIProofVerifierV1.verify(proof:publicInputs:)` is independent of prover helper
state. It checks the public-input digest, strict proof shape, transcript-derived challenge
and query pairs, left/right Merkle paths for every layer, first Circle fold arithmetic,
later line-fold arithmetic, cross-layer query consistency, and final-layer values. It
rejects tampered commitments, openings, final-layer values, public inputs, malformed
encodings, noncanonical field elements, and invalid line-domain pair schedules.

This is now a complete CPU verifier for the implemented multi-layer FRI artifact. It is not
yet a complete PCS verifier for polynomial commitments because Circle FFT/codeword
generation, committed polynomial evaluation semantics, and resident GPU query extraction are
not yet integrated.

## Transcript

`CircleFRITranscriptV1` frames and absorbs:

- protocol domain string
- proof version
- transcript version
- M31 modulus
- Circle generator
- canonical domain descriptor bytes
- security parameters and nominal security bits
- public-input digest
- each Merkle commitment before its challenge
- final layer bytes
- query request count and initial pair count

Challenges are squeezed as four M31 limbs per QM31 element using existing SHA3 transcript
rejection sampling. Query pair indices are squeezed modulo half the Circle domain size.

Tests mutate domain, security parameters, commitments, public inputs, and final layer to
verify transcript sensitivity for every currently bound field group.

## Current Boundary

Implemented:

- canonical Circle-domain descriptor
- M31 Circle point/index/coset arithmetic
- layout and bit-reversal policy helpers
- first Circle-fold inverse-`y` twiddle oracle
- CPU Circle-to-line first fold oracle
- Metal Circle first-fold plan with resident evaluation/output buffers
- Circle first-fold benchmark mode and Apple M4 baseline
- multi-layer Circle FRI domain/twiddle oracle
- multi-layer Circle FRI proof builder
- independent multi-layer verifier with left/right Merkle pair openings
- pinned deterministic first-fold and three-round proof digest vectors
- canonical QM31 binary encoding
- strict V1 proof container
- V1 transcript framing and challenge/query derivation
- unit tests for layout, encoding rejection, transcript binding, CPU/GPU first-fold parity,
  and resident layout rejection

Not yet implemented:

- Metal-resident Circle-domain/twiddle generation
- GPU Circle FFT/codeword command plans
- full resident Circle FRI fold chain
- resident query extraction from GPU Merkle/fold buffers
- independent full Circle PCS verifier with committed polynomial semantics
- checked-in reproducible complete PCS proof corpus
- end-to-end prover command plan and benchmark baselines
- sumcheck/GKR integration into the same proof artifact

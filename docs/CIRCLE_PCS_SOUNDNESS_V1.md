# Circle PCS/FRI Soundness V1

Status: conservative implementation note for the implemented Circle FFT-basis
PCS/FRI slice. This is not an external cryptography review and not a complete
proof-system security proof.

## Scope

The implemented verifier-facing surface is:

- `CirclePCSFRIStatementV1`: a public statement consisting of one parameter set
  and one structured `CirclePCSFRIPolynomialClaimV1`.
- `CirclePCSFRIContractVerifierV1`: the strict public verifier contract for
  canonical `CirclePCSFRIProofV1` bytes under that statement.
- `CirclePCSFRIParameterSetV1.conservative128`: the only built-in
  production-facing profile at this version.

The contract covers the implemented Circle codeword model `P(x) + yQ(x)` over
QM31 coefficients, canonical bit-reversed Circle domains, SHA3-256 Merkle
commitments over canonical QM31 leaves, Fiat-Shamir transcript binding, FRI
fold consistency, final terminal-layer shape, and claimed first-layer
evaluation openings.

It does not cover AIR trace generation, AIR semantic verification, GKR
verification, external review, side-channel resistance, malicious GPU/driver
behavior, or fused/tiled performance claims. `ApplicationProofV1` composes this
PCS verifier with the implemented M31 sum-check chunk verifier, but it does not
extend this PCS soundness note into an end-to-end AIR/GKR theorem.

## Parameter Profile

`CirclePCSFRIParameterSetV1.conservative128` fixes:

| Field | Value |
| --- | ---: |
| `profileID` | `circle-pcs-fri-v1-conservative-128` |
| `logBlowupFactor` | 4 |
| `queryCount` | 36 |
| `foldingStep` | 1 |
| `grindingBits` | 0 |
| `targetSoundnessBits` | 128 |
| nominal query bits | 144 |

For a canonical domain with `domain.logSize = n`, the contract requires:

- `n > 4`,
- `roundCount = n - 4`,
- `finalLayer.count = 2^4`,
- all final-layer values are identical,
- `xCoefficients.count + yCoefficients.count <= domain.size / 16`.

The nominal 144-bit figure is the simple `logBlowupFactor * queryCount`
budget. The public target is stated as 128 bits to leave margin for concrete
FRI constants, composition details, and implementation conservatism. This repo
does not claim a mechanized or externally reviewed theorem that the concrete
implementation achieves exactly 128 bits against every adversary. It claims
that the public verifier enforces this conservative profile and does not accept
developer/test parameter choices as production statements.

`grindingBits = 0` is intentional for this production-facing profile. The V1
proof format can verify nonzero grinding through an optional 8-byte nonce and a
leading-zero SHA3 transcript target, but this profile does not assign grinding
credit until that parameter choice receives separate review. Lower-level
developer artifacts may use verifier-checked nonzero grinding; the public
contract profile does not.

## FRI Argument

The verifier accepts only if all of the following hold:

1. The proof domain is the statement domain and is the canonical bit-reversed
   Circle-domain descriptor.
2. The proof security parameters exactly match the selected profile.
3. The number of committed layers equals `domain.logSize - logBlowupFactor`.
4. The final layer has the profile terminal size and is constant.
5. The transcript re-derives every folding challenge and query pair from the
   domain, security parameters, public-input digest, Merkle commitments, final
   layer, and any required grinding nonce.
6. Every sampled pair has valid SHA3-256 Merkle openings against the committed
   root for that layer.
7. The first sampled fold uses the Circle inverse-`y` twiddle schedule for the
   queried canonical Circle points.
8. Later sampled folds use the checked line-domain `x, -x` schedule and
   inverse-`x` twiddles.
9. The opened value in the next layer equals the fold result from the previous
   opened pair.
10. The final queried folded values match the terminal final layer.

The usual FRI intuition applies: a prover that commits to a word far from the
claimed bounded-degree space must evade enough independently sampled fold-path
checks to pass. The implementation samples 36 initial pair positions after all
layer commitments and the final layer have been bound into the transcript.
Because the profile uses blowup factor 16 and checks a terminal constant layer,
the nominal query budget is 144 bits before conservative slack.

This note deliberately avoids a stronger statement such as "proved 128-bit
soundness" without a reviewed concrete analysis of the exact Circle FRI theorem
constants and composition loss for this implementation.

## PCS Semantics

The contract verifier is stricter than the lower-level artifact verifier.

`CirclePCSFRIProofVerifierV1` checks only the internal FRI artifact and Merkle
openings against a supplied public-input digest. It is useful as a building
block but is not the final public PCS surface.

`CirclePCSFRIPolynomialVerifierV1` additionally checks the structured
polynomial claim:

- the proof domain equals the claim domain,
- the public-input digest is the digest of the structured claim,
- the claimed storage indices map to the claimed Circle points,
- CPU evaluation of `P(x) + yQ(x)` matches every claimed value,
- claimed first-layer openings verify against the first commitment root,
- coefficient counts fit the proof's blowup factor.

`CirclePCSFRIContractVerifierV1` is the public V1 PCS contract. It adds the
fixed profile, exact round count, terminal final-layer shape, and a combined
coefficient budget for the committed polynomial. A proof that is internally
consistent under developer parameters can still be rejected by the contract.
The checked-in corpus includes this rejection vector.

`CirclePCSFRIArtifactManifestV1.current` is the code-level scope manifest for this
boundary. It records that the artifact includes only the Circle PCS/FRI slice,
does not include witness/AIR, sumcheck, or GKR output inside the PCS proof
itself, supports the narrow resident monomial coefficient witness-column to
Circle FFT-basis producer, does not use fused/tiled codeword-to-commitment scheduling, and
supports verifier-checked nonzero grinding.

## Fiat-Shamir Binding

`CircleFRITranscriptV1` uses SHA3-256 transcript frames. The verifier replays
the transcript from public data instead of trusting prover-supplied challenges
or query indices.

The transcript binds:

- protocol domain string,
- proof and transcript versions,
- M31 modulus and Circle generator,
- canonical domain descriptor bytes,
- security parameters and nominal security bits,
- structured public-input digest,
- each Merkle commitment before the corresponding challenge,
- final-layer bytes before query sampling,
- an 8-byte grinding nonce and grinding target frame when `grindingBits > 0`,
- query request count and initial pair-count range.

QM31 challenges are squeezed by rejection-sampling four M31 limbs from the
SHA3 transcript stream. Query pair indices are squeezed after final-layer
binding, after any required grinding nonce has been absorbed and checked, and
reduced modulo the initial pair count.

The Fiat-Shamir use is modeled as a random oracle for:

- per-round QM31 fold challenges,
- grinding target checks for lower-level artifacts that request nonzero
  `grindingBits`,
- transcript-sampled query pair indices.

The same SHA3-256 primitive is also used as a collision-resistant digest for
public-input binding and Merkle commitments. The implementation uses explicit
frame tags so these roles are domain-separated at the byte level.

## Merkle Assumptions

Layer commitments are SHA3-256 Merkle roots over canonical 16-byte QM31 leaves.
Each internal node hashes `32-byte left || 32-byte right` with SHA3-256.

Verifier security relies on SHA3-256 collision resistance and second-preimage
resistance for:

- binding a committed layer root to one value at a sampled leaf index,
- binding each sibling path to the advertised root,
- preventing a proof from reusing one root for two inconsistent sampled paths.

Merkle openings include explicit leaf indices and fixed 32-byte sibling hashes.
The verifier rejects malformed path lengths, noncanonical QM31 leaves, and hash
length mismatches.

## Field And Domain Assumptions

The implemented field/domain assumptions are:

- base field M31 with modulus `2^31 - 1`,
- Circle group equation `x^2 + y^2 = 1`,
- fixed M31 Circle generator `(2, 1268011823)` with log order 31,
- canonical half-coset domain descriptor,
- bit-reversed Circle-domain storage order,
- QM31 represented over `CM31[U] / (U^2 - 2 - i)`,
- canonical 31-bit limbs for every serialized M31/QM31 value.

The verifier rejects noncanonical domain descriptors and noncanonical field
encodings at public proof boundaries. Resident GPU buffers are not proof inputs
to the verifier; verifier acceptance depends only on canonical proof bytes and
the public statement.

## Reproducible Corpus

`Tests/AppleZKProverTests/Resources/CirclePCSFRIProofCorpusV1.json` pins a
small complete PCS/FRI contract corpus for this profile:

- one accepted proof with canonical bytes and expected SHA3-256 proof digest,
- a terminal final-layer tamper rejection,
- a developer-parameter proof rejected by the contract even though the lower
  polynomial verifier accepts it,
- a claimed-opening Merkle path tamper rejection.

`CircleDomainTests/testCirclePCSProofCorpusV1PinsCanonicalBytesDigestsAndRejections`
loads the corpus, reconstructs the public statement, checks exact proof byte
counts and digests, checks codec re-encoding stability, and verifies each
expected accept/reject result.

## Open Boundaries

The following remain outside the V1 soundness claim:

- AIR/sumcheck/GKR output into Circle FFT-basis coefficients beyond resident
  monomial coefficient witness columns,
- AIR semantic verification, GKR verification, and AIR-to-sum-check reduction,
- a reviewed end-to-end proof-system theorem for an application statement,
- a reviewed production profile that assigns nonzero grinding credit,
- GPU-resident canonicality checks for private witness buffers,
- fused/tiled codeword-to-commitment performance claims,
- side-channel resistance on shared hardware,
- external cryptography audit.

# Application Proof V1

Status: implemented application-level proof envelope for the concrete verifier
surfaces that exist today. It binds witness, AIR, and GKR public digests, verifies
one M31 sum-check chunk proof, and verifies one Circle PCS/FRI contract proof.
`ApplicationProofV1` by itself is not a semantic AIR verifier, a GKR verifier,
or a witness-to-trace compiler.

The default verifier scope is the implemented component slice. A separate
`fullWitnessAIRGKRTheorem` scope is exposed so callers can ask for the stronger
claim explicitly; `ApplicationProofV1` returns false for that scope because
the proof bytes do not contain the AIR, witness trace, AIR-to-sum-check
reduction, or GKR material needed to check that theorem.

`ApplicationTheoremVerifierV1` is the separate public sidecar path. It accepts
an `ApplicationProofV1` plus an `ApplicationWitnessTraceV1`, `AIRDefinitionV1`,
and `GKRClaimV1`, then checks the bound digests, synthesizes the AIR trace,
verifies AIR constraints, checks the AIR-to-sum-check vector digest, and
evaluates the layered arithmetic GKR claim on CPU. This sidecar path is useful
for deterministic validation and fixtures, but it is not zero-knowledge and it
is not a succinct proof.

`ApplicationPublicTheoremArtifactV1` packages that public sidecar theorem into
one decodable artifact. It carries the application statement, `ApplicationProofV1`,
public witness trace, AIR definition, and GKR claim, then verifies the same
end-to-end public theorem without requiring out-of-band sidecar inputs. This is
a public witness artifact, not a zero-knowledge or succinct AIR/GKR proof.

## Scope

`ApplicationProofV1` is the first final proof artifact that composes the
implemented PCS and sum-check verifier surfaces under one application statement.
The public statement is `ApplicationProofStatementV1`; the proof bytes are
encoded by `ApplicationProofCodecV1`.

The statement binds:

- an application identifier,
- a 32-byte witness commitment digest,
- a 32-byte AIR definition digest,
- a 32-byte GKR claim digest,
- an `M31SumcheckStatementV1`,
- a `CirclePCSFRIStatementV1`.

The proof contains:

- the SHA3-256 digest of the application statement,
- an `M31SumcheckProofV1`,
- a `CirclePCSFRIProofV1`.

The verifier accepts only if the statement digest matches, the M31 sum-check
proof verifies against the statement's sum-check claim, and the Circle PCS/FRI
contract proof verifies against the statement's PCS claim.

`ApplicationProofVerifierV1.verificationReport` returns the per-boundary
booleans used by the scope checks. `verify(proof:statement:)` and the
`implementedPCSAndSumcheckSlice` scope accept the implemented slice. The
`fullWitnessAIRGKRTheorem` scope and `verifyEndToEndApplicationTheorem` return
false for `ApplicationProofV1` proof bytes alone because those bytes do not
carry the public sidecars required for the theorem check.

`ApplicationProofBuilderV1.prove` is a deterministic CPU helper that builds the
PCS proof from the PCS statement before assembling the application artifact.
`ApplicationProofBuilderV1.assemble` accepts an already-produced PCS proof, such
as one emitted by the resident Circle prover, and verifies both subproofs before
returning the final application proof.

## Sum-Check Component

`M31SumcheckProofV1` is a narrow proof for the implemented M31 chunk shape. It
serializes the coefficient log, transcript challenges, and final folded vector
from `SumcheckOracle.m31Chunk`.

The verifier independently checks:

- the first coefficient slice matches the initial evaluation-vector digest,
- the final vector matches the final-vector digest,
- every challenge is rederived from the framed transcript,
- every next coefficient slice is the fold of the previous slice,
- the final folded vector is the advertised final vector.

This chunk proof intentionally reveals the initial evaluation vector as the
first coefficient slice. It is not zero-knowledge, and it is not by itself a
full AIR constraint-system sum-check. The application statement can bind an AIR
definition digest, but this version does not prove that the sum-check vector was
produced from that AIR. `M31SumcheckManifestV1.current` records these facts as
machine-checkable flags.

`M31SumcheckVerificationReportV1` is the statement-class guardrail for this
component. Its accepted scope is
`revealedEvaluationVectorFoldingTrace`. The stronger
`fullMultilinearSumcheck`, `airConstraintSumcheck`, and
`zeroKnowledgeAIRConstraintSumcheck` scopes remain false unless future proof
data verifies those exact relations. `ApplicationProofVerificationReportV1`
threads that M31 report through as `m31SumcheckReport` and
`m31SumcheckClaimScope`, so application callers can reject attempts to treat the
current chunk transcript as a full AIR sum-check.

## PCS Component

The PCS component is the existing `CirclePCSFRIContractVerifierV1` surface. It
checks the selected parameter set, canonical Circle domain, terminal final
layer shape, transcript binding, Merkle openings, structured polynomial claim,
and claimed first-layer evaluation openings.

The application proof does not weaken the PCS contract. It embeds the Circle
PCS/FRI proof bytes and verifies them against the `CirclePCSFRIStatementV1`
inside the application statement.

## Public Sidecar Theorem

`ApplicationTheoremVerifierV1` provides a non-ZK theorem check when the caller
supplies public sidecar material:

- `ApplicationWitnessTraceV1` is a column-major public M31 witness trace.
- `ApplicationWitnessLayoutV1` is a named public M31 column layout. It validates
  unique names, uniform row counts, and canonical field values, then produces
  ordered `ApplicationWitnessTraceV1` values for arbitrary AIR column orderings.
- `WitnessToAIRTraceProducerV1` converts those columns into
  `AIRExecutionTraceV1`.
- `AIRDefinitionV1` contains transition and boundary polynomial constraints
  over current and next trace rows.
- `AIRSemanticVerifierV1` evaluates every AIR constraint over the trace.
- `AIRToSumcheckReductionV1` computes the canonical AIR constraint-evaluation
  vector, pads it to the current M31 chunk shape, and checks that the
  `M31SumcheckStatementV1.initialEvaluationDigest` binds that vector.
- `GKRClaimV1` is a layered M31 arithmetic-circuit claim; `GKRSemanticVerifierV1`
  evaluates the circuit and checks the claimed outputs.
- `AIRTraceToCirclePCSWitnessV1` is a CPU bridge from an already-produced public
  AIR trace to one or more `CirclePCSFRIPolynomialClaimV1` chunks. It packs up
  to four M31 AIR columns into each QM31 polynomial, interpolates over the
  canonical Circle first half-domain, and emits claimed row openings using the
  existing PCS claim type. This does not move AIR semantics into the PCS proof.
- `AIRTraceCirclePCSProofBundleBuilderV1` builds one ordinary
  `CirclePCSFRIStatementV1` / `CirclePCSFRIProofV1` pair per AIR trace chunk,
  and `AIRTraceCirclePCSProofBundleVerifierV1` verifies those PCS proofs and can
  rederive the chunk witness from the public AIR trace. This is a sidecar bundle
  of committed-polynomial proofs, not a batch PCS protocol and not an AIR proof.
- `AIRTraceCirclePCSProofBundleCodecV1` gives that ordered sidecar bundle a
  strict binary encoding; decoders reject trailing bytes and malformed witness
  layout metadata. `AIRTraceCirclePCSProofBundleDigestV1` hashes the
  domain-separated encoded bundle for reproducible fixture and artifact binding.

`ApplicationTheoremManifestV1.current` records the exact scope: this path
verifies witness-to-AIR trace production, AIR semantics, AIR-to-sum-check
reduction, and GKR claim semantics when sidecars are provided. Its open
boundaries are succinct AIR/GKR proof generation and zero-knowledge.

## Public Theorem Artifact

`ApplicationPublicTheoremArtifactV1` is the self-contained public form of the
sidecar theorem. It includes:

- an `ApplicationProofStatementV1`,
- an `ApplicationProofV1`,
- an `ApplicationWitnessTraceV1`,
- an `AIRDefinitionV1`,
- a `GKRClaimV1`.

`ApplicationPublicTheoremBuilderV1.prove` performs the public witness-to-AIR
trace production, rejects AIR traces that do not satisfy the supplied AIR,
rejects false GKR claims, computes the canonical AIR constraint-evaluation
vector, builds the M31 sum-check chunk proof over that vector, and assembles the
application proof. `ApplicationPublicTheoremArtifactCodecV1` gives the artifact
a strict binary encoding; decoders reject trailing bytes and malformed sidecar
layouts.

`ApplicationPublicTheoremArtifactManifestV1.current` records the exact stronger
public scope: the artifact is self-contained for public theorem verification,
but it is not zero-knowledge and it is not a succinct AIR/GKR proof.

`ApplicationPublicTheoremTracePCSArtifactV1` is an additive stricter artifact
for public trace-commitment fixtures. It wraps an
`ApplicationPublicTheoremArtifactV1` together with an
`AIRTraceCirclePCSProofBundleV1`. Its verifier checks the public theorem,
verifies every trace PCS proof in the bundle, rederives the bundle witness from
the public AIR trace, and requires the application proof's PCS proof/statement
pair to appear inside the trace bundle. This still does not move AIR semantics
into `CirclePCSFRIProofV1`; it binds the two public verification surfaces inside
one strict artifact. `ApplicationPublicTheoremTracePCSArtifactCodecV1` and
`ApplicationPublicTheoremTracePCSArtifactDigestV1` provide strict bytes and a
domain-separated digest for that combined artifact.

## Reproducible Corpus

`Tests/AppleZKProverTests/Resources/ApplicationProofCorpusV1.json` pins a
small complete application proof fixture:

- one accepted proof with canonical bytes and expected SHA3-256 proof digest,
- a statement-digest mismatch rejection,
- a sum-check challenge tamper rejection,
- a Circle PCS terminal final-layer tamper rejection.

`CircleDomainTests/testApplicationProofCorpusV1PinsCanonicalBytesDigestsAndRejections`
reconstructs the public statement from the JSON fixture, checks exact proof
byte counts and digests, checks codec re-encoding stability, verifies the
accepted proof, and rejects every tamper vector.

`Tests/AppleZKProverTests/Resources/ApplicationPublicTheoremArtifactCorpusV1.json`
pins the self-contained public theorem artifact contract:

- deterministic public witness, AIR, GKR, and PCS inputs,
- expected artifact, proof, statement, witness, AIR, GKR, and sum-check digests,
- a public witness sidecar mismatch rejection,
- a false GKR claim whose digest is correctly bound but whose semantics fail,
- an invalid AIR trace whose AIR-to-sum-check reduction is correctly bound but
  whose AIR semantics fail,
- a trailing-byte decoder rejection.

`ApplicationTheoremTests/testApplicationPublicTheoremArtifactCorpusV1PinsCanonicalDigestsAndRejections`
reconstructs the artifact from the JSON fixture, checks the stable digests,
checks strict codec round trips, verifies the accepted artifact, and rejects
every semantic tamper vector.

## Manifest

`ApplicationProofManifestV1.current` is the machine-checkable scope record for
this final artifact. It records that V1:

- includes a final application artifact,
- binds witness commitment, AIR definition, and GKR claim digests,
- verifies the narrow M31 sum-check chunk proof,
- verifies the Circle PCS/FRI contract proof,
- does not verify AIR semantics,
- does not verify GKR,
- does not produce witness-to-AIR traces,
- does not verify AIR-to-sum-check reductions,
- does not prove the end-to-end application theorem,
- is not zero-knowledge because the M31 chunk reveals the initial evaluation
  vector.

The open boundaries are intentionally part of the manifest instead of prose
only, so tests and downstream tooling can reject overbroad claims.

## Security Boundary

The accepted V1 claim is:

```text
Given this public application statement, the proof contains a valid M31
sum-check chunk transcript for the stated chunk digest and a valid Circle
PCS/FRI contract proof for the stated PCS claim, and the proof is bound to the
statement's witness/AIR/GKR digests.
```

The V1 claim is not:

```text
The witness satisfies the AIR, the AIR reduction produced the sum-check vector,
or the GKR claim is true.
```

Those stronger statements require sidecar material in V1. The current
implementation closes the proof artifact integration boundary and adds a public
sidecar theorem verifier. `ApplicationPublicTheoremArtifactV1` can carry those
public sidecars in one artifact, but it still does not make a zero-knowledge or
succinct AIR/GKR proof claim.

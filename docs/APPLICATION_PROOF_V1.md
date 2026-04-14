# Application Proof V1

Status: implemented application-level proof envelope for the concrete verifier
surfaces that exist today. It binds witness, AIR, and GKR public digests, verifies
one M31 sum-check chunk proof, and verifies one Circle PCS/FRI contract proof.
It is not a semantic AIR verifier, a GKR verifier, or a witness-to-trace
compiler.

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
produced from that AIR.

## PCS Component

The PCS component is the existing `CirclePCSFRIContractVerifierV1` surface. It
checks the selected parameter set, canonical Circle domain, terminal final
layer shape, transcript binding, Merkle openings, structured polynomial claim,
and claimed first-layer evaluation openings.

The application proof does not weaken the PCS contract. It embeds the Circle
PCS/FRI proof bytes and verifies them against the `CirclePCSFRIStatementV1`
inside the application statement.

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

## Manifest

`ApplicationProofManifestV1.current` is the machine-checkable scope record for
this final artifact. It records that V1:

- includes a final application artifact,
- binds witness commitment, AIR definition, and GKR claim digests,
- verifies the narrow M31 sum-check chunk proof,
- verifies the Circle PCS/FRI contract proof,
- does not verify AIR semantics,
- does not verify GKR,
- does not produce witness-to-AIR traces or AIR-to-sum-check reductions.

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

Those stronger statements require concrete AIR and GKR verifier code that does
not exist in this repository yet. The current implementation closes the proof
artifact integration boundary without inventing unverifiable mathematical
claims.

# Cryptographic Engineering Findings

This log records security-relevant implementation findings and the work completed to close them. It is not a production security audit.

## 2026-04-14: Resident Private AIR Trace Synthesis

Finding:

- The public theorem path could derive `AIRExecutionTraceV1` values from public
  witness columns, but there was no resident-private equivalent for the actual
  AIR trace layout consumed by the AIR semantic verifier.

Work completed:

- Added `AIRTraceResidentSynthesisPlanV1`, which accepts private column-major
  M31 witness columns, checks every limb against the M31 modulus on GPU, and
  writes row-major AIR trace values into a caller-owned resident buffer.
- Added `AIRTraceResidentSynthesisOracleV1` as the CPU mirror for column-major
  witness packing and trace synthesis, reusing the existing
  `WitnessToAIRTraceProducerV1` object model.
- Added fixture coverage that uploads the Fibonacci witness into private Metal
  memory, synthesizes the resident row-major trace, verifies readback equality
  with the CPU AIR trace oracle, and feeds that exact trace into the CPU AIR
  composition verifier. Noncanonical private witness limbs are rejected by the
  GPU failure flag.
- Updated the Circle PCS artifact manifest to record resident private AIR trace
  synthesis as an implemented substrate capability while still excluding AIR,
  sumcheck, and GKR data from the PCS proof bytes themselves.

Residual risk:

- This is trace layout synthesis, not an AIR proof. AIR semantic verification,
  resident AIR semantic verification, zero-knowledge masking, and succinct
  AIR/GKR integration remain separate slices.

## 2026-04-14: Shared-Domain AIR Quotient Identity PCS Openings

Finding:

- Public trace PCS openings and public quotient PCS openings could be aligned by
  storage index, but that did not prove the AIR quotient identity. The trace PCS
  bridge interpolated opened AIR rows over Circle first-half x-coordinates while
  the quotient oracle used row-coordinate polynomials.

Work completed:

- Added `AIRRowDomainTracePCSWitnessV1` and
  `AIRRowDomainTracePCSProofBundleV1` for current trace polynomials and
  shifted-next trace polynomials committed over the same row-coordinate x-domain
  used by `AIRPublicQuotientProofV1`.
- Added `AIRQuotientIdentityOpeningQueryPlannerV1`, which derives non-root
  challenge storage indices from the row-domain trace, shifted trace, and
  quotient commitment roots. Sampled x-coordinates exclude the public trace row
  roots so the quotient vanishing factors are nonzero at the checked points.
- Added `AIRSharedDomainQuotientIdentityPCSProofBundleV1` and verifier report
  plumbing. The verifier checks all PCS proofs, binds current trace chunks to
  the quotient proof trace-polynomial digest, checks that shifted trace chunks
  equal `T(X + 1)`, checks quotient chunks against the quotient proof, and then
  verifies `N(z) = Z(z) * Q(z)` from the PCS openings.
- Added regression coverage for a valid Fibonacci AIR quotient identity bundle
  and a tampered quotient-coefficient proof that still builds PCS chunks but is
  rejected by the shared-domain identity equation.

Residual risk:

- This is still a public sidecar construction. It is not zero-knowledge, not a
  batched PCS protocol, and not the final succinct AIR/GKR theorem path.

## 2026-04-14: Public Multilinear AIR Constraint Sumcheck

Finding:

- `M31SumcheckProofV1` verifies the existing coefficient-fold chunk transcript,
  but that fold shape is not the full multilinear sumcheck protocol over an
  evaluation table and should not be relabeled as such.

Work completed:

- Added `M31MultilinearSumcheckProofV1`, statement, round, builder, and verifier
  types for a public full multilinear evaluation-table sumcheck. The verifier
  checks each round polynomial `(g_i(0), g_i(1))`, transcript-derived
  challenges, `(1-r) * f(0) + r * f(1)` folding, and final evaluation
  consistency.
- Added `AIRConstraintMultilinearSumcheckProofV1`, which binds the full
  multilinear proof to `AIRToSumcheckReductionV1.paddedEvaluationVector`,
  requires a zero hypercube-sum claim, and reports whether the public AIR
  semantics also hold for the supplied trace.
- Added regression coverage for valid multilinear sumcheck proofs, tampered
  round polynomials, mismatched claimed sums, valid AIR reduction binding, and
  rejection when a proof is checked against a different AIR reduction vector.

Residual risk:

- This is public and revealed-vector. A zero sum of the current AIR reduction
  vector is not by itself a private succinct AIR proof, and it is not
  zero-knowledge. The older `ApplicationProofV1` byte format still embeds the
  narrow M31 chunk proof for corpus stability; the public multilinear AIR
  sumcheck is exposed as a separate sidecar surface.

## 2026-04-14: Integrated Public AIR/GKR Theorem Artifact

Finding:

- The public theorem path had independently verifiable pieces: public theorem
  artifact, AIR constraint multilinear sumcheck, and shared-domain quotient
  identity PCS openings. Callers still had to compose those reports correctly.

Work completed:

- Added `ApplicationPublicTheoremIntegratedArtifactV1`, which packages the
  public theorem artifact, `AIRConstraintMultilinearSumcheckProofV1`, and
  `AIRSharedDomainQuotientIdentityPCSProofBundleV1`.
- Added `ApplicationPublicTheoremIntegratedArtifactVerifierV1` and report
  fields that require all three surfaces to refer to the same public theorem
  trace. The verifier derives the public quotient proof from that trace, checks
  the quotient identity bundle against it, checks the AIR sumcheck against the
  canonical AIR reduction vector, and inherits GKR semantic verification from
  the public theorem report.
- Added manifest and regression coverage for the valid integrated artifact and
  a tampered AIR-reduction digest that leaves the public theorem and quotient
  identity valid but fails integrated theorem verification.
- Added strict codecs and domain-separated digests for
  `M31MultilinearSumcheckProofV1`,
  `AIRConstraintMultilinearSumcheckProofV1`, row-domain trace PCS bundles,
  shared-domain quotient-identity bundles, and
  `ApplicationPublicTheoremIntegratedArtifactV1`.
- Checked in `ApplicationPublicTheoremIntegratedArtifactCorpusV1.json`, which
  pins canonical integrated artifact bytes and raw/domain-separated digests, and
  rejects AIR-reduction digest mismatch, quotient-identity query-plan commitment
  mismatch, and trailing bytes.

Residual risk:

- This is an integrated public sidecar artifact. It still reveals public trace
  material, is not zero-knowledge, and is not a succinct private AIR/GKR proof.

## 2026-04-14: Public AIR Trace Circle FFT-Basis Witness

Finding:

- Arbitrary public AIR trace layouts could be packed into Circle PCS polynomial
  claims, but the corresponding Circle FFT-basis coefficient representation was
  not exposed as a structured witness. The resident FFT-basis producer remained
  limited to monomial coefficient buffers.

Work completed:

- Added `AIRTraceCircleFFTBasisChunkV1`,
  `AIRTraceCircleFFTBasisWitnessV1`, and
  `AIRTraceToCircleFFTBasisWitnessV1`.
- The producer reuses the arbitrary-layout public trace PCS bridge, then derives
  verifier-checkable Circle FFT-basis coefficient chunks for each packed QM31
  trace-column group.
- The witness validates row storage indices, contiguous source-column coverage,
  polynomial-claim consistency, canonical QM31 FFT-basis coefficients, and
  equality with the independent `CircleCodewordOracle.circleFFTCoefficients`
  output.
- Added regression coverage for a five-column AIR trace layout, polynomial claim
  compatibility, Circle FFT/direct evaluation equivalence, corrupted basis
  rejection, and rejection of private-resident/ZK overclaims.

Residual risk:

- This is a public CPU witness-generation surface. It does not make arbitrary
  AIR trace layouts resident-private, does not synthesize traces from constraint
  systems, does not verify AIR semantics, and is not zero-knowledge.

## 2026-04-14: Public Trace/Quotient PCS Query Alignment

Finding:

- The public trace PCS query planner selected AIR opening rows, and the quotient
  PCS layer proved packed quotient coefficient chunks, but no verifier checked
  that a quotient PCS bundle opened at the same storage indices required by the
  trace query plan.

Work completed:

- Added `AIRTraceQuotientPCSQueryAlignmentVerifierV1` and
  `AIRTraceQuotientPCSQueryAlignmentReportV1`.
- The verifier checks the trace queried-opening bundle, checks the quotient PCS
  bundle proofs, verifies the quotient bundle is bound to the supplied
  `AIRPublicQuotientProofV1`, requires matching domains and PCS parameter sets,
  and requires quotient openings to exactly match the trace query plan's
  bit-reversed row storage indices.
- Added regression coverage for accepted aligned openings, under-opened quotient
  bundles, wrong-domain quotient bundles, and quotient bundles bound to a
  different public quotient proof.

Residual risk:

- This is public opening alignment only. It does not prove the AIR quotient
  identity at a shared evaluation point, because the current trace PCS bridge
  interpolates public trace rows over Circle first-half x-coordinates while the
  CPU public quotient oracle is built over row-coordinate polynomials. The
  separate shared-domain quotient identity bundle now handles that equation with
  row-domain trace, shifted-trace, and quotient PCS openings.
- The report intentionally exposes `quotientIdentityChecked == false`,
  `coordinateDomainsAlignedForAIRQuotientIdentity == false`, and
  `isZeroKnowledge == false`.

## 2026-04-14: Public Trace PCS Opening Query Planner

Finding:

- Public AIR opening checks could validate caller-selected PCS openings, but the
  row selection was not transcript-derived.

Work completed:

- Added `AIRTracePCSOpeningQueryPlannerV1`, which samples public transition rows
  from a transcript over the AIR definition and initial trace PCS commitment
  roots.
- Added `AIRTracePCSQueriedOpeningBundleV1`, builder, verifier, and report types
  that require the trace PCS bundle to open exactly the sampled transition rows
  plus required boundary rows.
- Added regression coverage for accepted queried-opening bundles, tampered query
  plan rejection, non-query row-claim rejection, and invalid full-transition
  trace rejection.

Residual risk:

- This is a public query-opening scaffold. It does not hide opened witness
  values and does not implement the full STARK/AIR quotient identity protocol.
  The separate trace/quotient PCS alignment verifier now checks shared public
  opening coverage, and the shared-domain quotient identity bundle checks the
  row-coordinate quotient equation as a separate public sidecar.
- Query sampling is tied to initial trace PCS commitment roots to avoid the
  circularity of deriving rows from the completed bundle digest, but the current
  V1 PCS statement still exposes polynomial material and is not a commitment-only
  production proof.

## 2026-04-14: Public Trace PCS Opening Constraint Verifier

Finding:

- Public AIR trace PCS bundles could prove and bind opened trace chunks, but no
  verifier checked AIR transition or boundary constraints directly against the
  PCS evaluation claims.

Work completed:

- Added `AIRTracePCSOpeningConstraintVerifierV1` and
  `AIRTracePCSOpeningConstraintReportV1`.
- The verifier unpacks QM31 trace-opening limbs, checks padding limbs, verifies
  opened transition and boundary constraints, and reports whether opened rows
  cover every transition and boundary needed for full public AIR coverage.
- Tightened `AIRTraceCirclePCSWitnessV1` shape validation so decoded or assembled
  trace chunks must cover AIR columns contiguously and in order.
- Added regression coverage for complete openings, partial openings, invalid
  transition openings, invalid boundary openings, encoded-bundle verification,
  and AIR shape mismatch.

Residual risk:

- This is still a public opening verifier. It does not sample Fiat-Shamir AIR
  query rows, does not hide witness values, does not prove quotient relations
  through private openings, and is not a zero-knowledge or succinct AIR proof.

## 2026-04-14: Public Quotient PCS Layer

Finding:

- `AIRProofV1` had public quotient-divisibility validation, but no PCS-backed
  proof bundle for the quotient coefficient polynomials.

Work completed:

- Added `AIRProofQuotientPCSArtifactV1` and
  `AIRQuotientCirclePCSProofBundleV1`.
- Added `AIRPublicQuotientToCirclePCSWitnessV1`, which packs up to four M31
  quotient coefficient polynomials into each QM31 Circle polynomial chunk.
- Added builder, verifier, digest, and strict codec coverage for quotient PCS
  bundles and the wrapping artifact.
- Added regression coverage for accepted artifacts, encoded verification,
  trailing-byte rejection, and mismatched quotient-bundle rejection.

Residual risk:

- The quotient PCS layer is public. It proves packed public quotient coefficient
  chunks with the current Circle PCS contract, but it does not hide witness data,
  does not add zero-knowledge masking, and does not make the AIR/GKR theorem
  succinct.

## 2026-04-14: Public Revealed-Trace AIR Proof And Quotient Scaffold

Finding:

- The repository had AIR semantic checking and AIR-to-sum-check reduction, but
  it did not have a standalone AIR proof artifact with a strict statement,
  transcript-composed constraint-evaluation oracle, verifier report, and binary
  codec.

Work completed:

- Added `AIRProofManifestV1`, `AIRProofStatementV1`, `AIRProofV1`,
  `AIRProofBuilderV1`, and `AIRProofVerifierV1`.
- Added `AIRCompositionOracleV1`, which derives nonzero M31 composition weights
  from the AIR definition and trace shape, binds the raw AIR
  constraint-evaluation digest, and produces a composed public evaluation vector.
- Added `AIRPublicQuotientProofV1`, which interpolates public trace columns over
  the row domain and verifies transition/boundary numerator divisibility by
  public vanishing polynomials.
- Added strict codecs for the AIR proof statement, composition evaluation,
  public quotient proof, and proof bytes.
- Added regression coverage for accepted Fibonacci AIR proofs, strict codec
  round trips, trailing-byte rejection, invalid witness rejection, altered
  witness rejection, tampered composition rejection, and tampered quotient proof
  rejection.

Residual risk:

- The accepted scope is only public revealed-trace AIR constraint evaluation.
  The proof includes the witness trace and is not zero-knowledge.
- The quotient certificate inside `AIRProofV1` is public CPU divisibility
  validation. The separate `AIRProofQuotientPCSArtifactV1` adds public
  PCS-backed quotient chunks, but the combined artifact is still not a private
  STARK/AIR protocol.

## 2026-04-14: Public AIR Trace Layout And PCS Witness Bridge

Finding:

- The public sidecar theorem path could validate positional witness columns, but
  arbitrary AIR trace layouts still needed an explicit named-column boundary and
  there was no reusable bridge from public AIR trace rows into the structured
  Circle PCS polynomial-claim format.

Work completed:

- Added `ApplicationWitnessColumnV1` and `ApplicationWitnessLayoutV1`, which
  validate named public M31 witness columns, reject duplicate names and
  mismatched row counts, and produce ordered `ApplicationWitnessTraceV1` values
  for the AIR column order requested by the caller.
- Added `AIRTraceToCirclePCSWitnessV1`, which packs up to four M31 AIR columns
  into each QM31 polynomial chunk, interpolates those values over the canonical
  Circle first half-domain, and emits `CirclePCSFRIPolynomialClaimV1` values for
  selected trace rows.
- Added `AIRTraceCirclePCSProofBundleBuilderV1` and
  `AIRTraceCirclePCSProofBundleVerifierV1`, which wrap every generated trace
  chunk with an ordinary Circle PCS statement/proof pair and verify the bundle
  against a regenerated public AIR trace witness.
- Added `AIRTraceCirclePCSProofBundleCodecV1`,
  `AIRTraceCirclePCSProofBundleDigestV1`, and encoded verifier overloads so the
  ordered public trace PCS bundle has strict bytes, trailing-byte rejection, and
  a domain-separated digest.
- Added `ApplicationPublicTheoremTracePCSArtifactV1` with builder, verifier,
  strict codec, and domain-separated digest. This combined public artifact
  verifies the public AIR/GKR theorem, verifies the trace PCS bundle against the
  regenerated public AIR trace, and requires the application proof's PCS
  statement/proof pair to appear inside that trace bundle.
- Added regression coverage for named-column reordering, malformed layouts,
  multi-chunk five-column trace packing, interpolation correctness at every
  source row, claimed row opening values, proof-bundle verification, strict
  bundle codec round trips, digest stability, encoded-bundle verification,
  combined public theorem trace PCS artifact verification, altered trace
  rejection, unbound application PCS proof rejection, duplicate claim-row
  rejection, trailing-byte rejection, and domain capacity rejection.

Residual risk:

- This is a CPU/public sidecar bridge. It is not zero-knowledge, not a private
  resident witness compiler, and not a succinct AIR/GKR proof.
- The bridge creates committed-polynomial PCS claims from an AIR trace, but the
  PCS proof still checks only committed-polynomial semantics. AIR and GKR
  semantics remain in the application theorem verifier or public theorem
  artifact.
- The proof bundle is an ordered collection of existing single-polynomial PCS
  proofs. It is not a new batch PCS protocol and does not add cross-polynomial
  batching soundness claims.
- The combined public theorem trace PCS artifact binds two public verification
  surfaces in one artifact, but it is still public and non-ZK. It does not turn
  the underlying PCS proof into an AIR proof.
- The interpolation helper is intentionally simple and validation-oriented. A
  production large-trace compiler still needs a reviewed, tiled/interleaved
  construction path.

## 2026-04-14: Self-Contained Public Application Theorem Artifact

Finding:

- The public AIR/GKR theorem verifier could check semantic sidecars, but callers
  still had to supply the statement, proof, witness trace, AIR definition, and
  GKR claim out of band. That left no single verifier-facing artifact for
  deterministic end-to-end public theorem fixtures.

Work completed:

- Added `ApplicationPublicTheoremArtifactV1`, which packages an
  `ApplicationProofStatementV1`, `ApplicationProofV1`, public witness trace,
  AIR definition, and GKR claim.
- Added `ApplicationPublicTheoremBuilderV1`, which produces the public theorem
  artifact only after checking AIR semantics and GKR claim truth, computing the
  AIR-to-M31-sum-check reduction, building the M31 chunk proof, and assembling
  the application proof.
- Added strict binary codecs for the public theorem artifact, application
  statement, public witness trace, AIR definition, and GKR claim.
- Added verifier overloads that accept a decoded or encoded public theorem
  artifact and return the existing theorem report.
- Added `ApplicationPublicTheoremArtifactCorpusV1.json`, pinning deterministic
  public theorem inputs, stable artifact/proof/statement/sidecar digests, and
  digest-bound AIR/GKR semantic rejection vectors.
- Added regression coverage for canonical encoding round trips, trailing-byte
  rejection, valid artifact verification, digest-mismatched sidecar rejection,
  stable corpus verification, and builder rejection of invalid AIR or false GKR
  inputs.

Residual risk:

- This artifact is self-contained only because the witness trace and GKR inputs
  are public material inside the artifact.
- This is not zero-knowledge and not a succinct AIR/GKR proof. The existing M31
  chunk remains non-ZK and still reveals the initial evaluation vector.

## 2026-04-14: Public AIR/GKR Sidecar Theorem Verification

Finding:

- `ApplicationProofV1` correctly bound witness, AIR, and GKR digests, but the
  repository still needed a concrete way to validate those bound sidecars
  without pretending the proof bytes were self-contained or zero-knowledge.

Work completed:

- Added `AIRDefinitionV1`, `AIRExecutionTraceV1`, and
  `AIRSemanticVerifierV1`, a small M31 AIR language with transition and
  boundary polynomial constraints over current and next trace rows.
- Added `ApplicationWitnessTraceV1` and `WitnessToAIRTraceProducerV1`, which
  synthesize a row-major AIR trace from public column-major witness sidecars.
- Added `AIRToSumcheckReductionV1`, which computes the canonical AIR
  constraint-evaluation vector, pads it to the implemented M31 chunk shape, and
  checks that `M31SumcheckStatementV1.initialEvaluationDigest` binds that
  vector.
- Added `GKRClaimV1` and `GKRSemanticVerifierV1`, a CPU layered M31 arithmetic
  circuit evaluator for bound GKR claim sidecars.
- Added `ApplicationTheoremVerifierV1` and
  `ApplicationTheoremManifestV1.current`, composing the application proof,
  public witness, AIR, sum-check reduction, and GKR semantic checks under one
  explicit public sidecar theorem report.
- Added `zkmetal-bench --application-public-theorem`, a CPU smoke benchmark
  that builds the deterministic public Fibonacci AIR theorem artifact,
  exercises strict artifact serialization/deserialization, runs the public
  theorem verifier, and reports artifact/proof/statement digests with the
  accepted application and M31 claim scopes.
- Added regression coverage for an accepted Fibonacci-style AIR sidecar, a
  semantically invalid AIR trace whose sum-check reduction still matches the
  statement digest, and a false GKR output claim.

Residual risk:

- Sidecar verification by itself still expects the AIR trace and GKR inputs to
  be supplied to the verifier. `ApplicationPublicTheoremArtifactV1` now packages
  those public sidecars when a single artifact is needed.
- This path is not zero-knowledge. The existing M31 chunk still reveals its
  initial evaluation vector, and the sidecar theorem verifier sees the public
  witness trace.

## 2026-04-14: Application Proof Envelope For Implemented Components

Finding:

- The repository had independently verified Circle PCS/FRI and M31 sum-check
  chunk components, but no final application-level artifact that bound those
  proofs together with witness, AIR, and GKR public claims.
- At the time, the repo had no concrete AIR semantic verifier or GKR verifier,
  so filling the artifact gap could not turn into an unsupported full
  proof-system claim.

Work completed:

- Added `ApplicationProofStatementV1`, which binds an application identifier,
  witness commitment digest, AIR definition digest, GKR claim digest,
  `M31SumcheckStatementV1`, and `CirclePCSFRIStatementV1` into a SHA3-256
  statement digest.
- Added `M31SumcheckProofV1`, `M31SumcheckProofBuilderV1`,
  `M31SumcheckVerifierV1`, and `M31SumcheckProofCodecV1` for the implemented
  M31 chunk transcript. The verifier replays framed challenges, checks fold
  consistency, and binds initial/final vector digests.
- Added `M31SumcheckClaimScopeV1` and
  `M31SumcheckVerificationReportV1`. The current accepted scope is only
  `revealedEvaluationVectorFoldingTrace`; full multilinear sum-check,
  AIR-constraint sum-check, and zero-knowledge AIR sum-check scopes are
  explicitly rejected by that legacy chunk report. The separate
  `M31MultilinearSumcheckProofV1` and
  `AIRConstraintMultilinearSumcheckProofV1` surfaces now cover public
  evaluation-table and AIR-reduction sumcheck checks without changing
  `ApplicationProofV1` bytes.
- Added `ApplicationProofV1`, `ApplicationProofBuilderV1`,
  `ApplicationProofVerifierV1`, and `ApplicationProofCodecV1`. The verifier
  rejects statement digest mismatches, invalid M31 sum-check chunks, and invalid
  Circle PCS/FRI contract proofs.
- Added `ApplicationProofClaimScopeV1` and
  `ApplicationProofVerificationReportV1`, so callers can distinguish the
  accepted implemented PCS/sum-check slice from the unsupported witness/AIR/GKR
  theorem in `ApplicationProofV1` proof bytes alone.
  `verifyEndToEndApplicationTheorem` returns false for V1 rather than
  overclaiming.
- Added `ApplicationProofManifestV1.current`, which records the completed
  artifact composition and explicitly marks AIR semantic verification,
  witness-to-AIR trace production, AIR-to-sum-check reduction, GKR verification,
  end-to-end theorem verification, and M31 sum-check zero-knowledge as open.
- Added `M31SumcheckManifestV1.current`, which records that the M31 artifact
  verifies only the chunk transcript/folding relation, does not verify AIR
  reduction, is not a full sum-check protocol, and is not zero-knowledge.
- Added regression coverage for valid application proof round-trip, mismatched
  GKR digest rejection, sum-check challenge tamper rejection, codec trailing
  byte rejection, and manifest scope.
- Added `Tests/AppleZKProverTests/Resources/ApplicationProofCorpusV1.json`, a
  checked-in application proof corpus with canonical accepted bytes, expected
  proof digest, statement-digest mismatch rejection, sum-check challenge tamper
  rejection, and embedded PCS final-layer tamper rejection.

Residual risk:

- This is a final envelope for the implemented verifier components, not a
  proof that a witness satisfies an AIR or that a GKR claim is true. The
  sum-check chunk proof reveals the initial evaluation vector and verifies only
  the current chunk transcript/folding relation.
- Self-contained witness-to-trace proofs, prover-integrated AIR/GKR semantics,
  zero-knowledge masking for the M31 chunk, and an externally reviewed
  end-to-end theorem remain future work.

## 2026-04-14: Resident Witness Coefficient To Circle FFT-Basis Production

Finding:

- The resident Circle PCS path could consume a private Circle FFT-basis
  coefficient buffer, but callers with private monomial coefficient witness
  columns still had to convert those coefficients on the host or precompute the
  FFT-basis buffer elsewhere.
- Closing that residency gap must not be described as AIR trace synthesis or
  AIR semantic verification.

Work completed:

- Added `CircleWitnessToFFTBasisPlanV1`, which accepts private resident x/y
  monomial coefficient buffers and writes interleaved Circle FFT-basis
  coefficients into a resident output buffer.
- Added the `circle_witness_to_fft_basis` Metal kernel. It uses a public M31
  monomial-to-line-basis transform matrix and performs the QM31 linear
  combination on GPU, so private coefficient buffers are not read back.
- Added `QM31CanonicalityCheckPlan` and the `qm31_check_canonical` Metal kernel.
  The resident witness basis path scans private x/y witness coefficient buffers
  on GPU and rejects noncanonical QM31 limbs before applying the transform.
- Added tiled dense transform scheduling for `CircleWitnessToFFTBasisPlanV1`.
  The full public matrix oracle remains capped for host materialization, but
  resident execution can materialize bounded row tiles and dispatch the same
  checked matrix multiplication per tile.
- Added `CircleWitnessToFFTBasisCommandPlanV1`, recording that this producer
  consumes resident monomial coefficient columns, validates private witness
  canonicality, records dense versus tiled matrix scheduling, and explicitly
  does not produce AIR traces or verify AIR semantics.
- Added `CircleCodewordPCSFRIProverV1.proveResidentWitnessCoefficients` and a
  verified convenience path that feeds the new resident basis producer into the
  existing resident codeword and PCS/FRI proof emitter.
- Updated `CirclePCSFRIArtifactManifestV1.current` to mark resident
  witness-to-Circle-FFT-basis production as supported for this narrow
  coefficient-column shape while leaving AIR trace synthesis and sumcheck/GKR
  integration as open boundaries.

Residual risk:

- The transform remains a correctness-oriented resident bridge. It materializes
  the full Circle FFT-basis buffer before codeword generation and uses tiled
  dense matrix multiplication for larger witness shapes; it is not a
  matrix-free or AIR-aware witness compiler.
- This does not construct witness columns from an AIR, check AIR constraints, or
  verify that the coefficient witness is semantically tied to an application
  statement.

## 2026-04-14: V1 Scope Manifest And Grinding Nonce Support

Finding:

- The Circle V1 proof format serialized `grindingBits` and counted it in nominal security
  bits, but the artifact initially had no nonce or proof-of-work predicate for the verifier
  to check. The docs and production profile used `grindingBits = 0`, but lower-level
  developer surfaces needed either fail-closed rejection or a verifier-checked nonce.
- The remaining open boundaries were documented, but there was no code-level manifest that
  made those non-capabilities machine-checkable.

Work completed:

- Added `CirclePCSFRIArtifactManifestV1.current`, which records that V1 includes the
  Circle PCS/FRI slice and explicitly does not include witness/AIR, sumcheck, or GKR
  output, and records the remaining unsupported boundaries.
- Extended `CircleCodewordPCSFRIResidentCommandPlanV1` with an explicit
  codeword-to-commitment schedule and a `usesFusedTiledCodewordCommitment`
  flag. The current schedule is `final-fft-stage-leaf-hash-then-commit`.
- Added V1 grinding nonce support: nonzero `grindingBits` require an encoded 8-byte nonce,
  the transcript absorbs that nonce after the final layer and before query sampling, and
  the verifier checks the leading-zero SHA3 target before accepting the proof.
- Wired nonce search into the CPU proof builder and resident proof emitter. Local prover
  search is capped by `CircleFRIGrindingV1.maximumLocalSearchBits`; the verifier checks
  any valid encoded nonce independently.
- Added regression tests for the manifest, grinding-nonce round trips, missing nonce
  rejection, and tampered nonce rejection.

Residual risk:

- This deliberately does not implement AIR semantic verification, GKR
  verification. A later resident coefficient-witness
  bridge covers only monomial coefficient columns to Circle FFT-basis buffers.
  `ApplicationProofV1` is the separate final envelope for the implemented PCS
  and M31 sum-check components. The production-facing `conservative128` profile
  still uses `grindingBits = 0`; assigning grinding credit to a public profile
  remains separate parameter-review work.

## 2026-04-14: Production-Facing Circle PCS Contract, Parameters, And Corpus

Finding:

- The resident Circle coefficient-to-proof boundary had an implemented artifact verifier and structured polynomial-claim checker, but the public PCS surface still allowed caller-selected developer parameters. There was also no checked-in complete proof corpus that pinned canonical bytes, expected digests, and rejection behavior for the strict boundary.

Work completed:

- Added `CirclePCSFRIParameterSetV1.conservative128`, fixing `logBlowupFactor = 4`, `queryCount = 36`, `foldingStep = 1`, `grindingBits = 0`, and `roundCount = domain.logSize - 4` for the production-facing V1 slice. The profile targets 128-bit soundness from a nominal 144-bit query budget and intentionally claims no grinding credit.
- Added `CirclePCSFRIStatementV1` as the verifier-facing public statement: one parameter profile plus one structured `CirclePCSFRIPolynomialClaimV1`. The statement enforces canonical bit-reversed domains and a combined `P/Q` coefficient budget no larger than `domain.size / 16`.
- Added `CirclePCSFRIContractVerifierV1`, which rejects proofs that do not match the selected profile, exact round count, terminal constant final layer, statement domain, claimed-opening count, and claim-aware polynomial verification.
- Added `CirclePCSFRIContractProverV1` as a deterministic CPU helper for tests and corpus generation. It is not the resident production prover path.
- Checked in `Tests/AppleZKProverTests/Resources/CirclePCSFRIProofCorpusV1.json`, containing canonical accepted proof bytes, expected SHA3-256 proof digests, verifier acceptance, and three tamper/rejection vectors.
- Added a corpus regression that reconstructs the public statement from JSON, checks exact proof byte counts and digests, checks codec re-encoding stability, verifies the accepted proof, rejects tampered proofs, and confirms that a developer-parameter proof accepted by the lower polynomial verifier is rejected by the strict contract.
- Added `docs/CIRCLE_PCS_SOUNDNESS_V1.md`, a conservative soundness note covering FRI sampling, Fiat-Shamir transcript binding, Merkle assumptions, field/domain assumptions, random-oracle modeling points, and explicit open boundaries.

Residual risk:

- This remains the implemented Circle PCS/FRI slice. `ApplicationProofV1` now
  composes it with the implemented M31 sum-check chunk proof, and the separate
  public sidecar theorem path can check AIR/GKR semantics when sidecars are
  supplied. The PCS proof itself still does not include AIR, sum-check, or GKR
  semantics.
- The concrete profile has not received external cryptographic review or a mechanized theorem for exact 128-bit soundness.
- The production-facing profile still claims no grinding credit, even though lower-level
  V1 artifacts can now carry verifier-checked grinding nonces.
- The resident path now avoids the extra first-layer leaf-hash pass in the composed codeword prover, but the first committed layer remains materialized for query openings.

## 2026-04-14: End-To-End Resident Circle Coefficient-To-Proof Boundary

Finding:

- The Circle codeword and resident PCS/FRI proof pieces were individually correctness-gated, but the public composition boundary was still too implicit. The benchmark also read the generated GPU codeword back to compute a digest, which weakened the resident-prover claim even though proof emission itself did not need that readback.

Work completed:

- Added `CircleCodewordPCSFRIResidentCommandPlanV1` as the explicit command-plan surface for the implemented Circle slice: coefficient input, Circle FFT codeword generation, Merkle roots, transcript challenges, FRI folds, query extraction, and proof bytes.
- Changed the composed prover's generated codeword buffer and resident committed-layer log to private Metal buffers. The composed path now exposes only public proof material: Merkle commitments, the final FRI layer, queried leaves, sibling paths, and encoded proof bytes.
- Added `CircleCodewordPCSFRIProverV1.proveCircleFFTCoefficientsResident`, which consumes a caller-owned Circle FFT-basis coefficient buffer and feeds resident codeword generation directly into resident proof emission without reading the coefficient buffer, full codeword, or intermediate FRI layers back to the CPU.
- Extended the Circle domain regression to drive the new FFT-basis coefficient entry point from a private Metal buffer and compare the emitted proof bytes against the CPU proof builder/verifier.
- Updated `zkmetal-bench --circle-codeword-prover` to schema v3. The timed codeword and full-prover rows use a private FFT-basis coefficient buffer, keep the generated codeword private, report an explicit readback policy, and mark codeword digests as CPU-oracle digests rather than GPU codeword readbacks.

Residual risk:

- This closes the resident coefficient-to-proof boundary for the current Circle FFT-basis input model. The resident witness-coefficient bridge covers monomial coefficient columns, but still does not generate AIR witness polynomials from a larger proving system.
- `prove(polynomial:)` and the legacy resident monomial-buffer convenience path still perform the monomial-to-Circle-FFT-basis conversion on the host. Callers that require a no-host-read resident path can now provide either Circle FFT-basis coefficients directly or private monomial coefficient witness columns through `proveResidentWitnessCoefficients`.
- Legacy artifact/prover APIs still allow caller-selected developer parameters for development and lower-level tests. Public production-facing verification should use `CirclePCSFRIContractVerifierV1` with the fixed conservative profile; external cryptographic review of that concrete profile is still required.
- The path now writes the first layer into the committed-layer arena and hashes leaves in the final FFT stage. Deeper tile-local Merkle treelet construction remains performance work and must be benchmarked before any stronger throughput claim.

## 2026-04-14: Circle FFT Codeword Engine

Finding:

- The GPU Circle codeword path evaluated `P(x) + yQ(x)` independently at every domain point with Horner loops over the public coefficient buffers. That was correct, but it scaled as `O(domain_size * degree)` and did not exercise the Circle FFT basis used by the rest of the Circle-domain PCS/FRI design.

Work completed:

- Kept the direct `P(x) + yQ(x)` CPU evaluator as the independent oracle, and added a separate CPU mirror of the Circle FFT path for parity testing.
- Added bounded monomial-to-Circle-FFT-basis conversion for the current `P(x) + yQ(x)` API. The conversion maps `P` and `Q` through Chebyshev coefficients into the tensor basis generated by `y, x, pi(x), pi^2(x), ...` with `pi(x) = 2x^2 - 1`, then interleaves the `P` and `Q` basis coefficients for the Circle butterfly schedule.
- Replaced the Metal direct evaluator with `circle_codeword_fft_stage`, an in-place resident butterfly kernel. `CircleCodewordPlan` copies FFT-basis coefficients into the caller-owned output buffer and dispatches stages from the highest line layer down to the Circle `y` layer using GPU-materialized twiddles from `CircleDomainMaterializationPlan`.
- Added parity tests for tiny domains, x-only/y-only functions, and max-degree in-space `P/Q` coefficients; added layout rejection for coefficients outside the `domain.size / 2` Circle FFT codeword space.
- Updated the Circle codeword benchmark schema to report `codewordEngine: "circle-fft-butterfly-v1"` and account for FFT-basis coefficient and twiddle traffic instead of direct domain-point input traffic.

Residual risk:

- The current public polynomial API is still monomial `P(x) + yQ(x)`, so verified convenience paths convert those coefficients on the host before the resident FFT command plan. A future witness pipeline should emit Circle FFT-basis coefficients directly into resident buffers to remove that host conversion.
- The first committed layer still remains materialized because the V1 query extractor needs those leaf values for transcript-sampled openings. The fused commitment path removes the separate first-layer leaf-hash read but does not yet implement a deeper tile-local Merkle treelet schedule for the first root.

## 2026-04-14: Fused Circle FFT Final-Stage Leaf Hashing

Finding:

- The resident Circle codeword prover wrote the generated codeword into a private buffer, then the resident PCS prover copied that full first layer into its committed-layer arena and reread it for the first Merkle leaf-hash pass. The values must remain materialized for later query openings, but the extra first-layer copy and leaf-hash reread were avoidable.

Work completed:

- Added `circle_codeword_fft_stage_leaf_hash`, a final-stage Circle FFT butterfly kernel that writes finalized QM31 values and SHA3-hashes both finalized 16-byte leaves in the same dispatch.
- Added `SHA3PrehashedLeavesMerkleCommitPlan`, a resident Merkle reducer for already-hashed 32-byte leaves. It can encode parent reduction into an existing command buffer and write the root into caller-owned proof material.
- Added a precomputed-first-commitment path through the QM31/Circle FRI fold chain. The resident codeword prover now writes the first committed layer directly into the PCS committed-layer buffer, writes the first root through the prehashed reducer, then skips the old first-layer materialization copy and root recomputation while preserving the same transcript, FRI folds, query extraction, proof bytes, and CPU verifier acceptance.
- Updated the Circle PCS artifact manifest and resident command plan to record `final-fft-stage-leaf-hash-then-commit` with fused commitment scheduling enabled.
- Bumped `zkmetal-bench --circle-codeword-prover` to schema v4 so reports expose the codeword commitment schedule and fused commitment flag.

Residual risk:

- This closes the avoidable full-codeword leaf-hash pass for the first committed layer. Further optimization could still add tile-local first-layer parent/treelet construction, but that is a performance extension rather than an open proof-system boundary.

## 2026-04-14: Metal-Resident Circle Domain And Twiddle Materialization

Finding:

- The Circle GPU plans still treated canonical domain points, Circle FFT twiddles, and FRI inverse-domain schedules as CPU-precomputed public buffers. That kept the hot path dependent on host materialization for deterministic data that the GPU can derive from the canonical domain descriptor.

Work completed:

- Added `CircleDomainMaterializationPlan`, which accepts only canonical bit-reversed Circle domains and materializes requested domain points, Circle FFT twiddles, and flattened inverse-domain layers into private Metal buffers.
- Added Metal kernels for M31 Circle index-to-point generation, bit-reversed domain point materialization, first-round inverse-`y` twiddles, later line-fold inverse-`x` twiddles, and Circle FFT twiddle materialization.
- Rewired `CircleCodewordPlan`, `CircleFRIFoldPlan`, `CircleFRIFoldChainPlan`, and `CircleFRIMerkleTranscriptFoldChainPlan` to consume GPU-generated resident buffers instead of CPU-uploaded domain/twiddle schedules.
- Added stable SHA3 vector digests for canonical domain points, Circle FFT twiddles, and inverse-domain schedules, plus Metal readback parity over multiple canonical domain sizes.

Residual risk:

- The materializer is deterministic and parity-gated, but it is still a materialization step rather than a fused generator inside every downstream kernel. Fully tiled Circle FFT/codeword scheduling remains separate performance work.
- Resident APIs still assume caller-owned evaluation/coefficient buffers are canonical by construction unless the verified convenience path has CPU-side witness material available.

## 2026-04-14: Circle PCS Polynomial Claim Verification

Finding:

- The Circle proof verifier had become an independent CPU checker for the implemented FRI artifact, but successful verification still meant "these Merkle/FRI decommitments are internally consistent." It did not bind a structured polynomial claim, the canonical Circle domain point semantics, or user-facing claimed evaluations to the first committed layer.

Work completed:

- Added `CirclePCSFRIEvaluationClaimV1` and `CirclePCSFRIPolynomialClaimV1` for the current Circle codeword model `P(x) + yQ(x)`. The claim digest binds the canonical domain descriptor, QM31 coefficient vectors, storage-index/point pairs, and claimed QM31 values into the existing public-input digest path.
- Extended `CirclePCSFRIProofV1` with optional first-layer claimed evaluation openings. Legacy proof bytes stay unchanged when no claimed openings are present, while claim-bearing proofs serialize strict first-layer Merkle openings.
- Extended `CircleFRIProofBuilderV1` to emit claimed first-layer openings for selected storage indices and added `CirclePCSFRIPolynomialVerifierV1`, which first runs the FRI artifact verifier and then checks coefficient-count bounds, storage-index-to-domain-point mapping, CPU polynomial evaluation, claimed values, and Merkle openings against the first commitment root.
- Added a regression gate where `CirclePCSFRIProofVerifierV1` accepts a valid FRI artifact built under a false claimed evaluation digest, but `CirclePCSFRIPolynomialVerifierV1` rejects the malformed polynomial claim. The test also rejects tampered claimed-opening Merkle paths.

Residual risk:

- This closes the CPU verifier semantics for the current `P(x) + yQ(x)` codeword representation. It does not claim production soundness parameters.
- Resident-only GPU APIs outside the monomial witness-to-FFT-basis producer still
  assume caller-owned buffers are canonical by construction unless a verified
  convenience path has CPU-side polynomial material available.

## 2026-04-14: QM31 FRI Proof Benchmark Gate And Resident Circle Coefficients

Findings:

- The linear QM31 FRI proof/decommitment surface had deterministic serialization and an independent verifier, but no benchmark mode that exercised the complete proof artifact lifecycle. That made proof-size, query-opening count, strict decode cost, and verifier cost invisible to the measurement discipline.
- The Circle codeword prover benchmark used public polynomial convenience calls in timed regions. Those calls allocate and upload coefficient buffers even though the codeword plan supports caller-owned resident coefficient buffers, so the timed rows included avoidable host allocation work.

Work completed:

- Added `zkmetal-bench --qm31-fri-proof`, which builds the current linear radix-2 QM31 FRI proof, serializes it with deterministic sorted-key JSON, deserializes it through the strict decoder, verifies it with `QM31FRIProofVerifier`, and reports proof size, query-opening count, final-layer/proof digests, verifier acceptance, and CPU match status.
- Added `CircleCodewordPCSFRIProverV1.proveResidentCoefficients`, which composes resident coefficient buffers, resident Circle codeword generation, and resident PCS/FRI proof emission without allocating coefficient buffers in the timed path.
- Added `CircleCodewordPCSFRIProverV1.proveResidentCoefficientsVerified`, which keeps the same CPU oracle and independent verifier gate for callers that still have the polynomial on the CPU.
- Extended the Circle domain test flow to cover resident coefficient-buffer codeword generation and resident coefficient-buffer proof emission against the CPU proof builder/verifier.

Residual risk:

- `--qm31-fri-proof` benchmarks the CPU proof artifact for the current linear radix-2 layout. It is not a GPU proof emitter, not a Circle-domain proof benchmark, and not a production soundness-parameter claim.
- The QM31 proof format remains deterministic developer JSON. A compact binary format should be specified before treating it as a wire-format commitment.
- Resident coefficient-buffer execution outside the witness-coefficient bridge
  assumes the caller has already produced canonical QM31 coefficient limbs. The
  verified convenience method checks the resulting proof against a CPU
  polynomial oracle, but the resident FFT-basis entry point still intentionally
  avoids reading private coefficient buffers back for canonicality checks.
- The legacy resident monomial-buffer API still requires CPU-readable buffers so it can convert into FFT-basis coefficients before dispatch. The resident FFT-basis entry point and resident witness-coefficient bridge supersede this limitation for callers that can provide private Circle FFT-basis coefficients or private monomial coefficient witness columns directly.

## 2026-04-13: Linear QM31 FRI Query Proof Format And Verifier

Finding:

- The Merkle-bound QM31 FRI chain now generated roots from each folded layer before deriving challenges, but it still had no verifier-facing proof object. A caller could benchmark or CPU-check the folded roots, but there was no serialized artifact containing sampled query positions, Merkle decommitments, folded-value consistency checks, or a deterministic verifier contract.

Work completed:

- Added `QM31FRIProof`, `QM31FRIQueryProof`, and `QM31FRILayerQueryProof` as versioned `Codable` proof types. `QM31FRIProof.serialized()` emits deterministic sorted-key JSON, and `QM31FRIProof.deserialize(_:)` fails closed with the package's typed layout error for malformed input.
- Added `QM31FRIProofBuilder.prove`, which commits every current QM31 radix-2 layer as 16-byte little-endian SHA3 Merkle leaves, replays the domain-separated fold-chain transcript, absorbs the serialized final layer, samples query pair indices from the Fiat-Shamir state, and extracts left/right Merkle openings along the queried fold path.
- Added `QM31FRIProofVerifier.verify`, an independent CPU verifier that re-derives fold challenges and query indices from the proof transcript, verifies every Merkle opening against the committed roots, decodes canonical QM31 leaves, checks each folded value appears in the next opened layer, and checks the last folded value against the serialized final layer.
- Made QM31/CM31 field elements and `MerkleOpeningProof` codable so proof objects can be serialized without ad hoc byte munging.
- Added regression coverage for deterministic serialization/deserialization, successful proof verification, final-layer tamper rejection, Merkle leaf tamper rejection, malformed proof shape rejection, and malformed JSON rejection.

Residual risk:

- This is a linear radix-2 QM31 FRI proof format for the layer order consumed by the current fold scheduler. It is not a Circle-domain FRI/PCS proof: Circle twiddle generation, coset/bit-reversal layout, and Circle-specific query mapping remain open protocol work.
- The verifier takes inverse-domain layers as public verifier parameters. A full PCS format still needs a stable domain descriptor that commits to those parameters and to the codeword layout.
- Query count is caller-selected, and this change does not claim a production soundness parameter set. It establishes the typed proof/decommitment surface that future protocol configurations can bind.
- The proof format uses JSON for deterministic developer-facing serialization. A compact binary PCS format remains future work once the Circle-domain layout is fixed.

References:

- S-two Book, FRI prover commitment flow, where each inner layer is folded, committed, and appended to the Fiat-Shamir channel: https://docs.starknet.io/learn/S-two-book/how-it-works/circle-fri/fri_prover
- S-two Book, FRI verifier flow, where commitments are mixed before folding randomness and query positions are sampled afterward: https://docs.starknet.io/learn/S-two-book/how-it-works/circle-fri/fri_verifier
- Stwo core FRI verifier/config source, including secure-field challenges, query count configuration, and fold-step structure: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fri.rs

## 2026-04-13: Merkle-Bound QM31 FRI Fold Chain Roots

Finding:

- The transcript-derived QM31 FRI chain bound challenges to 32-byte commitment roots, but those roots were supplied by the caller. That still left a protocol composition gap: the implementation did not prove that the absorbed roots were produced from the resident evaluation layer being folded in that round.

Work completed:

- Added `QM31FRIMerkleFoldChainOracle`, an independent CPU oracle that serializes each current QM31 layer as 16-byte little-endian raw SHA3 Merkle leaves, commits that layer, absorbs the resulting root into the same domain-separated fold-chain transcript, derives the QM31 challenge, and then folds to the next layer.
- Exposed an internal `SHA3RawLeavesMerkleCommitPlan.encodeCommitmentRoot` encoder so higher-level command plans can write Merkle roots into caller-owned GPU buffers inside an existing command buffer instead of forcing a standalone Merkle command submission.
- Extended `QM31FRIFoldChainPlan` with `executeMerkleTranscriptDerived`, `executeMerkleTranscriptDerivedVerified`, and `executeMerkleTranscriptDerivedResident`. The resident path commits the current layer buffer, absorbs the generated root, squeezes the challenge on GPU, folds into the next resident layer, and repeats. The public verified path checks final values, commitments, and challenges against the CPU oracle.
- Added resident commitment-root output for the Merkle-bound path, so verifier-facing proof construction can consume the generated roots without trusting detached caller-supplied commitment bytes.
- Added CPU and GPU tests for current-layer root binding, root/challenge mutation sensitivity, padded resident root output, malformed layouts, and alias rejection. Added `zkmetal-bench --qm31-fri-fold-chain-merkle` with `challengeMode: "merkle-transcript"` and CPU verification that checks both final folded values and generated roots.

Residual risk:

- The Merkle-bound mode commits the linearly ordered QM31 layer buffers that the current radix-2 fold scheduler consumes. It is not yet a full Circle-domain layout: Circle FFT twiddles, bit-reversal/coset ordering, and domain-specific query mapping remain separate work.
- A linear verifier-facing proof format now samples query positions, extracts Merkle decommitments, serializes proof data, and verifies fold consistency independently. Circle-domain query mapping and a full PCS proof remain separate work.
- The resident path assumes the input and inverse-domain buffers are canonical and protocol-correct by construction. Public array APIs still CPU-check canonicality; private composition must preserve those invariants before this becomes a production proof system.

References:

- S-two Book, FRI prover commitment flow, where each inner layer is folded, committed, and appended to the Fiat-Shamir channel: https://docs.starknet.io/learn/S-two-book/how-it-works/circle-fri/fri_prover
- S-two Book, FRI verifier flow, where roots are mixed before folding randomness and query positions are sampled afterward: https://docs.starknet.io/learn/S-two-book/how-it-works/circle-fri/fri_verifier
- Stwo core FRI verifier/config source, including secure-field challenges and fold-step structure: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fri.rs

## 2026-04-13: Transcript-Derived QM31 FRI Chain Challenges

Finding:

- The chained QM31 FRI fold executor accepted caller-supplied challenges. That was useful for resident composition, but in a FRI protocol each folded-layer commitment must be mixed into the Fiat-Shamir transcript before deriving the next secure-field challenge. Leaving challenge arrays as host material was a composition risk and did not prove that transcript squeeze output could feed the fold kernel without CPU materialization.

Work completed:

- Added `QM31FRIFoldTranscriptOracle`, an independent CPU oracle with a domain-separated framing contract for the QM31 FRI fold chain. The transcript absorbs a versioned header, per-round metadata, the caller-provided 32-byte round commitment root, and a per-round challenge request before squeezing four M31 limbs into one canonical QM31 challenge by rejection sampling.
- Extended `QM31FRIFoldChainPlan` with transcript frame uploads, a commitment-root upload ring, private transcript state, challenge scratch/log buffers, and public `executeTranscriptDerived` / `executeTranscriptDerivedVerified` APIs.
- Added a resident transcript-derived execution path that accepts caller-owned evaluation, inverse-domain, commitment-root, and output buffers. Each round absorbs the current commitment root, squeezes the QM31 challenge on GPU, and passes the challenge buffer directly into the fold kernel before moving to the next layer.
- Added the `qm31_fri_fold_challenge_buffer` Metal kernel so folded layers can consume transcript-derived resident challenge words instead of CPU-supplied challenge structs.
- Added CPU/GPU differential tests covering transcript challenge derivation, commitment mutation sensitivity, malformed roots, resident padded commitment strides, final-output correctness, and alias rejection. Added `zkmetal-bench --qm31-fri-fold-chain-transcript` with JSON reporting that records `challengeMode: "transcript"`.

Residual risk:

- A Merkle-bound mode now builds roots from the resident folded buffers before deriving challenges. The detached-root transcript mode remains useful for integration with an external commitment system, but callers must not treat detached roots as proof that the current buffer was committed unless the higher-level protocol enforces that binding.
- Linear query sampling, decommitment extraction, proof serialization, and an independent verifier now exist for the QM31 radix-2 FRI proof surface. Circle-domain twiddle/layout generation and full PCS binding remain separate protocol work.
- The resident path assumes evaluation, inverse-domain, and commitment-root buffers are protocol-correct and canonical by construction. Public APIs retain CPU oracle checks; private-buffer protocol composition must enforce those invariants at the layer that constructs the roots and layouts.

References:

- S-two Book, FRI verifier flow, where layer commitments are mixed into the channel before drawing secure-field folding randomness: https://docs.starknet.io/learn/S-two-book/how-it-works/circle-fri/fri_verifier
- Stwo core FRI verifier/config source, including secure-field challenges and fold-step structure: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fri.rs
- Stwo CPU FRI folding source, using inverse butterflies and `f0 + alpha * f1` for line and circle-to-line folds: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/prover/backend/cpu/fri.rs

## 2026-04-13: QM31 Multi-Round Resident FRI Fold Chain

Finding:

- The single-layer QM31 FRI fold primitive removed one CPU round-trip, but a real FRI reduction performs repeated folds. Without a chained resident plan, higher-level code would still need to resubmit and synchronize each intermediate layer from the host, or each caller would need to hand-roll scratch-buffer choreography around the field kernel.

Work completed:

- Added `QM31FRIFoldRound` and `QM31FRIFoldChainOracle`, an independent CPU oracle that applies the audited single-layer fold formula repeatedly and preserves the same canonicality, even-input, nonzero inverse-domain, and challenge validation rules.
- Added `QM31FRIFoldChainPlan`, a reusable Metal plan that accepts an input layer size and round count, precomputes every output-layer size and inverse-domain offset, allocates private scratch for intermediate layers, and encodes every fold round into a single command buffer.
- Added a resident `executeResident` API that consumes caller-owned evaluation and concatenated inverse-domain buffers plus per-round QM31 challenges, rejects final-output aliasing with the full input and inverse-domain ranges, and writes only the final folded layer to the caller output buffer. Intermediate layers never leave the private residency arena.
- Added CPU-verified public execution, explicit reusable-buffer clearing, checked sizing for chained inverse-domain buffers, CLI validation for `--fri-fold-rounds`, and benchmark reporting via `zkmetal-bench --qm31-fri-fold-chain`.
- Added deterministic tests for CPU chain equivalence to repeated single-layer folds, malformed round layouts, zero inverse-domain points, noncanonical challenges, GPU/CPU equality, plan reuse after clearing, resident hot-path execution, invalid resident buffer sizes, challenge-count mismatch, and output/input alias rejection.

Residual risk:

- The explicit-challenge chain remains a fold executor for caller-supplied per-round inverse-domain points and Fiat-Shamir challenges. A separate transcript-derived challenge mode now absorbs caller-supplied commitment roots and derives challenges on GPU, but the project still does not compute Circle-domain twiddles, commit folded layers into Merkle trees inside the same plan, choose/query positions, or emit a verifier-facing FRI/PCS proof.
- Resident buffers are treated as already canonical. The public array path validates canonical QM31 limbs and nonzero inverse-domain points; the resident path intentionally avoids CPU readback, so protocol layers using private buffers must maintain those invariants by construction.
- The scratch schedule is linear radix-2 folding over adjacent pairs. Any Circle FFT bit-reversal, coset ordering, or batched codeword layout policy must be introduced as a separately tested layer before this is used in a complete prover.

References:

- Stwo CPU FRI folding source, using inverse butterflies and `f0 + alpha * f1` for line and circle-to-line folds: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/prover/backend/cpu/fri.rs
- Stwo core FRI verifier/config source, including secure-field challenges and fold-step structure: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fri.rs
- Stwo QM31 source, defining `SECURE_EXTENSION_DEGREE = 2`, `R = 2 + i`, and `CM31[x] / (x^2 - R)`: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fields/qm31.rs

## 2026-04-13: QM31 Resident FRI Fold Composition Primitive

Finding:

- The QM31 field lane closed the secure-field arithmetic gap, but the next trust boundary was composition: higher-level codeword/FRI work still needed a way to consume resident QM31 buffers and write the next layer without forcing CPU readback. Without a verified fold primitive, FRI/PCS integration would either copy intermediate layers to the host or duplicate unaudited field formulas inside future command plans.

Work completed:

- Added `QM31FRIFoldOracle`, an independent CPU oracle for one radix-2 FRI fold layer over QM31. The oracle validates canonical limbs, requires an even non-empty input, rejects zero inverse-domain points, and computes `(f(x) + f(-x))/2 + alpha * (f(x) - f(-x)) * inv(point) / 2` for each adjacent pair.
- Added `QM31FRIFoldPlan`, a reusable Metal command plan backed by a private `ResidencyArena`, ring-buffered staging for public array execution, and a caller-owned resident execution path. `executeVerified` compares GPU output against the CPU oracle; `executeResident` accepts caller `MTLBuffer` inputs and writes a caller `MTLBuffer` output while returning only timing stats.
- Added the `qm31_fri_fold` Metal kernel. It reuses the existing QM31 add/subtract/multiply primitives and multiplies by `1/2 = 1073741824 mod 2^31 - 1`.
- Added deterministic regression coverage for the closed-form pair `(1,2,3,4),(4,5,6,7)` with scalar challenge `2`, identical-pair folding, malformed canonical limbs, odd/mismatched layouts, zero inverse-domain rejection, GPU/CPU equality, plan clear/reuse, and the no-readback resident-buffer path.
- Added `zkmetal-bench --qm31-fri-fold`, with schema v1 JSON/text output, CPU digest verification, folded-elements/sec, and input bandwidth reporting. The timed benchmark path uses `executeResident`, so it measures the composition API rather than the public convenience array/readback path.

Residual risk:

- This is one radix-2 fold layer. A separate chained command plan now composes repeated radix-2 folds, but the project still does not implement a complete Circle FFT, transcript-bound FRI protocol, PCS commitment scheme, query/decommitment flow, or verifier-facing proof format.
- `executeResident` assumes the caller already owns canonical QM31 buffers and supplies inverse-domain points in the exact pair order expected by the surrounding domain layout. It rejects output ranges that overlap either input range, but it does not validate canonical limbs inside resident buffers. Callers that cannot prove those invariants must use the public array API or an independent CPU witness during integration.
- The primitive currently accepts precomputed inverse-domain points. A full Circle FFT/FRI composition plan still needs audited domain/twiddle generation, bit-reversal policy, transcript framing, Merkle commitment chaining, and query opening integration.

References:

- Stwo CPU FRI folding source, using inverse butterflies and `f0 + alpha * f1` for line and circle-to-line folds: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/prover/backend/cpu/fri.rs
- Stwo core FRI verifier/config source, including secure-field challenges and fold-step structure: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fri.rs
- Stwo QM31 source, defining `SECURE_EXTENSION_DEGREE = 2`, `R = 2 + i`, and `CM31[x] / (x^2 - R)`: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fields/qm31.rs

## 2026-04-13: QM31 Quartic Secure-Field Primitive

Finding:

- CM31 closed the first quadratic extension-field gap, but Stwo/Circle-STARK verifier-facing challenge arithmetic uses the quartic secure field QM31. Without a first-class QM31 oracle and GPU lane, future Circle FFT, FRI, PCS, and verifier transcript work would either fall back to CPU code or risk implementing incompatible ad hoc field formulas.

Work completed:

- Added `QM31Element` and `QM31Field` for `CM31[u] / (u^2 - 2 - i)`, represented as `(a + bi) + (c + di)u`. The CPU oracle validates canonical M31 limbs and implements add, subtract, negate, multiply, square, inverse, and prefix/suffix batch inversion.
- Added `CM31Field.inverse(_:)` because QM31 inversion reduces through a CM31 denominator.
- Added `QM31VectorOperation` and `QM31VectorArithmeticPlan`, a reusable Metal plan for interleaved four-limb QM31 vectors. The public array path validates canonical input and rejects zero for inversion; `executeUploadedVectors` provides the first resident-buffer hot path for QM31 composition when a caller already owns canonical GPU buffers.
- Added a Metal `qm31_vector_arithmetic` kernel covering add, subtract, negate, multiply, square, and inverse. Multiplication follows the Stwo field model with nonresidue `2 + i`; inversion uses `(A - Bu) / (A^2 - (2+i)B^2)`.
- Added deterministic regression coverage using Stwo-style edge vectors, including `(1,2,3,4) * (4,5,6,7) = (-71,93,-16,50)`, inverse identity checks, batch inversion checks, malformed canonical limbs, zero-inverse rejection, GPU/CPU equality for every QM31 vector operation, explicit clear/reuse, and uploaded-buffer execution.
- Added `zkmetal-bench --qm31-multiply` and `zkmetal-bench --qm31-inverse`, with schema v1 JSON/text output, CPU digest verification, QM31 elements/sec, and input bandwidth reporting.

Residual risk:

- This is a standalone secure-field primitive plus uploaded-vector hot path. A separate resident radix-2 FRI fold primitive now exists, but the project still does not implement Circle FFT, a full multi-round FRI protocol, PCS commitment composition, query/decommitment flow, or verifier-facing proof serialization.
- The GPU inverse path is per-lane. Future FRI/PCS code should compare it against a resident batch-inversion scan once denominator layout and batching are fixed.
- Uploaded-buffer execution assumes canonical QM31 limbs. Callers that cannot prove canonicality must use the public array API or carry an independent CPU witness for verification.

References:

- Stwo QM31 source, defining `SECURE_EXTENSION_DEGREE = 2`, `R = 2 + i`, and `CM31[x] / (x^2 - R)`: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fields/qm31.rs
- Stwo CM31 source, defining `M31[x] / (x^2 + 1)`: https://github.com/starkware-libs/stwo/blob/dev/crates/stwo/src/core/fields/cm31.rs
- Stwo Book, "Mersenne Primes", sections on M31, CM31, and QM31: https://zksecurity.github.io/stwo-book/how-it-works/mersenne-prime.html

## 2026-04-13: CM31 Extension Field Multiplication Primitive

Finding:

- The Phase 3 field-lane roadmap required extension-field multiplication, but the implemented reusable vector surface stopped at base M31 arithmetic. Circle-STARK/Stwo-style paths need the quadratic extension CM31 before Circle FFT, secure challenge packing, and later quartic-field work can be represented without falling back to ad hoc CPU code.

Work completed:

- Added `CM31Element` and `CM31Field`, an independent CPU oracle for `M31[X]/(X^2 + 1)` with canonical validation, componentwise add/subtract/negate, direct-form multiplication, and squaring.
- Added `CM31VectorOperation` and `CM31VectorArithmeticPlan`, a reusable Metal plan for interleaved `real, imaginary` CM31 vectors. The public path validates canonical CM31 elements, copies through ring-buffered shared staging, keeps resident private buffers in a `ResidencyArena`, reads back only the output vector, and exposes `executeVerified` for CPU/GPU equality checks.
- Added a Metal `cm31_vector_arithmetic` kernel. Multiplication uses the three-base-multiply Karatsuba form for `i^2 = -1`; the CPU oracle intentionally uses the direct four-product formula for differential independence.
- Added deterministic CPU regression coverage for edge values `0`, `1`, `i`, `-1`, and `-1 - i`, malformed canonical limbs, binary/unary layout errors, GPU/CPU equality for every CM31 vector operation, and clear/reuse behavior.
- Added `zkmetal-bench --cm31-multiply`, with schema v1 JSON/text output, CPU digest verification, CM31 elements/sec, and input bandwidth reporting.

Residual risk:

- This is a quadratic CM31 lane, not the full QM31 secure-field stack. The next extension step should build quartic multiplication over CM31 with independent test vectors before using extension challenges in a verifier-facing proof format.
- The reusable plan is an uploaded-vector/readback primitive. It does not yet compose CM31 buffers directly into Circle FFT, FRI fold, PCS, or sum-check command plans.

Reference:

- Stwo Book, "Mersenne Primes", sections on M31, CM31, and QM31: https://zksecurity.github.io/stwo-book/how-it-works/mersenne-prime.html

## 2026-04-13: M31 Vector Inversion Primitive

Finding:

- The M31 field-lane roadmap had elementwise arithmetic and dot products, but no inverse primitive. Inversion is required by FRI/PCS denominators, normalization steps, and future batch evaluation code.

Work completed:

- Added `M31Field.inverse(_:)` and `M31Field.batchInverse(_:)`. The batch oracle uses the standard prefix/suffix product method so a nonzero vector is inverted with one field inversion plus linear-time multiplications.
- Added `.inverse` to `M31VectorOperation` and wired the reusable Metal vector arithmetic plan to compute one inverse per nonzero lane using a fixed Fermat exponentiation schedule over the M31 prime field.
- Public vector execution rejects zero and non-canonical values before dispatch. The GPU path remains a canonical-field hot path and does not mask malformed field inputs.
- Added deterministic regression coverage for exact edge inverses of `1`, `2`, `3`, `p - 2`, and `p - 1`, zero rejection, non-canonical rejection, CPU batch-oracle equality, GPU/CPU equality, and plan clear/reuse coverage through the existing vector arithmetic test matrix.
- Added `zkmetal-bench --m31-inverse`, with schema v1 JSON/text output, CPU digest verification, elements/sec, input bandwidth, and device capability reporting.

Residual risk:

- The first GPU path uses per-lane Fermat exponentiation, not a parallel prefix/suffix batch-inversion kernel. It is correct and benchmarked, but future PCS workloads should compare it against a true resident batch-inversion scan once the surrounding codeword layout is fixed.
- The vector inverse public API rejects zero. Protocol layers that need zero-preserving inversion masks must implement and verify that policy explicitly instead of relying on this primitive.

## 2026-04-13: M31 Dot-Product Reduction Primitive

Finding:

- The M31 field-lane roadmap had elementwise vector operations, but it still lacked a reusable dot-product/reduction primitive. Dot products are a core building block for multilinear evaluations, sum-check reductions, PCS work, and codeword pipelines.

Work completed:

- Added `M31Field.dotProduct(lhs:rhs:)`, an independent CPU oracle that validates canonical inputs and accumulates products through the M31 add/multiply operations.
- Added `M31DotProductPlan`, a reusable Metal plan that uploads two vectors, computes per-threadgroup dot-product partials, ping-pongs resident partial reductions, and reads back only the final canonical field element.
- Added `executeVerified`, which compares the GPU result against the CPU oracle before accepting it, plus `executeUploadedVectors` for future GPU-resident composition when the caller already owns canonical private buffers.
- Added explicit reusable-buffer clearing for upload rings, partial buffers, private vector storage, and the one-word readback buffer.
- Added deterministic regression coverage for edge values around `0`, `1`, `p - 2`, and `p - 1`, non-power-of-two vector lengths, uploaded-buffer execution, invalid layouts, and CPU/GPU equality.
- Added `zkmetal-bench --m31-dot-product`, with JSON/text output, CPU verification gating, elements/sec, input bandwidth, threadgroup geometry, and device capability reporting.

Residual risk:

- The initial GPU reduction is a scalar threadgroup-reduction path. It is correct and measured, but it is not yet a simdgroup-specialized or Apple9-atomic accumulation variant.
- Uploaded-buffer execution assumes the buffer already contains canonical M31 elements. Callers that need canonicality checks must use the public array API or keep an independent CPU copy for verification.

## 2026-04-13: M31 Vector Arithmetic Foundation

Finding:

- The sum-check chunk used M31 arithmetic internally, but the field lane roadmap still lacked a first-class reusable vector arithmetic surface with explicit CPU oracle coverage.

Work completed:

- Added canonical M31 CPU oracle operations for add, subtract, negate, multiply, and square using the `2^31 - 1` Mersenne reduction.
- Added `M31VectorArithmeticPlan`, a reusable Metal plan for vector add, subtract, negate, multiply, and square over canonical M31 elements.
- Public array execution validates canonical input before dispatch; `executeVerified` compares the GPU output against the CPU oracle before accepting it.
- Regression coverage now checks edge values around `0`, `1`, `p - 2`, and `p - 1`, non-power-of-two vector lengths, invalid canonical layouts, explicit clear/reuse, and CPU/GPU equality for every implemented operation.

Residual risk:

- This is a standalone field-lane primitive. It does not yet compose field vectors directly into FRI/codeword or PCS command plans, and it does not claim constant-time behavior against a hostile GPU driver or physical observer.

## 2026-04-13: Accelerator Trust And Buffer Hygiene Hardening

Findings:

- Strided GPU hash and Keccak-F permutation APIs returned the full caller-declared output stride. Kernels write only the digest or state bytes, so unwritten padding could retain stale reusable-buffer contents.
- `SharedUploadRing` accepted copies smaller than a slot capacity without clearing the unused slot tail.
- Public tests differentially checked GPU results, but callers had no explicit CPU-verified API for deployments where accelerator execution is not trusted.
- The M31 fold kernels used generic integer remainder for field reduction and also modulo-reduced uploaded values during round evaluation. The public array API already enforces canonical M31 input, so modulo-reducing inputs in-kernel masked malformed uploaded buffers and kept a generic division-like operation in the private-data path.
- Several buffer-size checks depended on unchecked offset or arena arithmetic after earlier validation.

Work completed:

- Fixed-rate SHA3/Keccak hash plans and Keccak-F permutation plans now clear unwritten strided-output padding before returning host-visible `Data`.
- `SharedUploadRing.copy` now clears unused slot tails, and shared-buffer clearing uses an explicit zeroing primitive on Darwin.
- Added CPU-verified accelerator APIs: fixed-rate hash `hashVerified`, Keccak-F `permuteVerified`, raw Merkle `commitRawLeavesVerified` and plan `commitVerified`, planned Merkle `commitVerified`, and M31 sum-check `executeVerified`.
- Replaced the M31 GPU fold path with the `2^31 - 1` Mersenne reduction for canonical M31 values and removed input modulo reduction from round coefficient logging and folding.
- Added overflow-checked buffer offset, arena allocation, and planner layout arithmetic.
- Regression coverage now checks verified APIs, strided-output padding clearing, upload-ring tail clearing, and CPU/GPU M31 chunk equivalence after the reduction change.

Residual risk:

- Verified APIs require CPU-visible inputs. They do not validate private buffers that exist only on the GPU unless the caller also supplies a CPU copy or an independent expected result.
- This work does not defend against a compromised OS, malicious kernel driver, physical memory inspection, or hostile same-device co-tenants.

## 2026-04-13: Transcript Challenge Squeeze Expansion

Finding:

- `SHA3Oracle.TranscriptState.squeezeUInt32` and the GPU `transcript_squeeze_challenges` kernel derived challenge words from a repeated subset of the transcript state. The CPU path wrapped with `index & 15`; the GPU path used the same 16-word window. That was correct for the current one-challenge sum-check round tests, but it was not a sound general transcript squeeze for larger challenge batches.

Work completed:

- CPU challenge squeezing now walks the full SHA3-256 rate as `34` little-endian `UInt32` candidates per block.
- Squeezing beyond the first rate block applies Keccak-F1600 before continuing, matching the sponge construction used by the rest of the SHA3 code.
- CPU and GPU challenge reduction now uses rejection sampling instead of direct modulo reduction, so field elements are unbiased for the requested modulus.
- GPU transcript squeezing now matches the CPU oracle across the first squeeze-block boundary.
- Regression coverage now includes a fixed 40-challenge transcript vector and a GPU/CPU differential test over the same 40-challenge stream.
- The M31 sum-check chunk transcript now absorbs a versioned chunk header, per-round coefficient frame, and per-round challenge frame before deriving challenges.
- Regression coverage now includes a fixed framed M31 sum-check vector.

Reference:

- NIST FIPS 202, SHA-3 Standard: Permutation-Based Hash and Extendable-Output Functions: https://csrc.nist.gov/pubs/fips/202/final

## 2026-04-13: Merkle Opening Extraction And Verification

Finding:

- The Merkle commitment path produced CPU-verified roots, but there was no first-class opening proof API. Callers would have needed to read back or reconstruct intermediate levels outside the reusable GPU plan to answer inclusion queries.

Work completed:

- Added `MerkleOpeningProof` as a public proof object containing the leaf index, leaf bytes, bottom-up sibling hashes, and root.
- Added independent CPU SHA3 Merkle opening construction and verification. Verification hashes the leaf, folds each sibling according to the leaf-index bits, rejects malformed sibling/root layouts, and compares the recomputed root.
- Added a GPU raw-leaf opening path that hashes leaves on the GPU, extracts exactly one sibling node per level with `sha3_256_merkle_extract_sibling_32`, reduces the tree on resident private buffers, and reads back only the sibling path plus root.
- Added `openRawLeafVerified`, which compares the GPU opening against the CPU oracle and also verifies the returned proof against its root before accepting it.
- Regression coverage now checks CPU tamper detection, invalid leaf indices, single-leaf trees, strided fixed-rate leaves, and GPU/CPU opening equality for several leaf positions.

Follow-up:

- The later combined treelet root/opening kernel removed the duplicate target-treelet hash while keeping the same CPU opening oracle gate.

## 2026-04-13: Race-Free Merkle Treelets

Finding:

- The threadgroup-local Merkle treelet and fused-upper kernels compacted parent nodes into the same scratch span that sibling threads could still be reading as child input. CPU/GPU tests passed on the benchmark host, but the layout depended on implicit execution ordering inside a threadgroup and was not an acceptable cryptographic implementation invariant.

Work completed:

- Reworked `sha3_256_merkle_treelet_leaves_specialized` and `sha3_256_merkle_fuse_upper_32` to use two threadgroup scratch halves and swap read/write bases after each level.
- Updated Swift feasibility and dispatch sizing so treelet and fused-upper kernels reserve 64 bytes per live node instead of 32 bytes.
- Added a treelet-aware opening kernel that extracts the lower sibling path from the selected subtree using the same ping-pong reduction discipline. Opening mode now uses a combined variant that writes every selected subtree root and emits the requested lower sibling path during the same treelet reduction.
- Made automatic subtree selection conservative after refreshed Apple M4 / Apple9 smoke data: near-rate 135- and 136-byte SHA3 leaves can select 64-leaf treelets; shorter leaves require explicit fixed mode or planner tuning records.

Residual risk:

- Ping-pong scratch doubles threadgroup memory use and changes the benchmark profile. More devices and tree sizes need measured plan records before promoting additional automatic treelet shapes.

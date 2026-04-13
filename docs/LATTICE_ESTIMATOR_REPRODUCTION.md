# Lattice Estimator Reproduction

AppleZKProver does not currently define lattice-based cryptographic parameters. Do not add a lattice security claim to this repository until the parameter set has an independently reproducible estimator artifact.

This document is the required gate for future lattice parameters. It is deliberately separate from the current transparent proving path so that benchmark or GPU-kernel progress cannot be mistaken for a lattice security review.

## Required Inputs

Every lattice-parameter change must record:

- the exact problem family: LWE, Module-LWE, SIS, Module-SIS, NTRU, or another explicitly named assumption,
- all dimensions, moduli, ranks, norm bounds, and secret/error distributions,
- the source of each parameter value,
- the estimator tool, repository URL, commit hash, and Sage/Python versions,
- the cost model and any deny-list or attack filters used,
- the raw estimator output,
- the interpretation used by the project, including classical and quantum bit-security claims if both are claimed.

## Reproduction Procedure

Use an isolated checkout under `.build/` so estimator dependencies do not become part of the Swift package:

```bash
mkdir -p .build/lattice-estimator
git clone https://github.com/malb/lattice-estimator.git .build/lattice-estimator/src
git -C .build/lattice-estimator/src rev-parse HEAD
sage --version
```

The reproducer must then run a checked-in script or notebook against the exact parameter file under review and store the raw output under `docs/` or `BenchmarkBaselines/` with a date, estimator commit, and host tool versions.

For LWE-family parameters, the reproduction must use the upstream estimator API rather than a project-local reimplementation. A future script should follow this shape, with concrete parameters filled from the reviewed parameter file:

```python
from estimator import LWE

params = ...  # Construct from the reviewed parameter file.
print(LWE.estimate.rough(params))
print(LWE.estimate(params))
```

For SIS-family parameters, use the corresponding estimator API and record the selected norm and solution form. If the upstream estimator cannot model the exact assumption, the finding must say that plainly and must not convert the output into a security claim.

## Independence Rules

- The CPU verifier and Fiat-Shamir transcript must not depend on estimator code.
- Estimator scripts must not import AppleZKProver implementation code.
- A reproduction must be rerun after any parameter, distribution, modulus, protocol, or proof-format change.
- A second reviewer must be able to reproduce the raw output from the committed instructions without relying on local shell history.

## Current Status

No lattice parameters are present in the repository as of 2026-04-13, so no lattice-estimator run has been performed for AppleZKProver. The correct current security claim is therefore: lattice-estimator reproduction is a required future gate, not a completed property of the implemented hash/Merkle/M31 slice.

References:

- Lattice Estimator repository: https://github.com/malb/lattice-estimator
- NIST PQC security discussion context: https://csrc.nist.gov/projects/post-quantum-cryptography

# Irredundant generation in sporadic simple groups

This repository contains the companion code and certificate artifacts for the
computations of \(m(G)\), weak/private-witness \(\operatorname{MaxDim}(G)\),
and \(i(G)\) for selected sporadic simple groups.

The computed values are:

| group | \(m(G)\) | \(\operatorname{MaxDim}(G)\) | \(i(G)\) | flat? | strongly flat? |
| --- | ---: | ---: | ---: | --- | --- |
| \(J_1\) | 4 | 4 | 4 | yes | no |
| \(J_2\) | 5 | 5 | 5 | yes | no |
| \(J_3\) | 4 | 4 | 5 | no | no |
| \(M_{22}\) | 6 | 6 | 6 | yes | yes |
| \(M_{23}\) | 6 | 6 | 6 | yes | no |
| \(M_{24}\) | 7 | 7 | 7 | yes | no |
| \(HS\) | 7 | 7 | 7 | yes | no |
| \(McL\) | 6 | 6 | 6 | yes | no |

Here \(\operatorname{MaxDim}(G)\) means the weak, or private-witness, maximal
subgroup dimension: a family \(M_1,\ldots,M_k\) of maximal subgroups is counted
when

```text
intersection_{j != i} M_j > intersection_j M_j
```

for every \(i\).

## Contents

- `gap/`: group-agnostic GAP framework code and manifest-driven runners.
- `python/`: deterministic tuple verifiers and log/manifest validators.
- `certs/`: tuple certificates, prefix files, and JSON manifests.
- `logs/`: final successful proof logs needed by the manifests.
- `data/`: machine-readable summary of the final bounds.
- `docs/`: short framework notes.
- `tables/`: human-readable tables of the ambient values, maximal-subgroup
  status, and strong-flatness evidence.

The file `data/certificate_runs.json` is the computation manifest. It records
the per-group settings used with the generic GAP runners: target lengths,
selected classes, member-filter choices, prefix splitting, and the logs or
manifests that certify completion. Every ambient upper-bound computation in
the manifest is expressed as: build the conjugation-action workspace once with
`gap/30_build_action_workspace.g`, then load it with
`gap/47_run_framework_cached_upper_bound.g`. Historical case-specific GAP
scripts are kept under `gap/legacy/` only for provenance.

This is intentionally not a full research scratch directory. It excludes
Magma cross-checks, cluster submit wrappers, benchmark/profiling experiments,
PDF/browser render artifacts, obsolete failed runs, and old exploratory logs.

## Requirements

- GAP, with access to the standard sporadic group constructors used by GAP and
  the ATLAS/AtlasRep infrastructure.
- Python 3.

The computations were produced with GAP 4.15.1. The validators are plain
Python scripts and do not require third-party Python packages.

## Quick validation

Run the lightweight certificate checks:

```bash
bash scripts/validate_release.sh
```

This checks all tuple certificates and validates the split/manifest layer for
the large upper-bound computations. Some tuple checks call GAP and may take a
little time.

The table `tables/maximal_subgroup_status.md` records the subgroup-level
information used for the `i(G)` bounds and for strong flatness. It distinguishes
exact values from certified upper bounds and equality witnesses; it should not
be read as a claim that exact `m`, `MaxDim`, and `i` triples were computed for
every maximal subgroup class.

The certificate `certs/agl42_tuple7.json` verifies an irredundant generating
7-tuple in \(AGL(4,2)\cong 2^4:A_8\), the maximal subgroup shape occurring in
\(M_{24}\). This settles the remaining strong-flatness case: \(M_{24}\) is
flat but not strongly flat.

The main individual commands are:

```bash
python3 python/emit_gap_commands.py --all --section m_upper

python3 python/verify_tuple_json.py certs/j3_i5_irredundant_tuple.json

python3 python/validate_prefix_certificate.py \
  --map-log logs/j3_active_depth2_map_v2_create.log \
  --prefix-file certs/j3_active_prefixes_v2.txt \
  --chunk-log-template 'logs/j3_active_v2_prefix_chunk_{task}_create.log' \
  --chunk-size 4

python3 python/validate_prefix_certificate.py \
  --map-log logs/mcl_survivor_depth2_map_cert_create.log \
  --prefix-file certs/mcl_survivor_prefixes_oldmap_lean.txt \
  --chunk-log-template 'logs/mcl_survivor_lean_prefix_chunk_{task}_create.log' \
  --chunk-size 4

python3 python/validate_weakgp_cover.py \
  --group M24 \
  --target 8 \
  --selected-classes 2,3,5,7 \
  --expected-first-ranks 4 \
  --expected-gap-version 4.15.1 \
  --expected-framework-version 2026-05-12-known-i-shortcut \
  --expected-action-degree 6601 \
  --require-metadata \
  --require-class-table \
  --fail-extra-search-prefixes \
  --listing logs/m24_classes2357_depth2_listing_current.log \
  --listing logs/m24_classes2357_branch1_prefixes_1036_1038_listing_current.log \
  --search-glob 'logs/m24_current_no_gp8_prefix_*.log'
```

Class numbers in logs and manifests are GAP-run-local class numbers, interpreted
relative to the maximal-class table printed in the corresponding run.

## Proof architecture

Lower bounds are explicit tuple certificates stored as permutation image lists.
The verifier reconstructs the ambient group, checks tuple membership, computes
the generated subgroup, and verifies irredundance by deleting one tuple entry
at a time.

Upper bounds use the standard reduction

```text
m(G) <= MaxDim(G) <= i(G).
```

The GAP framework searches for weak general-position families of maximal
subgroups. For larger computations, GAP performs the group-theoretic search and
the Python validators check that the distributed logs form a complete,
parameter-consistent cover of the prefix tree.

For \(i(G)\), the code applies the same weak-GP exclusion one level down:
subgroup-class representatives below maximal subgroups are checked, with
manifested shortcuts where a previously established value applies.

See `docs/running_computations.md` for the current group-agnostic entry points.

# Irredundant generation in sporadic simple groups

This repository contains the companion code and certificate artifacts for the
computations of \(m(G)\), weak/private-witness \(\operatorname{MaxDim}(G)\),
and \(i(G)\) for selected sporadic simple groups.

The computed values are:

| group | \(m(G)\) | \(\operatorname{MaxDim}(G)\) | \(i(G)\) |
| --- | ---: | ---: | ---: |
| \(J_1\) | 4 | 4 | 4 |
| \(J_2\) | 5 | 5 | 5 |
| \(J_3\) | 4 | 4 | 5 |
| \(M_{22}\) | 6 | 6 | 6 |
| \(M_{23}\) | 6 | 6 | 6 |
| \(M_{24}\) | 7 | 7 | 7 |
| \(HS\) | 7 | 7 | 7 |
| \(McL\) | 6 | 6 | 6 |

Here \(\operatorname{MaxDim}(G)\) means the weak, or private-witness, maximal
subgroup dimension: a family \(M_1,\ldots,M_k\) of maximal subgroups is counted
when

```text
intersection_{j != i} M_j > intersection_j M_j
```

for every \(i\).

## Contents

- `gap/`: GAP framework code and final group-specific verifiers.
- `python/`: deterministic tuple verifiers and log/manifest validators.
- `certs/`: tuple certificates, prefix files, and JSON manifests.
- `logs/`: final successful proof logs needed by the manifests.
- `data/`: machine-readable summary of the final bounds.
- `docs/`: short framework notes.

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

The main individual commands are:

```bash
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

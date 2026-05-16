# Prefix Upper-Bound Certificates

This file records split prefix computations and the current manifest-validated
upper-bound certificates. Older J3/McL chunk certificates are checked by
`python/validate_prefix_certificate.py`; recursive current-framework covers
are checked by `python/validate_weakgp_cover.py`.

The validator checks that:

- the depth-2 map log completed in listing mode;
- the prefix file exactly matches the prefixes parsed from the map log;
- every expected chunk log exists;
- each chunk log ran the fixed prefixes assigned to that chunk;
- no chunk log contains GAP errors, memory-limit failures, node-limit failures,
  or a found weak-GP counterexample;
- each chunk log reports `RESULT=partial_success` or `RESULT=success`.

## McL

- Group/action log: `logs/mcl_survivor_depth2_map_cert_create.log`
- Prefix file: `certs/mcl_survivor_prefixes_oldmap_lean.txt`
- Chunk logs: `logs/mcl_survivor_lean_prefix_chunk_{0..33}_create.log`
- Validation log: `logs/mcl_survivor_prefix_certificate_validation.log`
- GAP version: `4.15.1`
- Target weak-GP length: `7`
- Selected maximal classes: `[1, 2, 3, 6, 7, 8, 9, 10]`
- Total selected maximal subgroups: `108825`
- Prefixes: `133`
- Chunks: `34`
- Total search nodes: `38755`
- Maximum nodes in one chunk: `19911` in chunk `0`

Validation command:

```bash
python3 python/validate_prefix_certificate.py \
  --map-log logs/mcl_survivor_depth2_map_cert_create.log \
  --prefix-file certs/mcl_survivor_prefixes_oldmap_lean.txt \
  --chunk-log-template 'logs/mcl_survivor_lean_prefix_chunk_{task}_create.log' \
  --chunk-size 4
```

Validation output:

```text
VALID_PREFIX_CERTIFICATE prefixes=133 chunks=34 total_nodes=38755 max_nodes=19911 max_node_chunk=0
```

The maximal-class filter used before this run is recorded in
`logs/mcl_member_i6_filter.log`: survivors were
`[1, 2, 3, 6, 7, 8, 9, 10]`, and excluded classes were `[4, 5, 11, 12]`.

## J3

- Group/action log: `logs/j3_active_depth2_map_v2_create.log`
- Prefix file: `certs/j3_active_prefixes_v2.txt`
- Chunk logs: `logs/j3_active_v2_prefix_chunk_{0..24}_create.log`
- Validation log: `logs/j3_active_v2_prefix_certificate_validation.log`
- GAP version: `4.15.1`
- Target weak-GP length: `5`
- Selected maximal classes: `[1, 2, 3, 4, 6, 7, 8, 9]`
- Total selected maximal subgroups: `192358`
- Prefixes: `97`
- Chunks: `25`
- Total search nodes: `1850`
- Maximum nodes in one chunk: `772` in chunk `0`

Validation command:

```bash
python3 python/validate_prefix_certificate.py \
  --map-log logs/j3_active_depth2_map_v2_create.log \
  --prefix-file certs/j3_active_prefixes_v2.txt \
  --chunk-log-template 'logs/j3_active_v2_prefix_chunk_{task}_create.log' \
  --chunk-size 4
```

Validation output:

```text
VALID_PREFIX_CERTIFICATE prefixes=97 chunks=25 total_nodes=1850 max_nodes=772 max_node_chunk=0
```

The maximal-class filter used before this run is recorded in
`logs/j3_member_i4_filter.log`: survivors were `[1, 2, 3, 4, 6, 7, 8, 9]`,
and excluded class was `[5]`.

## M24

This is the cleaned current-framework replacement for the older ad-hoc M24
split logs.  The member-class exclusions leave only maximal classes
`[2, 3, 5, 7]` for an ambient weak-GP8 search:

- class `1` is excluded by the established `i(M23)=6` computation;
- classes `4`, `6`, `8`, and `9` are excluded by the target-7
  non-exceptional subgroup checks in
  `logs/m24_nonexception_class4_target7_current_clean.log`,
  `logs/m24_nonexception_class6_target7_create.log`, and
  `logs/m24_nonexception_classes8_9_target7.log`.
- the ambient-exclusion manifest
  `certs/m24_ambient_exclusion_manifest.json` validates these five excluded
  classes.

For the surviving classes, the current framework listed the depth-2 prefix
tree, split the two larger prefixes one level further, and completed every
leaf search.

- Top-level listing: `logs/m24_classes2357_depth2_listing_current.log`
- Nested listing: `logs/m24_classes2357_branch1_prefixes_1036_1038_listing_current.log`
- Leaf logs: `logs/m24_current_no_gp8_prefix_*.log`
- Validation log: `logs/m24_current_weakgp_cover_validation.log`
- GAP version: `4.15.1`
- Target weak-GP length: `8`
- Selected maximal classes: `[2, 3, 5, 7]`
- Root prefixes: `27`
- Leaf searches: `41`
- Total search nodes: `4387`

Validation command:

```bash
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

Validation output:

```text
VALID_WEAKGP_COVER roots=27 leaves=41 search_logs=41 total_nodes=4387
```

The proper-subgroup computation for `i(M24)` is now also consolidated:

- Manifest: `certs/m24_i_upper_manifest.json`
- Validation log: `logs/m24_i_upper_manifest_validation.log`
- Validation output:

```text
VALID_I_UPPER_MANIFEST group=M24 target=8 classes=9 shortcuts=1 ranges=15
```

The ambient member-exclusion manifest validates separately:

```text
VALID_I_UPPER_MANIFEST group=M24 target=7 classes=5 shortcuts=1 ranges=4
```

The class-1 shortcut depends on the M23 lower tuple, the M23 no-weak-GP7
upper-bound logs, and the M23 proper-subgroup `i`-upper log, all listed in the
JSON manifest.

## HS

This row no longer needs a broad top-level search.  The current generic
member-class filter leaves only maximal class `5` (`S8`) as a possible member
of a weak-GP8 family:

- Member-filter log: `logs/hs_member_i7_filter_current.log`
- Survivors: `[5]`
- Excluded classes: `[1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12]`

The ambient search restricted to this survivor class then completes directly:

- Manifest: `certs/hs_ambient_upper_manifest.json`
- Validation log: `logs/hs_ambient_upper_manifest_validation.log`
- Upper-bound log: `logs/hs_current_no_gp8_class5.log`
- GAP version: `4.15.1`
- Target weak-GP length: `8`
- Selected maximal classes: `[5]`
- Search nodes: `22`

Relevant log tail:

```text
SURVIVORS=[ 5 ]
EXCLUDED=[ 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12 ]
SUCCESS: framework member-filter run completed for HS.

RESULT=success
NODES=22
SUCCESS: framework no weak-GP8 upper-bound run completed for HS.
```

Validation output:

```text
VALID_MEMBER_FILTER_MANIFEST group=HS target=8 survivors=[5] excluded=11
```

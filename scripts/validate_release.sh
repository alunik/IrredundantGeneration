#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== Tuple certificates =="
for cert in \
  certs/j1_tuple4.json \
  certs/j2_tuple5.json \
  certs/j3_tuple4.json \
  certs/j3_i5_irredundant_tuple.json \
  certs/m22_tuple6.json \
  certs/m23_tuple6.json \
  certs/m24_tuple7.json \
  certs/agl42_tuple7.json \
  certs/hs_tuple7.json \
  certs/mcl_tuple6.json
do
  echo "-- $cert"
  python3 python/verify_tuple_json.py "$cert"
done

echo "== Split prefix certificates =="
python3 python/validate_prefix_certificate.py \
  --map-log logs/j3_active_depth2_map_v2_create.log \
  --prefix-file certs/j3_active_prefixes_v2.txt \
  --chunk-log-template 'logs/j3_active_v2_prefix_chunk_{task}_create.log' \
  --chunk-size 4

grep -q "SUCCESS: no proper subgroup of J3 has weak-GP" \
  logs/j3_proper_i_upper_target6.log

python3 python/validate_prefix_certificate.py \
  --map-log logs/mcl_survivor_depth2_map_cert_create.log \
  --prefix-file certs/mcl_survivor_prefixes_oldmap_lean.txt \
  --chunk-log-template 'logs/mcl_survivor_lean_prefix_chunk_{task}_create.log' \
  --chunk-size 4

echo "== Recursive and manifest certificates =="
python3 python/validate_certificate_runs.py \
  --manifest data/certificate_runs.json

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

python3 python/validate_i_upper_manifest.py \
  --manifest certs/m24_i_upper_manifest.json

python3 python/validate_i_upper_manifest.py \
  --manifest certs/m24_ambient_exclusion_manifest.json

python3 python/validate_member_filter_manifest.py \
  --manifest certs/hs_ambient_upper_manifest.json

python3 python/summarize_hs_i_upper.py \
  --range-file hs_i_upper_ranges.txt \
  --log-dir logs \
  --out /tmp/hs_i_upper_manifest.check.md >/tmp/hs_i_upper_manifest.check.out

python3 python/summarize_mcl_i_upper.py \
  --range-file mcl_i_upper_ranges.txt \
  --log-dir logs \
  --out /tmp/mcl_i_upper_manifest.check.md >/tmp/mcl_i_upper_manifest.check.out

echo "All release checks completed."

#!/usr/bin/env bash
set -euo pipefail

echo "== Tuple certificates =="
for cert in certs/*tuple*.json; do
  base=$(basename "$cert" .json)
  log="logs/${base}_verification.log"
  if [[ ! -f "$log" ]]; then
    echo "missing tuple verification log: $log" >&2
    exit 1
  fi
  grep -q "SUCCESS:" "$log"
  echo "ok $cert"
done

echo "== Ambient manifests =="
for manifest in certs/*_ambient_upper_manifest.json; do
  python3 python/validate_member_filter_manifest.py --manifest "$manifest"
done
for manifest in certs/*_prefix_ambient_manifest.json; do
  [[ -e "$manifest" ]] || continue
  python3 python/validate_prefix_ambient_manifest.py --manifest "$manifest"
done

echo "== Proper-subgroup i-upper manifests =="
for manifest in certs/*_i_upper_manifest.json; do
  python3 python/validate_i_upper_manifest.py --manifest "$manifest"
done

echo "Certificate checks completed."

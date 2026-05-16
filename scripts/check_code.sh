#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== Python syntax =="
python3 -m py_compile python/*.py

echo "== Computation specs =="
python3 python/validate_computation_specs.py \
  --specs data/computation_specs.json

python3 python/emit_gap_commands.py \
  --specs data/computation_specs.json \
  --group J1 \
  --section m_upper >/tmp/irredgen_gap_commands.check

echo "== GAP framework load =="
gap -q -A -c 'WorkspaceRoot:="."; Read("gap/sporadic_registry.g"); Read("gap/upper_bound_library.g"); QUIT;'

echo "Code checks completed."

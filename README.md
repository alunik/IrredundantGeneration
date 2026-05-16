# Irredundant generation framework

This repository contains the group-agnostic code used to compute upper bounds
for \(m(G)\), weak/private-witness \(\operatorname{MaxDim}(G)\), and \(i(G)\)
by searching for weak general-position families of maximal subgroups.

Certificate artifacts are intentionally not included in this cleanup pass.
They will be regenerated once the framework layout is stable.

Here \(\operatorname{MaxDim}(G)\) means the weak, or private-witness, maximal
subgroup dimension: a family \(M_1,\ldots,M_k\) of maximal subgroups is counted
when

```text
intersection_{j != i} M_j > intersection_j M_j
```

for every \(i\).

## Contents

- `gap/`: reusable GAP modules and generic runners.
- `python/`: command emitters, tuple verifiers, and certificate validators.
- `data/computation_specs.json`: group-specific settings for the generic code.
- `docs/`: notes on running and auditing the framework.
- `scripts/check_code.sh`: lightweight code/spec validation.

The public ambient upper-bound workflow is uniform:

1. Build the conjugation action once with `gap/build_action_workspace.g`.
2. Reuse that saved workspace with `gap/run_cached_upper_bound.g`.
3. For large cases, split by fixed prefixes and validate the cover.

The group-specific part is the spec file, not new GAP code.

## Requirements

- GAP, with access to the standard sporadic group constructors used by GAP and
  the ATLAS/AtlasRep infrastructure.
- Python 3.

The computations were developed with GAP 4.15.1. The Python tools use only the
standard library.

## Quick Check

Run:

```bash
bash scripts/check_code.sh
```

This checks Python syntax, validates `data/computation_specs.json`, emits a
sample command from the specs, and verifies that the GAP framework modules
load. It does not claim to validate mathematical certificates; those artifacts
are to be regenerated.

## Commands From Specs

Print the ambient upper-bound commands for all registered groups:

```bash
python3 python/emit_gap_commands.py --all --section m_upper
```

Print the proper-subgroup upper-bound command for one group:

```bash
python3 python/emit_gap_commands.py --group J2 --section i_upper
```

For example, the \(J_1\) ambient run has the form:

```bash
mkdir -p workspaces
gap -q -c 'WorkspaceRoot:=".";TargetGroupName:="J1";ActionWorkspacePath:="workspaces/j1_all_action.ws";Read("gap/build_action_workspace.g");'
gap -q -L workspaces/j1_all_action.ws -c 'WorkspaceRoot:=".";TargetGroupName:="J1";TargetLength:=5;Read("gap/run_cached_upper_bound.g");'
```

## Architecture

Lower-bound certificates, when regenerated, are explicit tuple certificates
stored as permutation image lists. The verifier reconstructs the ambient
group, checks tuple membership, computes the generated subgroup, and verifies
irredundance by deleting one tuple entry at a time.

Upper bounds use the reduction

```text
m(G) <= MaxDim(G) <= i(G).
```

The GAP framework searches for weak general-position families of maximal
subgroups. For \(i(G)\), the same weak-GP exclusion is applied one level down:
subgroup-class representatives below maximal subgroups are checked, with
explicitly registered shortcuts where a previously established value is being
used.

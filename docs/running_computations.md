# Running the computations

The public workflow is spec-driven.  The algorithms live in a small set of
group-agnostic GAP entry points:

- `gap/verify_irredundant_tuple_from_images.g`
- `gap/run_member_filter.g`
- `gap/run_proper_subgroup_upper.g`
- `gap/build_action_workspace.g`
- `gap/run_cached_upper_bound.g`

The file `data/computation_specs.json` records the per-group settings: target
lengths, selected maximal classes, member-filter choices, prefix splitting,
and workspace paths.  A new group should require a new spec entry, not a new
GAP algorithm.

Ambient upper-bound runs always use the same cached-action workflow:

1. Optionally run the member filter to obtain the surviving maximal classes.
2. Build the conjugation action once with `gap/build_action_workspace.g`.
3. Reuse that saved workspace with `gap/run_cached_upper_bound.g`.
4. For large cases, split the search by fixed prefixes and validate the cover.

The helper below prints commands encoded by the specs:

```bash
python3 python/emit_gap_commands.py --group J1 --section m_upper
```

For example, the ambient \(J_1\) run has the form:

```bash
mkdir -p workspaces
gap -q -c 'WorkspaceRoot:=".";TargetGroupName:="J1";ActionWorkspacePath:="workspaces/j1_all_action.ws";Read("gap/build_action_workspace.g");'
gap -q -L workspaces/j1_all_action.ws -c 'WorkspaceRoot:=".";TargetGroupName:="J1";TargetLength:=5;Read("gap/run_cached_upper_bound.g");'
```

The proper-subgroup upper bounds used for \(i(G)\) are also called through one
generic runner:

```bash
python3 python/emit_gap_commands.py --group J2 --section i_upper
```

For prefix-split computations, the same saved action workspace is loaded in
each chunk.  The chunk jobs set `FixedPrefix` or `FixedPrefixes`; the Python
validators check that the resulting logs cover the advertised prefix tree.

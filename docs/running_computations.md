# Running the computations

The public workflow is manifest-driven.  The algorithms live in a small set of
group-agnostic GAP entry points:

- `gap/42_verify_irredundant_tuple_from_images.g`
- `gap/44_run_framework_member_filter.g`
- `gap/46_run_framework_proper_subgroup_upper.g`
- `gap/30_build_action_workspace.g`
- `gap/47_run_framework_cached_upper_bound.g`

The file `data/certificate_runs.json` records the per-group settings: target
lengths, selected maximal classes, whether a member filter was used, whether a
prefix split was used, and which certificate logs validate the run.  The point
is that a new group should require adding a manifest entry and certificates,
not writing a new GAP algorithm.

Ambient upper-bound runs always use the same cached-action workflow, even for
the small groups:

1. Optionally run the member filter to obtain the surviving maximal classes.
2. Build the conjugation action once with `gap/30_build_action_workspace.g`.
3. Reuse that saved workspace with `gap/47_run_framework_cached_upper_bound.g`.
4. For large cases, split the search by fixed prefixes and validate the cover.

The helper below prints the commands encoded by the manifest:

```bash
python3 python/emit_gap_commands.py --group J1 --section m_upper
```

For example, the ambient \(J_1\) run has the form:

```bash
mkdir -p workspaces
gap -q -c 'WorkspaceRoot:=".";TargetGroupName:="J1";ActionWorkspacePath:="workspaces/j1_all_action.ws";Read("gap/30_build_action_workspace.g");'
gap -q -L workspaces/j1_all_action.ws -c 'WorkspaceRoot:=".";TargetGroupName:="J1";TargetLength:=5;Read("gap/47_run_framework_cached_upper_bound.g");'
```

The proper-subgroup upper bounds used for \(i(G)\) are also called through one
generic runner:

```bash
python3 python/emit_gap_commands.py --group J2 --section i_upper
```

For prefix-split computations, the same saved action workspace is loaded in
each chunk.  The chunk jobs set `FixedPrefix` or `FixedPrefixes`; the Python
validators check that the resulting logs cover the advertised prefix tree.

Historical case-specific scripts have been moved to `gap/legacy/`.  They are
kept only to explain older log names and are not part of the public
recomputation interface.

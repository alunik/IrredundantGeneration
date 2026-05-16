# Running the computations

The public workflow is manifest-driven.  The algorithms live in a small set of
group-agnostic GAP entry points:

- `gap/42_verify_irredundant_tuple_from_images.g`
- `gap/43_run_framework_upper_bound.g`
- `gap/44_run_framework_member_filter.g`
- `gap/45_run_framework_filtered_upper_bound.g`
- `gap/46_run_framework_proper_subgroup_upper.g`
- `gap/47_run_framework_cached_upper_bound.g`

The file `data/certificate_runs.json` records the per-group settings: target
lengths, selected maximal classes, whether a member filter was used, whether a
prefix split was used, and which certificate logs validate the run.  The point
is that a new group should require adding a manifest entry and certificates,
not writing a new GAP algorithm.

Examples:

```bash
gap -q -c 'WorkspaceRoot:="."; TargetGroupName:="J1"; TargetLength:=5; Read("gap/43_run_framework_upper_bound.g");'
```

```bash
gap -q -c 'WorkspaceRoot:="."; TargetGroupName:="J2"; TargetProperUpper:=6; CheckStrongFlatTarget:=5; Read("gap/46_run_framework_proper_subgroup_upper.g");'
```

For large groups, first build and save the conjugation action workspace with
`gap/30_build_action_workspace.g`, then run prefix chunks through
`gap/47_run_framework_cached_upper_bound.g`.  The Python validators check that
the resulting logs cover the advertised prefix tree.

Historical case-specific scripts have been moved to `gap/legacy/`.  They are
kept only to explain older log names and are not part of the public
recomputation interface.

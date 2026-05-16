# Upper-Bound Framework

The core upper-bound algorithms are intended to be group-agnostic and loaded
once:

```gap
WorkspaceRoot := ".";;
Read("gap/39_sporadic_registry.g");;
Read("gap/41_upper_bound_library.g");;
```

The library defines two main algorithms.

```gap
data := UB_BuildActionData(G, selectedClasses, opts);;
result := UB_NoWeakGP(data, targetLength, opts);;
```

This is the ambient MaxDim/m upper-bound search.  A successful
`UB_NoWeakGP(data, r, opts)` proves that there is no weak-GP`r` family among
the selected maximal classes.  With all possible classes selected, this proves
`MaxDim(G) <= r-1`, hence `m(G) <= r-1`.

The public certificate workflow builds `data` once and saves it as a GAP
workspace.  Create the workspace directory first, then run:

```gap
WorkspaceRoot := ".";;
TargetGroupName := "J1";;
ActionWorkspacePath := "workspaces/j1_all_action.ws";;
Read("gap/30_build_action_workspace.g");;
```

All ambient upper-bound runs, including the small groups, then load that
workspace and call the cached runner:

```bash
gap -q -L workspaces/j1_all_action.ws -c 'WorkspaceRoot:=".";TargetGroupName:="J1";TargetLength:=5;Read("gap/47_run_framework_cached_upper_bound.g");'
```

This is the same code path used by the prefix-split computations; the only
difference is that a split chunk additionally sets `FixedPrefix` or
`FixedPrefixes`.

If an action has already been built for a larger list of classes, the same
action data can be restricted without recomputing the conjugation action:

```gap
data := UB_RestrictActionData(data, activeClasses);;
```

This only changes the rank/order metadata used by the recursion.  Subgroups in
inactive classes receive rank `0`, are never chosen as candidates, and cannot
start a branch.  The ambient action and subgroup list are otherwise unchanged.
Thus the restricted search proves nonexistence among the active classes, and it
is valid after a separate member-class filter has excluded the inactive
classes.

Several pruning options are enabled by default.  They are certificate-safe only
under the following interpretations.

`use_moved_point_candidate_filter` requires the selected maximal subgroup
representatives to be self-normalizing.  At a node with selected family `S`, the
current full intersection `I` lies in the pointwise stabilizer of `S` on the
maximal-subgroup action.  If a candidate maximal point is fixed by that
pointwise stabilizer, then every element of `I` fixes it; by self-normalizing,
`I` is contained in the candidate maximal subgroup, so the candidate cannot have
a private witness.  Hence only moved points need be considered.

`use_rank_monotone_order` is only a symmetry break: branches are run by the
least selected rank, and later choices are required to have nondecreasing rank.
Every unordered family has at least one ordering satisfying this condition.

`use_dead_set_cache` records selected sets whose entire continuation search has
failed.  The cache key is the unordered selected set.  With rank-monotone
ordering, the last selected rank is determined by the maximum rank already in
the set; within a fixed first-rank branch the future candidate space therefore
depends only on the set, not on the particular order in which equal-rank
subgroups were chosen.  Across branches, cached failures from an earlier
smaller first-rank branch are still failures in later branches because later
branches allow a subset of the candidate ranks.

`list_next_reps_only` is a splitting aid for cluster jobs.  Its output is not a
certificate; each listed prefix must be exhausted by a normal search run, and a
complete certificate must account for every listed prefix.

Cluster wrappers run GAP with `--quitonbreak`, so any GAP `Error(...)` exits
with a nonzero status.  This is required for Slurm `afterok` dependencies:
node-limit failures, found counterexamples, malformed fixed prefixes, and
workspace/class mismatches must stop the dependent certificate pipeline.

For split prefix runs, use `python/validate_prefix_certificate.py` after all
chunks have finished.  The validator checks that the map log completed in
listing mode, that the prefix file exactly matches the map log, and that every
expected chunk log exists and has no error/found/cancelled marker.  This is the
operational coverage check that turns prefix chunks back into one complete
ambient search.

```gap
filter := UB_MemberClassFilter(G, ambientTargetLength, opts);;
```

This is the class filter.  If a maximal subgroup class representative `M` has
no subgroup with weak-GP`(r-1)`, then that class cannot occur in a weak-GP`r`
family of `G`.  The filter returns `survivors` and `excluded`.

The proof must be phrased through a witness-generated subgroup.  If
`M_1,...,M_r` is a weak-GP`r` family in `G` and `M_i=M`, choose private
witnesses `x_j in intersection_{k != j} M_k \\ M_j`.  For `j != i`, all
these witnesses lie in `M`.  Let `K=<x_j : j != i> <= M` and
`L_j=K cap M_j`.  Then `x_j notin L_j`, while `x_j in L_k` for all
`k != i,j`, and `K=<L_j,x_j>`.

For each `j`, choose `N_j` maximal among subgroups `S <= K` with
`L_j <= S` and `x_j notin S`.  Then `N_j` is a maximal subgroup of `K`;
otherwise a larger proper subgroup containing `N_j` would have to contain
`x_j`, forcing it to contain `<L_j,x_j>=K`.  The family `{N_j : j != i}` is
weak-GP`(r-1)` in `K`, witnessed by the same `x_j`.  Therefore, if every
subgroup-class representative below `M` has no weak-GP`(r-1)`, the class of
`M` is impossible in an ambient weak-GP`r` family.

It is not enough to check only `M` itself, or only the maximal subgroups of
`M`.  The witness-generated subgroup `K` can be any subgroup of `M`, which is
why the implementation scans `ConjugacyClassesSubgroups(M)`.  A node-limit
failure must be treated as an error, not as evidence for exclusion.

For example, a small smoke test:

```gap
WorkspaceRoot := ".";;
Read("gap/41_upper_bound_library.g");;
G := AtlasGroup("J1");;
opts := UB_DefaultOptions();;
opts.node_limit := 200000;;
data := UB_BuildActionData(G, fail, opts);;
result := UB_NoWeakGP(data, 5, opts);;
```

For a registered project group, the group-specific part lives outside the
algorithm.  The registry supplies the target length and group constructor, and
`data/certificate_runs.json` records which settings were used for the final
certificates.  Filtering should be computed from the
`MaximalSubgroupClassReps(G)` list in the current GAP session:

```gap
name := "McL";;
G := SP_BuildGroup(name);;
target := SP_MUpperTarget(name);;
filter := UB_MemberClassFilter(G, target, opts);;
data := UB_BuildActionData(G, filter.survivors, opts);;
result := UB_NoWeakGP(data, target, opts);;
```

For certificate runs, write the survivor list from
`gap/44_run_framework_member_filter.g` using `SurvivorOutputPath`, then use
that machine-produced list as the selected classes for
`gap/30_build_action_workspace.g`.  The class numbers are therefore local
labels attached to the GAP maximal-subgroup list used in that run, not
hand-maintained mathematical identifiers.

The current lower-bound and status database is in
`data/sporadic_bounds.json`.  The database is deliberately not used by the
core algorithms; it records witness files, current bounds, and class-filter
outputs for the target groups in this project.

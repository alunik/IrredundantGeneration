if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

Read(Concatenation(WorkspaceRoot, "/gap/common.g"));
Read(Concatenation(WorkspaceRoot, "/gap/sporadic_registry.g"));
Read(Concatenation(WorkspaceRoot, "/gap/upper_bound_library.g"));

if not IsBound(TargetGroupName) then
    Error("Set TargetGroupName.");
fi;

if not IsBound(TargetLength) then
    TargetLength := SP_MUpperTarget(TargetGroupName);
fi;

if not IsBound(SelectedClasses) then
    SelectedClasses := fail;
fi;

if not IsBound(ActiveSelectedClasses) then
    ActiveSelectedClasses := fail;
fi;

if not IsBound(FirstRanks) then
    FirstRanks := fail;
fi;

if not IsBound(NodeLimit) then
    NodeLimit := infinity;
fi;

if not IsBound(ProgressEvery) then
    ProgressEvery := 10000;
fi;

if not IsBound(WitnessSupportThreshold) then
    WitnessSupportThreshold := 5000;
fi;

if not IsBound(WitnessPoolLimit) then
    WitnessPoolLimit := 10000;
fi;

if not IsBound(ListDepth2RepsOnly) then
    ListDepth2RepsOnly := false;
fi;

if not IsBound(UseOrbitFirst) then
    UseOrbitFirst := true;
fi;

if not IsBound(UseFixedSupportCache) then
    UseFixedSupportCache := true;
fi;

if not IsBound(UseRankMonotoneOrder) then
    UseRankMonotoneOrder := true;
fi;

if not IsBound(UseMovedPointCandidateFilter) then
    UseMovedPointCandidateFilter := true;
fi;

if not IsBound(UseDeadSetCache) then
    UseDeadSetCache := true;
fi;

if not IsBound(DeadSetCacheMinDepth) then
    DeadSetCacheMinDepth := 3;
fi;

if not IsBound(FixedPrefix) then
    FixedPrefix := fail;
fi;

if not IsBound(FixedPrefixes) then
    FixedPrefixes := fail;
fi;

if not IsBound(G) or not IsBound(maxReps) or not IsBound(allMax)
   or not IsBound(classOf) or not IsBound(selectedRank)
   or not IsBound(firstOfRank) or not IsBound(actionHom)
   or not IsBound(permAction) then
    Error("Run this script with a prebuilt action workspace loaded by GAP -L.");
fi;

if IsBound(PrebuiltTargetGroupName)
   and PrebuiltTargetGroupName <> TargetGroupName then
    Error("Prebuilt action target group mismatch: expected ",
          TargetGroupName, " but workspace has ", PrebuiltTargetGroupName, ".");
fi;

if IsBound(PrebuiltSelectedClasses) then
    if SelectedClasses <> fail and SelectedClasses <> PrebuiltSelectedClasses then
        Error("Prebuilt action selected classes mismatch.");
    fi;
    SelectedClasses := PrebuiltSelectedClasses;
elif SelectedClasses = fail then
    Error("Set SelectedClasses or load a workspace with PrebuiltSelectedClasses.");
fi;

opts := UB_DefaultOptions();
opts.node_limit := NodeLimit;
opts.progress_every := ProgressEvery;
opts.witness_support_threshold := WitnessSupportThreshold;
opts.witness_pool_limit := WitnessPoolLimit;
opts.use_orbit_first := UseOrbitFirst;
opts.use_fixed_support_cache := UseFixedSupportCache;
opts.use_rank_monotone_order := UseRankMonotoneOrder;
opts.use_moved_point_candidate_filter := UseMovedPointCandidateFilter;
opts.use_dead_set_cache := UseDeadSetCache;
opts.dead_set_cache_min_depth := DeadSetCacheMinDepth;
opts.list_next_reps_only := ListDepth2RepsOnly;
opts.first_ranks := FirstRanks;
opts.fixed_prefix := FixedPrefix;
opts.fixed_prefixes := FixedPrefixes;

data := rec(
    G := G,
    maxReps := maxReps,
    selectedClasses := SelectedClasses,
    allMax := allMax,
    classOf := classOf,
    selectedRank := selectedRank,
    firstOfRank := firstOfRank,
    actionHom := actionHom,
    permAction := permAction,
    fixedSupportCacheKeys := [],
    fixedSupportCacheValues := [],
    witness_support_threshold := WitnessSupportThreshold,
    witness_pool_limit := WitnessPoolLimit,
    use_fixed_support_cache := UseFixedSupportCache
);

if ActiveSelectedClasses <> fail then
    data := UB_RestrictActionData(data, ActiveSelectedClasses);
    Print("Using active selected classes inside prebuilt workspace: ",
          ActiveSelectedClasses, "\n");
fi;

Print("Framework cached upper-bound run for ", TargetGroupName, "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("UB framework version = ", UB_FrameworkVersion, "\n");
Print("Target weak-GP length = ", TargetLength, "\n");
Print("Prebuilt selected maximal classes = ", SelectedClasses, "\n");
if ActiveSelectedClasses <> fail then
    Print("Active maximal classes = ", ActiveSelectedClasses, "\n");
fi;
Print("Total prebuilt maximal subgroups = ", Length(allMax), "\n");
Print("Action degree = ", LargestMovedPoint(permAction),
      " size = ", Size(permAction), "\n");
Print("UseRankMonotoneOrder = ", UseRankMonotoneOrder, "\n");
Print("UseMovedPointCandidateFilter = ", UseMovedPointCandidateFilter, "\n");
Print("UseDeadSetCache = ", UseDeadSetCache,
      " min_depth=", DeadSetCacheMinDepth, "\n");
if FixedPrefix <> fail then
    Print("FixedPrefix = ", FixedPrefix, "\n");
fi;
if FixedPrefixes <> fail then
    Print("FixedPrefixes count = ", Length(FixedPrefixes), "\n");
fi;

result := UB_NoWeakGP(data, TargetLength, opts);

Print("RESULT=", result.status, "\n");
Print("NODES=", result.stats.nodes, "\n");
Print("NODES_BY_DEPTH=", result.stats.nodesByDepth, "\n");
Print("BRANCH_STATS=", result.stats.branchStats, "\n");

if ListDepth2RepsOnly then
    Print("SUCCESS: framework listed next orbit representatives for ",
          TargetGroupName, ". This is a splitting aid, not an upper-bound ",
          "certificate by itself.\n");
elif result.status = "found" then
    Print("FOUND_FAMILY=", result.result.family, "\n");
    Print("FOUND_CLASSES=", result.result.classPattern, "\n");
    Error("Found weak-GP family.");
else
    Print("SUCCESS: framework cached no weak-GP", TargetLength,
          " run completed for ", TargetGroupName,
          " with status ", result.status, ".\n");
fi;

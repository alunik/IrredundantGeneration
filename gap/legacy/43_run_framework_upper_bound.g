if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

Read(Concatenation(WorkspaceRoot, "/gap/39_sporadic_registry.g"));
Read(Concatenation(WorkspaceRoot, "/gap/41_upper_bound_library.g"));

if not IsBound(TargetGroupName) then
    Error("Set TargetGroupName.");
fi;

if not IsBound(SelectedClasses) then
    SelectedClasses := SP_SelectedClassesForMUpper(TargetGroupName);
fi;

if not IsBound(ActiveSelectedClasses) then
    ActiveSelectedClasses := fail;
fi;

if not IsBound(TargetLength) then
    TargetLength := SP_MUpperTarget(TargetGroupName);
fi;

if not IsBound(NodeLimit) then
    NodeLimit := infinity;
fi;

if not IsBound(ProgressEvery) then
    ProgressEvery := 10000;
fi;

if not IsBound(UseMovedPointCandidateFilter) then
    UseMovedPointCandidateFilter := true;
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

if not IsBound(UseDeadSetCache) then
    UseDeadSetCache := true;
fi;

if not IsBound(ListNextRepsOnly) then
    ListNextRepsOnly := false;
fi;

if not IsBound(FixedPrefix) then
    FixedPrefix := fail;
fi;

if not IsBound(FixedPrefixes) then
    FixedPrefixes := fail;
fi;

G := SP_BuildGroup(TargetGroupName);

opts := UB_DefaultOptions();
opts.node_limit := NodeLimit;
opts.progress_every := ProgressEvery;
opts.use_orbit_first := UseOrbitFirst;
opts.use_fixed_support_cache := UseFixedSupportCache;
opts.use_moved_point_candidate_filter := UseMovedPointCandidateFilter;
opts.use_rank_monotone_order := UseRankMonotoneOrder;
opts.use_dead_set_cache := UseDeadSetCache;
opts.list_next_reps_only := ListNextRepsOnly;
opts.fixed_prefix := FixedPrefix;
opts.fixed_prefixes := FixedPrefixes;

Print("Framework upper-bound run for ", TargetGroupName, "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("UB framework version = ", UB_FrameworkVersion, "\n");
Print("Target weak-GP length = ", TargetLength, "\n");
Print("Selected classes = ", SelectedClasses, "\n");
if ActiveSelectedClasses <> fail then
    Print("Active classes = ", ActiveSelectedClasses, "\n");
fi;

data := UB_BuildActionData(G, SelectedClasses, opts);
if ActiveSelectedClasses <> fail then
    data := UB_RestrictActionData(data, ActiveSelectedClasses);
fi;
result := UB_NoWeakGP(data, TargetLength, opts);

Print("RESULT=", result.status, "\n");
Print("NODES=", result.stats.nodes, "\n");
Print("NODES_BY_DEPTH=", result.stats.nodesByDepth, "\n");
Print("BRANCH_STATS=", result.stats.branchStats, "\n");

if ListNextRepsOnly then
    Print("SUCCESS: framework listed next orbit representatives for ",
          TargetGroupName, ". This is a splitting aid, not an upper-bound ",
          "certificate by itself.\n");
elif result.status = "found" then
    Print("FOUND_FAMILY=", result.result.family, "\n");
    Print("FOUND_CLASSES=", result.result.classPattern, "\n");
    Error("Found weak-GP family.");
elif result.status = "success" then
    Print("SUCCESS: framework no weak-GP", TargetLength,
          " upper-bound run completed for ", TargetGroupName, ".\n");
elif result.status = "partial_success" then
    Print("PARTIAL_SUCCESS: restricted framework no weak-GP", TargetLength,
          " run completed for ", TargetGroupName,
          ". This must be combined with the matching split/coverage ",
          "certificate.\n");
fi;

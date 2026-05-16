if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

Read(Concatenation(WorkspaceRoot, "/gap/39_sporadic_registry.g"));
Read(Concatenation(WorkspaceRoot, "/gap/41_upper_bound_library.g"));

if not IsBound(TargetGroupName) then
    Error("Set TargetGroupName.");
fi;

if not IsBound(TargetLength) then
    TargetLength := SP_MUpperTarget(TargetGroupName);
fi;

if not IsBound(NodeLimit) then
    NodeLimit := infinity;
fi;

if not IsBound(MemberFilterNodeLimit) then
    MemberFilterNodeLimit := 1000000;
fi;

if not IsBound(ProgressEvery) then
    ProgressEvery := infinity;
fi;

G := SP_BuildGroup(TargetGroupName);
opts := UB_DefaultOptions();
opts.node_limit := NodeLimit;
opts.progress_every := ProgressEvery;
opts.member_filter_signature_opts.node_limit := MemberFilterNodeLimit;
opts.member_filter_signature_opts.progress_every := ProgressEvery;
opts.known_i_upper_bound := SP_KnownIUpperBoundSubgroup;

Print("Framework filtered upper-bound run for ", TargetGroupName, "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("UB framework version = ", UB_FrameworkVersion, "\n");
Print("Target weak-GP length = ", TargetLength, "\n");

result := UB_NoWeakGPWithMemberFilter(G, TargetLength, opts);

Print("FILTER_SURVIVORS=", result.filter.survivors, "\n");
Print("FILTER_EXCLUDED=", result.filter.excluded, "\n");
Print("RESULT=", result.status, "\n");
Print("REASON=", result.reason, "\n");
if result.search <> fail then
    Print("SEARCH_NODES=", result.search.stats.nodes, "\n");
    Print("SEARCH_NODES_BY_DEPTH=", result.search.stats.nodesByDepth, "\n");
    Print("SEARCH_BRANCH_STATS=", result.search.stats.branchStats, "\n");
fi;

if result.status = "found" then
    Error("Found weak-GP family.");
fi;

if result.status = "success" then
    Print("SUCCESS: framework filtered no weak-GP", TargetLength,
          " upper-bound run completed for ", TargetGroupName, ".\n");
else
    Print("PARTIAL_SUCCESS: framework filtered restricted run completed for ",
          TargetGroupName, ". Combine with the matching coverage ",
          "certificate before using as an upper bound.\n");
fi;

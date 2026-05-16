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
    NodeLimit := 1000000;
fi;

if not IsBound(ProgressEvery) then
    ProgressEvery := infinity;
fi;

G := SP_BuildGroup(TargetGroupName);
opts := UB_DefaultOptions();
opts.member_filter_signature_opts.node_limit := NodeLimit;
opts.member_filter_signature_opts.progress_every := ProgressEvery;
opts.known_i_upper_bound := SP_KnownIUpperBoundSubgroup;

Print("Framework member-filter run for ", TargetGroupName, "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("UB framework version = ", UB_FrameworkVersion, "\n");
Print("Ambient target weak-GP length = ", TargetLength, "\n");

result := UB_MemberClassFilter(G, TargetLength, opts);
Print("SURVIVORS=", result.survivors, "\n");
Print("EXCLUDED=", result.excluded, "\n");
if IsBound(SurvivorOutputPath) then
    PrintTo(SurvivorOutputPath, result.survivors, "\n");
    Print("WROTE_SURVIVORS=", SurvivorOutputPath, "\n");
fi;
if IsBound(ExcludedOutputPath) then
    PrintTo(ExcludedOutputPath, result.excluded, "\n");
    Print("WROTE_EXCLUDED=", ExcludedOutputPath, "\n");
fi;
Print("SUCCESS: framework member-filter run completed for ",
      TargetGroupName, ".\n");

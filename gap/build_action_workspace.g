if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;
Read(Concatenation(WorkspaceRoot, "/gap/common.g"));
Read(Concatenation(WorkspaceRoot, "/gap/sporadic_registry.g"));
Read(Concatenation(WorkspaceRoot, "/gap/upper_bound_library.g"));

if not IsBound(TargetGroupName) then
    Error("Set TargetGroupName.");
fi;

if not IsBound(ActionWorkspacePath) then
    Error("Set ActionWorkspacePath.");
fi;

if not IsBound(SelectedClasses) then
    SelectedClasses := fail;
fi;

if not IsBound(WitnessSupportThreshold) then
    WitnessSupportThreshold := 5000;
fi;

if not IsBound(WitnessPoolLimit) then
    WitnessPoolLimit := 10000;
fi;

if not IsBound(UseFixedSupportCache) then
    UseFixedSupportCache := true;
fi;

if not IsBound(UseMovedPointCandidateFilter) then
    UseMovedPointCandidateFilter := true;
fi;

Print("Building reusable action workspace for ", TargetGroupName, "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("UB framework version = ", UB_FrameworkVersion, "\n");

G := SP_BuildGroup(TargetGroupName);
Print("Built ", TargetGroupName, ", order = ", Size(G));
if IsPermGroup(G) then
    Print(", degree = ", LargestMovedPoint(G));
fi;
Print("\n");

t := Runtime();
opts := UB_DefaultOptions();
opts.witness_support_threshold := WitnessSupportThreshold;
opts.witness_pool_limit := WitnessPoolLimit;
opts.use_fixed_support_cache := UseFixedSupportCache;
opts.use_moved_point_candidate_filter := UseMovedPointCandidateFilter;

data := UB_BuildActionData(G, SelectedClasses, opts);

maxReps := data.maxReps;
SelectedClasses := data.selectedClasses;
allMax := data.allMax;
classOf := data.classOf;
selectedRank := data.selectedRank;
firstOfRank := data.firstOfRank;
actionHom := data.actionHom;
permAction := data.permAction;

Print("Selected maximal classes = ", SelectedClasses, "\n");
Print("Total selected maximal subgroups = ", Length(allMax), "\n");
Print("Action degree = ", LargestMovedPoint(permAction),
      " size = ", Size(permAction),
      " build_ms = ", Runtime() - t, "\n");

PrebuiltTargetGroupName := TargetGroupName;
PrebuiltSelectedClasses := ShallowCopy(SelectedClasses);

Print("Saving workspace to ", ActionWorkspacePath, "\n");
if not SaveWorkspace(ActionWorkspacePath) then
    Error("SaveWorkspace failed.");
fi;
Print("SUCCESS: saved reusable action workspace.\n");

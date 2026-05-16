if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

SkipM22IVerifier := true;
Read(Concatenation(WorkspaceRoot, "/gap/10_verify_i_m22.g"));

if not IsBound(TargetGroupName) then
    Error("Set TargetGroupName.");
fi;

if not IsBound(MemberWitnessLength) then
    MemberWitnessLength := 6;
fi;

if not IsBound(SelectedTopClasses) then
    SelectedTopClasses := fail;
fi;

G := AtlasGroup(TargetGroupName);
if G = fail then
    Error("Could not build Atlas group ", TargetGroupName);
fi;
iso := IsomorphismPermGroup(G);
G := Image(iso);

Print("Built ", TargetGroupName, ", order = ", Size(G),
      ", degree = ", LargestMovedPoint(G), "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("Member witness length = ", MemberWitnessLength, "\n");
Print("MaxDimSearchNodeLimit = ", MaxDimSearchNodeLimit, "\n");

maxReps := MaximalSubgroupClassReps(G);
if SelectedTopClasses = fail then
    SelectedTopClasses := [1..Length(maxReps)];
fi;

survivors := [];
excluded := [];

for c in SelectedTopClasses do
    M := maxReps[c];
    Print("Top class ", c, ": size=", Size(M),
          " struct=", StructureDescription(M), "\n");
    subReps := List(ConjugacyClassesSubgroups(M), Representative);
    Print("  subgroup class reps = ", Length(subReps), "\n");

    found := false;
    checked := 0;
    for K in subReps do
        checked := checked + 1;
        if checked mod 25 = 0 then
            Print("  checked ", checked, "/", Length(subReps), "\n");
        fi;
        result := WeakGPFamilyBySignatures(K, MemberWitnessLength);
        if result <> fail then
            found := true;
            Print("  KEEP class ", c, ": subgroup index ", checked,
                  " size=", Size(K),
                  " struct=", StructureDescription(K),
                  " has weak-GP", MemberWitnessLength,
                  " classPattern=", result.classPattern, "\n");
            break;
        fi;
    od;

    if found then
        Add(survivors, c);
    else
        Add(excluded, c);
        Print("  EXCLUDE class ", c,
              ": no subgroup class representative has weak-GP",
              MemberWitnessLength, ".\n");
    fi;
od;

Print("SURVIVORS=", survivors, "\n");
Print("EXCLUDED=", excluded, "\n");
Print("SUCCESS: member-i filter complete for ", TargetGroupName, ".\n");

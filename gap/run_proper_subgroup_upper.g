if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

Read(Concatenation(WorkspaceRoot, "/gap/sporadic_registry.g"));
Read(Concatenation(WorkspaceRoot, "/gap/signature_weakgp_library.g"));

if not IsBound(TargetGroupName) then
    Error("Set TargetGroupName.");
fi;

if not IsBound(TargetProperUpper) then
    Error("Set TargetProperUpper to the excluded weak-GP length.");
fi;

if not IsBound(SelectedTopClasses) then
    SelectedTopClasses := fail;
fi;

if not IsBound(SubgroupStart) then
    SubgroupStart := 1;
fi;

if not IsBound(SubgroupStop) then
    SubgroupStop := infinity;
fi;

if not IsBound(ProgressEverySubgroups) then
    ProgressEverySubgroups := 25;
fi;

if not IsBound(DeduplicateBySizeStructure) then
    DeduplicateBySizeStructure := false;
fi;

if not IsBound(OnlyListSubgroupCounts) then
    OnlyListSubgroupCounts := false;
fi;

if not IsBound(UseKnownSubgroupShortcuts) then
    UseKnownSubgroupShortcuts := true;
fi;

if not IsBound(CheckStrongFlatTarget) then
    CheckStrongFlatTarget := fail;
fi;

if not IsBound(SignatureNodeLimit) then
    SignatureNodeLimit := 1000000;
fi;

if not IsBound(SignatureProgressEvery) then
    SignatureProgressEvery := infinity;
fi;

SP_SubgroupSignatureForDedup := function(K)
    return Concatenation(String(Size(K)), ":", StructureDescription(K));
end;

SP_RunWeakGPOrShortcut := function(K, target, opts)
    local shortcut;

    if UseKnownSubgroupShortcuts then
        shortcut := SP_KnownNoWeakGPSubgroup(K, target);
        if shortcut <> fail then
            Print("    shortcut: ", shortcut.reason);
            if IsBound(shortcut.group) then
                Print(" group=", shortcut.group);
            fi;
            if IsBound(shortcut.i_upper) then
                Print(" i_upper=", shortcut.i_upper);
            fi;
            if IsBound(shortcut.no_weak_gp) then
                Print(" no_weak_gp=", shortcut.no_weak_gp);
            fi;
            if IsBound(shortcut.proof) then
                Print(" dependency=", shortcut.proof);
            fi;
            Print(" excludes weak-GP", target, ".\n");
            return fail;
        fi;
    fi;

    return SIG_WeakGPFamily(K, target, opts);
end;

G := SP_BuildGroup(TargetGroupName);
Print("Built ", TargetGroupName, ", order = ", Size(G),
      ", degree = ", LargestMovedPoint(G), "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("Signature framework version = ", SIG_FrameworkVersion, "\n");
Print("Target proper-subgroup weak-GP exclusion length = ",
      TargetProperUpper, "\n");
Print("Subgroup index range = [", SubgroupStart, ", ", SubgroupStop, "]\n");
Print("UseKnownSubgroupShortcuts = ", UseKnownSubgroupShortcuts, "\n");
Print("DeduplicateBySizeStructure = ", DeduplicateBySizeStructure, "\n");
if CheckStrongFlatTarget <> fail then
    Print("Strong-flat probe exclusion length = ",
          CheckStrongFlatTarget, "\n");
fi;

maxReps := MaximalSubgroupClassReps(G);
if SelectedTopClasses = fail then
    SelectedTopClasses := [1..Length(maxReps)];
fi;

Print("Maximal subgroup classes = ", Length(maxReps), "\n");
for classIndex in [1..Length(maxReps)] do
    Print(classIndex, ": size=", Size(maxReps[classIndex]),
          " index=", Size(G) / Size(maxReps[classIndex]),
          " struct=", StructureDescription(maxReps[classIndex]), "\n");
od;
Print("Selected top maximal classes = ", SelectedTopClasses, "\n");

sigOpts := rec(node_limit := SignatureNodeLimit,
               progress_every := SignatureProgressEvery);
seen := [];
checked := 0;
strongWitnesses := [];

for classIndex in SelectedTopClasses do
    M := maxReps[classIndex];
    Print("Checking ", TargetGroupName, " maximal class ", classIndex,
          ": size=", Size(M), " struct=", StructureDescription(M),
          " target_no_weakGP=", TargetProperUpper, "\n");

    if UseKnownSubgroupShortcuts
       and SP_KnownNoWeakGPSubgroup(M, TargetProperUpper) <> fail then
        SP_RunWeakGPOrShortcut(M, TargetProperUpper, sigOpts);
        Print("  shortcut: top maximal class ", classIndex,
              " has certified no weak-GP", TargetProperUpper,
              " in all subgroups.\n");
        continue;
    fi;

    t := Runtime();
    subReps := List(ConjugacyClassesSubgroups(M), Representative);
    Print("  subgroup class representatives = ", Length(subReps),
          " enumeration_ms=", Runtime() - t, "\n");

    if OnlyListSubgroupCounts then
        continue;
    fi;

    started := Maximum(1, SubgroupStart);
    stopped := Minimum(Length(subReps), SubgroupStop);
    if started > stopped then
        Print("  empty requested subgroup-index range [", SubgroupStart,
              ", ", SubgroupStop, "] for class ", classIndex, "\n");
        continue;
    fi;

    for localIndex in [started..stopped] do
        K := subReps[localIndex];
        if DeduplicateBySizeStructure then
            sig := SP_SubgroupSignatureForDedup(K);
            if sig in seen then
                continue;
            fi;
            Add(seen, sig);
        fi;

        checked := checked + 1;
        if checked = 1 or checked mod ProgressEverySubgroups = 0 then
            Print("  checked=", checked,
                  " top_class=", classIndex,
                  " local_index=", localIndex,
                  " size=", Size(K),
                  " struct=", StructureDescription(K), "\n");
        fi;

        t := Runtime();
        result := SP_RunWeakGPOrShortcut(K, TargetProperUpper, sigOpts);
        elapsed := Runtime() - t;
        if result <> fail then
            Print("FOUND weak-GP", TargetProperUpper,
                  " in subgroup below ", TargetGroupName,
                  " top_class=", classIndex,
                  " local_index=", localIndex,
                  " size=", Size(K),
                  " struct=", StructureDescription(K), "\n");
            Print("  family=", result.family,
                  " classPattern=", result.classPattern,
                  " maximalCount=", result.maximalCount,
                  " signatureCount=", result.signatureCount, "\n");
            Error("Proper-subgroup i upper bound failed.");
        fi;

        if CheckStrongFlatTarget <> fail then
            result := SIG_WeakGPFamily(K, CheckStrongFlatTarget, sigOpts);
            if result <> fail then
                Add(strongWitnesses, rec(
                    topClass := classIndex,
                    localIndex := localIndex,
                    size := Size(K),
                    structure := StructureDescription(K),
                    family := result.family,
                    classPattern := result.classPattern,
                    maximalCount := result.maximalCount,
                    signatureCount := result.signatureCount
                ));
                Print("  strong-flat obstruction: weak-GP",
                      CheckStrongFlatTarget,
                      " in size=", Size(K),
                      " struct=", StructureDescription(K),
                      " classPattern=", result.classPattern, "\n");
            fi;
        fi;

        if elapsed > 1000 then
            Print("    completed local_subgroup_index=", localIndex,
                  " elapsed_ms=", elapsed, "\n");
        fi;
    od;

    Print("  completed ", TargetGroupName, " maximal class ", classIndex,
          " checked=", stopped - started + 1,
          " requested_range=[", started, ", ", stopped, "]",
          " no weak-GP", TargetProperUpper, " found.\n");
od;

Print("Checked subgroup-class representatives = ", checked, "\n");
if DeduplicateBySizeStructure then
    Print("Deduplicated size/structure signatures = ", Length(seen), "\n");
fi;

Print("SUCCESS: no proper subgroup of ", TargetGroupName,
      " has weak-GP", TargetProperUpper,
      "; hence every proper subgroup has i <= ",
      TargetProperUpper - 1, ".\n");

if CheckStrongFlatTarget <> fail then
    if Length(strongWitnesses) = 0 then
        Print("SUCCESS: no proper subgroup has weak-GP",
              CheckStrongFlatTarget, ".\n");
    else
        Print("Proper subgroup weak-GP", CheckStrongFlatTarget,
              " witnesses found: ", Length(strongWitnesses), "\n");
        Print(strongWitnesses[1], "\n");
    fi;
fi;

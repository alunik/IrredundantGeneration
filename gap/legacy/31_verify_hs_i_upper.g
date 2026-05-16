if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

SkipM22IVerifier := true;
Read(Concatenation(WorkspaceRoot, "/gap/10_verify_i_m22.g"));

if not IsBound(TargetProperUpper) then
    TargetProperUpper := 8;
fi;

if not IsBound(SelectedTopClasses) then
    SelectedTopClasses := [1..12];
fi;

if not IsBound(ProgressEverySubgroups) then
    ProgressEverySubgroups := 25;
fi;

if not IsBound(SubgroupStart) then
    SubgroupStart := 1;
fi;

if not IsBound(SubgroupStop) then
    SubgroupStop := infinity;
fi;

if not IsBound(UseKnownSubgroupShortcuts) then
    UseKnownSubgroupShortcuts := true;
fi;

if not IsBound(DeduplicateBySizeStructure) then
    DeduplicateBySizeStructure := false;
fi;

if not IsBound(OnlyListSubgroupCounts) then
    OnlyListSubgroupCounts := false;
fi;

BuildHSForI := function()
    local G;

    G := PrimitiveGroup(100, 3);
    if Size(G) <> 44352000 then
        Error("PrimitiveGroup(100,3) did not build HS.");
    fi;
    return G;
end;

SubgroupSignatureForHSI := function(K)
    return Concatenation(String(Size(K)), ":", StructureDescription(K));
end;

KnownNoWeakGPShortcutHS := function(K, target)
    local desc;

    if target <= 7 then
        return false;
    fi;

    if Size(K) < 2^target then
        return true;
    fi;

    desc := StructureDescription(K);

    if Size(K) = 443520 and desc = "M22" then
        Print("    shortcut: previous deterministic M22 result gives ",
              "i(M22)=6, so no weak-GP", target, " occurs here.\n");
        return true;
    fi;

    return false;
end;

CheckHSMaximalClassForNoWeakGP := function(M, classIndex, target)
    local subReps, checked, localIndex, K, result, started, stopped, t,
          elapsed, seen, sig;

    Print("Checking HS maximal class ", classIndex,
          ": size=", Size(M), " struct=", StructureDescription(M),
          " target_no_weakGP=", target, "\n");

    if UseKnownSubgroupShortcuts and Size(M) = 443520
       and StructureDescription(M) = "M22" then
        Print("  shortcut: top class is M22. Previous deterministic ",
              "M22 computation proves i(M22)=6, hence no subgroup below ",
              "this class has weak-GP", target, ".\n");
        return true;
    fi;

    t := Runtime();
    subReps := List(ConjugacyClassesSubgroups(M), Representative);
    Print("  subgroup class representatives = ", Length(subReps),
          " enumeration_ms=", Runtime() - t, "\n");

    if OnlyListSubgroupCounts then
        return true;
    fi;

    checked := 0;
    seen := [];
    started := Maximum(1, SubgroupStart);
    stopped := Minimum(Length(subReps), SubgroupStop);

    if started > stopped then
        Print("  empty requested subgroup-index range [", SubgroupStart,
              ", ", SubgroupStop, "] for class ", classIndex, "\n");
        return true;
    fi;

    for localIndex in [started..stopped] do
        K := subReps[localIndex];

        if DeduplicateBySizeStructure then
            sig := SubgroupSignatureForHSI(K);
            if sig in seen then
                continue;
            fi;
            Add(seen, sig);
        fi;

        checked := checked + 1;
        if checked = 1 or checked mod ProgressEverySubgroups = 0 then
            Print("  checking local_subgroup_index=", localIndex,
                  " checked_in_range=", checked,
                  " size=", Size(K),
                  " struct=", StructureDescription(K), "\n");
        fi;

        t := Runtime();
        if UseKnownSubgroupShortcuts
           and KnownNoWeakGPShortcutHS(K, target) then
            result := fail;
        else
            result := WeakGPFamilyBySignatures(K, target);
        fi;
        elapsed := Runtime() - t;

        if result <> fail then
            Print("FOUND weak-GP", target,
                  " below HS maximal class ", classIndex,
                  " local_subgroup_index=", localIndex,
                  " subgroup_size=", Size(K),
                  " subgroup_struct=", StructureDescription(K), "\n");
            Print("  family=", result.family,
                  " classPattern=", result.classPattern,
                  " maximalCount=", result.maximalCount,
                  " signatureCount=", result.signatureCount, "\n");
            Error("HS i upper-bound obstruction failed.");
        fi;

        if elapsed > 1000 then
            Print("    completed local_subgroup_index=", localIndex,
                  " elapsed_ms=", elapsed, "\n");
        fi;
    od;

    Print("  completed HS maximal class ", classIndex,
          " checked=", checked,
          " requested_range=[", started, ", ", stopped, "]",
          " no weak-GP", target, " found.\n");
    return true;
end;

G := BuildHSForI();
Print("Built HS, order = ", Size(G), ", degree = ", LargestMovedPoint(G), "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("Target proper-subgroup weak-GP exclusion length = ",
      TargetProperUpper, "\n");
Print("Selected top maximal classes = ", SelectedTopClasses, "\n");
Print("Subgroup index range = [", SubgroupStart, ", ", SubgroupStop, "]\n");
Print("UseKnownSubgroupShortcuts = ", UseKnownSubgroupShortcuts, "\n");
Print("DeduplicateBySizeStructure = ", DeduplicateBySizeStructure, "\n");

maxReps := MaximalSubgroupClassReps(G);
Print("HS maximal subgroup classes = ", Length(maxReps), "\n");
for i in [1..Length(maxReps)] do
    Print(i, ": size=", Size(maxReps[i]),
          " index=", Size(G)/Size(maxReps[i]),
          " struct=", StructureDescription(maxReps[i]), "\n");
od;

for classIndex in SelectedTopClasses do
    CheckHSMaximalClassForNoWeakGP(maxReps[classIndex], classIndex,
                                   TargetProperUpper);
od;

Print("SUCCESS: selected HS maximal classes have no subgroup with weak-GP",
      TargetProperUpper, " in the checked ranges.\n");
Print("When run for all classes 1..12 with TargetProperUpper=8, this proves ",
      "every proper subgroup of HS has i <= 7. Combined with m(HS)=7, ",
      "this gives i(HS)=7.\n");

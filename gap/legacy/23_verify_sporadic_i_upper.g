if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

SkipM22IVerifier := true;
Read(Concatenation(WorkspaceRoot, "/gap/10_verify_i_m22.g"));

if not IsBound(TargetGroupName) then
    Error("Set TargetGroupName, for example: TargetGroupName := \"J1\".");
fi;

if not IsBound(TargetProperUpper) then
    Error("Set TargetProperUpper to the excluded weak-GP length.");
fi;

if not IsBound(CheckStrongFlatTarget) then
    CheckStrongFlatTarget := fail;
fi;

if not IsBound(ProgressEverySubgroups) then
    ProgressEverySubgroups := 25;
fi;

if not IsBound(DeduplicateBySizeStructure) then
    DeduplicateBySizeStructure := false;
fi;

if not IsBound(SubgroupStart) then
    SubgroupStart := 1;
fi;

if not IsBound(SubgroupStop) then
    SubgroupStop := infinity;
fi;

if not IsBound(OnlyListSubgroupCounts) then
    OnlyListSubgroupCounts := false;
fi;

if not IsBound(UseKnownSubgroupShortcuts) then
    UseKnownSubgroupShortcuts := true;
fi;

if not IsBound(MaxDimSearchNodeLimit) then
    MaxDimSearchNodeLimit := 1000000;
fi;

SubgroupSignatureForDedup := function(K)
    return Concatenation(String(Size(K)), ":", StructureDescription(K));
end;

KnownNoWeakGPShortcut := function(K, target)
    local desc;

    if Size(K) < 2^target then
        return true;
    fi;

    desc := StructureDescription(K);

    if target > 6 and Size(K) = 443520 and desc = "M22" then
        Print("    shortcut: certified i(M22)=6 excludes weak-GP",
              target, ".\n");
        return true;
    fi;

    if target > 5 and Size(K) = 7920 and desc = "M11" then
        Print("    shortcut: certified i(M11)=5 excludes weak-GP",
              target, ".\n");
        return true;
    fi;

    if target > 6 and desc = "PSL(3,4)" then
        Print("    shortcut: previous M24 class-6 computation excludes ",
              "weak-GP", target, " in all subgroups of PSL(3,4).\n");
        return true;
    fi;

    if target > 6 and Size(K) = 3265920 and desc = "PSU(4,3)" then
        Print("    shortcut: certified U4(3) member-filter/class-1 ",
              "computation excludes weak-GP", target, ".\n");
        return true;
    fi;

    return false;
end;

G := AtlasGroup(TargetGroupName);
if G = fail then
    Error("AtlasGroup failed for ", TargetGroupName);
fi;
if not IsPermGroup(G) then
    G := Image(IsomorphismPermGroup(G));
fi;

Print("Built ", TargetGroupName, ", order = ", Size(G),
      ", degree = ", LargestMovedPoint(G), "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("Target proper-subgroup weak-GP exclusion length = ",
      TargetProperUpper, "\n");
Print("Subgroup index range = [", SubgroupStart, ", ", SubgroupStop, "]\n");
Print("UseKnownSubgroupShortcuts = ", UseKnownSubgroupShortcuts, "\n");
if CheckStrongFlatTarget <> fail then
    Print("Strong-flat probe exclusion length = ",
          CheckStrongFlatTarget, "\n");
fi;

maxReps := MaximalSubgroupClassReps(G);
if not IsBound(SelectedTopClasses) then
    SelectedTopClasses := [1..Length(maxReps)];
fi;

Print("Maximal subgroup classes = ", Length(maxReps), "\n");
for i in [1..Length(maxReps)] do
    Print(i, ": size=", Size(maxReps[i]),
          " index=", Size(G)/Size(maxReps[i]),
          " struct=", StructureDescription(maxReps[i]), "\n");
od;
Print("Selected top maximal classes = ", SelectedTopClasses, "\n");

seen := [];
checked := 0;
strongWitnesses := [];

for classIndex in SelectedTopClasses do
    M := maxReps[classIndex];
    Print("Checking top maximal class ", classIndex,
          ": size=", Size(M), " struct=", StructureDescription(M), "\n");

    if UseKnownSubgroupShortcuts and KnownNoWeakGPShortcut(M, TargetProperUpper) then
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
            sig := SubgroupSignatureForDedup(K);
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

        if UseKnownSubgroupShortcuts and KnownNoWeakGPShortcut(K, TargetProperUpper) then
            result := fail;
        else
            result := WeakGPFamilyBySignatures(K, TargetProperUpper);
        fi;
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
            result := WeakGPFamilyBySignatures(K, CheckStrongFlatTarget);
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
    od;
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

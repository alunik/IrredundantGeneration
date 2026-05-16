if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

SkipM22IVerifier := true;
Read(Concatenation(WorkspaceRoot, "/gap/10_verify_i_m22.g"));

if not IsBound(TargetProperUpper) then
    TargetProperUpper := 8;
fi;

if not IsBound(SelectedTopClasses) then
    SelectedTopClasses := [2..9];
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

if not IsBound(AssumeM23IUpperFromPreviousRun) then
    AssumeM23IUpperFromPreviousRun := true;
fi;

if not IsBound(UseKnownSubgroupShortcuts) then
    UseKnownSubgroupShortcuts := false;
fi;

CheckM24MaximalClassForNoWeakGP := function(M, classIndex, target)
    local subReps, checked, localIndex, K, D, result, started, stopped, t,
          elapsed;

    Print("Checking M24 maximal class ", classIndex,
          ": size=", Size(M), " struct=", StructureDescription(M),
          " target_no_weakGP=", target, "\n");

    t := Runtime();
    subReps := List(ConjugacyClassesSubgroups(M), Representative);
    Print("  subgroup class representatives = ", Length(subReps),
          " enumeration_ms=", Runtime() - t, "\n");

    checked := 0;
    started := Maximum(1, SubgroupStart);
    stopped := Minimum(Length(subReps), SubgroupStop);

    if started > stopped then
        Print("  empty requested subgroup-index range [", SubgroupStart,
              ", ", SubgroupStop, "] for class ", classIndex, "\n");
        return true;
    fi;

    for localIndex in [started..stopped] do
        K := subReps[localIndex];
        checked := checked + 1;

        if checked = 1 or checked mod ProgressEverySubgroups = 0 then
            Print("  checking local_subgroup_index=", localIndex,
                  " checked_in_range=", checked,
                  " size=", Size(K),
                  " struct=", StructureDescription(K), "\n");
        fi;

        t := Runtime();
        if UseKnownSubgroupShortcuts and target >= 7 and Size(K) = 443520
           and StructureDescription(K) = "M22" then
            Print("    using previous deterministic M22 result: ",
                  "i(M22)=6, so no weak-GP", target,
                  " occurs in this subgroup.\n");
            result := fail;
        elif UseKnownSubgroupShortcuts and target >= 8 and Size(K) = 887040
             and StructureDescription(K) = "M22 : C2" then
            D := DerivedSubgroup(K);
            if Size(D) <> 443520 or not IsNormal(K, D)
               or Size(K) / Size(D) <> 2 then
                Error("M22:C2 shortcut failed its internal checks.");
            fi;
            Print("    using checked extension shortcut: K' has order ",
                  Size(D), " and index 2; with i(M22)=6 and i(C2)=1, ",
                  "the standard m-subadditivity argument gives i(K)<=7, ",
                  "so no weak-GP", target, " occurs here.\n");
            result := fail;
        else
            result := WeakGPFamilyBySignatures(K, target);
        fi;
        elapsed := Runtime() - t;

        if result <> fail then
            Print("FOUND weak-GP", target,
                  " below M24 maximal class ", classIndex,
                  " local_subgroup_index=", localIndex,
                  " subgroup_size=", Size(K),
                  " subgroup_struct=", StructureDescription(K), "\n");
            Print("  family=", result.family,
                  " classPattern=", result.classPattern,
                  " maximalCount=", result.maximalCount,
                  " signatureCount=", result.signatureCount, "\n");
            Error("i upper-bound obstruction failed.");
        fi;

        if elapsed > 1000 then
            Print("    completed local_subgroup_index=", localIndex,
                  " elapsed_ms=", elapsed, "\n");
        fi;
    od;

    Print("  completed M24 maximal class ", classIndex,
          " checked=", checked,
          " requested_range=[", started, ", ", stopped, "]",
          " no weak-GP", target, " found.\n");
    return true;
end;

G := MathieuGroup(24);
if Size(G) <> 244823040 then
    Error("Wrong group size for M24.");
fi;

Print("Built M24, order = ", Size(G), "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("Target proper-subgroup weak-GP exclusion length = ",
      TargetProperUpper, "\n");
Print("Selected top maximal classes = ", SelectedTopClasses, "\n");
Print("Subgroup index range = [", SubgroupStart, ", ", SubgroupStop, "]\n");

maxReps := MaximalSubgroupClassReps(G);
Print("M24 maximal subgroup classes = ", Length(maxReps), "\n");
for i in [1..Length(maxReps)] do
    Print(i, ": size=", Size(maxReps[i]),
          " index=", Size(G)/Size(maxReps[i]),
          " struct=", StructureDescription(maxReps[i]), "\n");
od;

if 1 in SelectedTopClasses then
    if AssumeM23IUpperFromPreviousRun then
        Print("Class 1 is M23. Using previous deterministic M23 result: ",
              "i(M23)=6, so no subgroup below class 1 has weak-GP",
              TargetProperUpper, " for TargetProperUpper >= 7.\n");
    else
        Error("Class 1 requested without the previous M23 assumption. ",
              "Run gap/12_verify_m23_upper_i.g separately.");
    fi;
fi;

for classIndex in SelectedTopClasses do
    if classIndex = 1 then
        continue;
    fi;
    CheckM24MaximalClassForNoWeakGP(maxReps[classIndex], classIndex,
                                    TargetProperUpper);
od;

Print("SUCCESS: selected M24 maximal classes have no subgroup with weak-GP",
      TargetProperUpper, " in the checked ranges.\n");
Print("When run for all classes 2..9 with TargetProperUpper=8, this proves ",
      "every proper subgroup of M24 has i <= 7, using the previous M23 ",
      "verification for class 1.\n");
Print("When run for non-exceptional classes 4,6,7,8,9 with ",
      "TargetProperUpper=7, this excludes those classes from a hypothetical ",
      "weak-GP8 family of maximal subgroups of M24.\n");

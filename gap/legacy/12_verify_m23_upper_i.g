if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

SkipM22IVerifier := true;
Read(Concatenation(WorkspaceRoot, "/gap/10_verify_i_m22.g"));

if not IsBound(MaxDimSearchNodeLimit) then
    MaxDimSearchNodeLimit := 1000000;
fi;

if not IsBound(TargetProperUpper) then
    TargetProperUpper := 7;
fi;

IsWeakGPPointSetM23 := function(G, S)
    local all, p, H;

    all := Stabilizer(G, S, OnTuples);
    for p in S do
        H := Stabilizer(G, Filtered(S, x -> x <> p), OnTuples);
        if Size(H) = Size(all) then
            return false;
        fi;
    od;
    return true;
end;

CheckNoSevenM22PointStabilizers := function(G)
    local subsets, orbits, orb, S;

    subsets := Combinations([1..23], 7);
    orbits := Orbits(G, subsets, OnSets);
    Print("M23 orbits on 7-point subsets = ", Length(orbits),
          " sizes=", List(orbits, Length), "\n");

    for orb in orbits do
        S := orb[1];
        Print("  7-set orbit representative ", S,
              " full_stabilizer_size=", Size(Stabilizer(G, S, OnTuples)),
              " omit_sizes=",
              List(S, p -> Size(Stabilizer(G, Filtered(S, x -> x <> p),
                                            OnTuples))),
              " weakGP=", IsWeakGPPointSetM23(G, S), "\n");
        if IsWeakGPPointSetM23(G, S) then
            Error("Found weak-GP7 among M22 point stabilizers.");
        fi;
    od;

    Print("No seven M22 point stabilizers are in weak general position.\n");
end;

CheckMaximalSubgroupClassIAtMostSix := function(M, classIndex)
    local subReps, checked, K, result;

    Print("Checking non-M22 maximal class ", classIndex,
          ": size=", Size(M), " struct=", StructureDescription(M), "\n");
    subReps := List(ConjugacyClassesSubgroups(M), Representative);
    Print("  subgroup class representatives = ", Length(subReps), "\n");

    checked := 0;
    for K in subReps do
        checked := checked + 1;
        if checked mod 25 = 0 then
            Print("  checked ", checked, " subgroup classes\n");
        fi;

        result := WeakGPFamilyBySignatures(K, TargetProperUpper);
        if result <> fail then
            Print("FOUND weak-GP", TargetProperUpper,
                  " in subgroup size=", Size(K),
                  " struct=", StructureDescription(K),
                  " family=", result.family,
                  " classPattern=", result.classPattern, "\n");
            Error("i bound failed for M23 maximal class ", classIndex);
        fi;
    od;

    Print("  no subgroup below class ", classIndex,
          " has weak-GP", TargetProperUpper,
          "; hence this maximal has i <= ", TargetProperUpper - 1, ".\n");
end;

G := MathieuGroup(23);
if Size(G) <> 10200960 then
    Error("Wrong group size for M23.");
fi;

Print("Built M23, order = ", Size(G), "\n");
Print("GAP version = ", GAPInfo.Version, "\n");

maxReps := MaximalSubgroupClassReps(G);
Print("Maximal subgroup classes = ", Length(maxReps), "\n");
for i in [1..Length(maxReps)] do
    Print(i, ": size=", Size(maxReps[i]),
          " index=", Size(G)/Size(maxReps[i]),
          " struct=", StructureDescription(maxReps[i]), "\n");
od;

CheckNoSevenM22PointStabilizers(G);

for i in [2..Length(maxReps)] do
    CheckMaximalSubgroupClassIAtMostSix(maxReps[i], i);
od;

Print("SUCCESS: no seven M22 point stabilizers are in weak general position.\n");
Print("SUCCESS: non-M22 maximal subgroups have i <= ",
      TargetProperUpper - 1, ".\n");
Print("Combined with the M22 computation, every proper subgroup of M23 has ",
      "i <= ", TargetProperUpper - 1, ".\n");

if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;
Read(Concatenation(WorkspaceRoot, "/gap/00_common.g"));

if not IsBound(TargetUpper) then
    TargetUpper := 7;
fi;

if not IsBound(TargetLower) then
    TargetLower := 6;
fi;

if not IsBound(StopAfterLowerWitness) then
    StopAfterLowerWitness := true;
fi;

if not IsBound(DeduplicateByStructureString) then
    DeduplicateByStructureString := false;
fi;

if not IsBound(SignatureProgressEvery) then
    SignatureProgressEvery := infinity;
fi;

if not IsBound(MaxDimSearchNodeLimit) then
    MaxDimSearchNodeLimit := 1000000;
fi;

NodesVisited := 0;
NodesAtDepth := [];
BranchStats := [];

NonemptyBlist := function(b)
    return SizeBlist(b) > 0;
end;

OrbitRepresentativesInCandidates := function(stab, candidates)
    local candidateSet, orbits, reps, orb, hit;

    if Length(candidates) = 0 then
        return [];
    fi;

    candidateSet := Set(candidates);
    orbits := OrbitsDomain(stab, candidateSet);
    reps := [];

    for orb in orbits do
        hit := Intersection(Set(orb), candidateSet);
        if Length(hit) > 0 then
            Add(reps, Minimum(hit));
        fi;
    od;

    return reps;
end;

CanAddSignatureState := function(sigB, state, idx)
    local pos, filtered, newPrivate;

    for pos in [1..Length(state.family)] do
        filtered := IntersectionBlist(state.possible[pos], sigB[idx]);
        if not NonemptyBlist(filtered) then
            return false;
        fi;
    od;

    newPrivate := DifferenceBlist(state.allSelected, sigB[idx]);
    return NonemptyBlist(newPrivate);
end;

AddSignatureState := function(sigB, state, idx)
    local pos, newPossible;

    newPossible := [];
    for pos in [1..Length(state.family)] do
        Add(newPossible, IntersectionBlist(state.possible[pos], sigB[idx]));
    od;
    Add(newPossible, DifferenceBlist(state.allSelected, sigB[idx]));

    return rec(
        family := Concatenation(state.family, [idx]),
        possible := newPossible,
        allSelected := IntersectionBlist(state.allSelected, sigB[idx])
    );
end;

CandidateListSignatureState := function(sigB, classOf, state, minClass)
    local out, idx, last;

    out := [];
    last := state.family[Length(state.family)];
    for idx in [last + 1..Length(sigB)] do
        if classOf[idx] < minClass then
            continue;
        fi;
        if CanAddSignatureState(sigB, state, idx) then
            Add(out, idx);
        fi;
    od;
    return out;
end;

SortRepsBySignaturePressure := function(sigB, state, reps)
    local scored, idx, score, pos, filtered, newPrivate;

    scored := [];
    for idx in reps do
        score := 0;
        for pos in [1..Length(state.family)] do
            filtered := IntersectionBlist(state.possible[pos], sigB[idx]);
            score := score + SizeBlist(filtered);
        od;
        newPrivate := DifferenceBlist(state.allSelected, sigB[idx]);
        score := score + SizeBlist(newPrivate);
        Add(scored, [score, idx]);
    od;
    Sort(scored);
    return List(scored, x -> x[2]);
end;

SearchSignatureRecursive := function(sigB, classOf, state, stab, minClass, target)
    local depth, candidates, reps, idx, newState, newStab, result;

    depth := Length(state.family);
    NodesVisited := NodesVisited + 1;
    NodesAtDepth[depth] := NodesAtDepth[depth] + 1;

    if SignatureProgressEvery <> infinity
       and NodesVisited mod SignatureProgressEvery = 0 then
        Print("    signature-progress nodes=", NodesVisited,
              " depth=", depth,
              " family=", state.family, "\n");
    fi;

    if NodesVisited > MaxDimSearchNodeLimit then
        Error("Node limit exceeded in subgroup search.");
    fi;

    if depth = target then
        return state;
    fi;

    candidates := CandidateListSignatureState(sigB, classOf, state, minClass);
    if Length(candidates) = 0 then
        return fail;
    fi;

    reps := OrbitRepresentativesInCandidates(stab, candidates);
    reps := SortRepsBySignaturePressure(sigB, state, reps);
    BranchStats[depth+1] := BranchStats[depth+1] + Length(reps);

    for idx in reps do
        newState := AddSignatureState(sigB, state, idx);
        newStab := Stabilizer(stab, idx);
        result := SearchSignatureRecursive(sigB, classOf, newState, newStab,
                                           minClass, target);
        if result <> fail then
            return result;
        fi;
    od;

    return fail;
end;

WeakGPFamilyBySignatures := function(K, target)
    local maxReps, allMax, classOf, firstOfClass, elts, signaturesByElement,
          idx, c, classList, H, x, eligiblePositions, signatures, sigUniverse,
          sigContains, sidx, sigB, allSigB, permAction, firstClass, first,
          initialState, initialStab, result, p, d;

    # A weak-GP family of target maximal subgroups yields target irredundant
    # elements, so successive generated subgroups have index at least 2.
    if Size(K) < 2^target then
        return fail;
    fi;

    # In a p-group all maximal subgroups contain the Frattini subgroup, so
    # weak-GP families of maximal subgroups are bounded by d(P).
    if IsPGroup(K) then
        p := PrimePGroup(K);
        d := LogInt(Size(K) / Size(FrattiniSubgroup(K)), p);
        if d < target then
            return fail;
        fi;
    fi;

    if Size(K) = 1 then
        return fail;
    fi;

    maxReps := MaximalSubgroupClassReps(K);

    elts := Elements(K);
    allMax := [];
    classOf := [];
    firstOfClass := [];
    signaturesByElement := List([1..Length(elts)], i -> []);

    idx := 0;
    for c in [1..Length(maxReps)] do
        classList := AsList(ConjugacyClassSubgroups(K, maxReps[c]));
        for H in classList do
            idx := idx + 1;
            Add(allMax, H);
            Add(classOf, c);
            if not IsBound(firstOfClass[c]) then
                firstOfClass[c] := idx;
            fi;
            for x in Elements(H) do
                Add(signaturesByElement[PositionSorted(elts, x)], idx);
            od;
        od;
    od;

    if Length(allMax) < target then
        return fail;
    fi;

    eligiblePositions := Filtered([1..Length(elts)],
        i -> Order(elts[i]) <> 1 and Length(signaturesByElement[i]) >= target - 1);
    if Length(eligiblePositions) = 0 then
        return fail;
    fi;

    signatures := Set(List(eligiblePositions, i -> signaturesByElement[i]));
    sigUniverse := [1..Length(signatures)];
    sigContains := List([1..Length(allMax)], i -> []);

    for sidx in sigUniverse do
        for idx in signatures[sidx] do
            Add(sigContains[idx], sidx);
        od;
    od;

    sigB := List(sigContains, inds -> BlistList(sigUniverse, inds));
    allSigB := BlistList(sigUniverse, sigUniverse);
    permAction := Action(K, allMax, function(M, g) return M^g; end);

    for firstClass in [1..Length(firstOfClass)] do
        first := firstOfClass[firstClass];
        NodesVisited := 0;
        NodesAtDepth := List([1..target], i -> 0);
        BranchStats := List([1..target], i -> 0);

        initialState := rec(
            family := [first],
            possible := [DifferenceBlist(allSigB, sigB[first])],
            allSelected := sigB[first]
        );
        initialStab := Stabilizer(permAction, [first], OnSets);

        result := SearchSignatureRecursive(sigB, classOf, initialState,
                                           initialStab, firstClass, target);
        if result <> fail then
            return rec(
                family := result.family,
                classPattern := List(result.family, i -> classOf[i]),
                maximalCount := Length(allMax),
                maxClassCount := Length(maxReps),
                eligibleElementCount := Length(eligiblePositions),
                signatureCount := Length(signatures)
            );
        fi;
    od;

    return fail;
end;

SubgroupSignature := function(K)
    return Concatenation(String(Size(K)), ":", StructureDescription(K));
end;

if not IsBound(SkipM22IVerifier) then
    SkipM22IVerifier := false;
fi;

if not SkipM22IVerifier then

G := BuildM22();
Print("Built M22, order = ", Size(G), "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("Checking proper subgroups under the eight maximal subgroup classes.\n");

maxRepsG := MaximalSubgroupClassReps(G);
seen := [];
upperChecked := 0;
lowerWitnesses := [];

for m in [1..Length(maxRepsG)] do
    M := maxRepsG[m];
    Print("Top maximal class ", m, ": size=", Size(M),
          " struct=", StructureDescription(M), "\n");
    subReps := List(ConjugacyClassesSubgroups(M), Representative);
    Print("  subgroup class reps in this maximal = ", Length(subReps), "\n");

    for K in subReps do
        sig := SubgroupSignature(K);
        if DeduplicateByStructureString and sig in seen then
            continue;
        fi;
        Add(seen, sig);

        upperChecked := upperChecked + 1;
        if upperChecked mod 25 = 0 then
            Print("  checked ", upperChecked,
                  " subgroup-class representatives so far\n");
        fi;

        result := WeakGPFamilyBySignatures(K, TargetUpper);
        if result <> fail then
            Print("FOUND weak-GP", TargetUpper, " in subgroup size=",
                  Size(K), " struct=", StructureDescription(K), "\n");
            Print("  family=", result.family,
                  " classPattern=", result.classPattern, "\n");
            Error("Upper bound i(M22) <= ", TargetUpper - 1, " failed.");
        fi;

        if Length(lowerWitnesses) = 0 or not StopAfterLowerWitness then
            result := WeakGPFamilyBySignatures(K, TargetLower);
            if result <> fail then
                Add(lowerWitnesses, rec(
                    topMaxClass := m,
                    size := Size(K),
                    structure := StructureDescription(K),
                    family := result.family,
                    classPattern := result.classPattern,
                    maximalCount := result.maximalCount,
                    signatureCount := result.signatureCount
                ));
                Print("  found proper weak-GP", TargetLower,
                      " witness in size=", Size(K),
                      " struct=", StructureDescription(K),
                      " classPattern=", result.classPattern, "\n");
            fi;
        fi;
    od;
od;

if DeduplicateByStructureString then
    Print("Distinct size/structure subgroup signatures checked = ",
          upperChecked, "\n");
else
    Print("Subgroup-class representatives checked, with repetitions across ",
          "top maximals = ", upperChecked, "\n");
fi;
Print("No subgroup below a maximal subgroup of M22 has weak-GP",
      TargetUpper, ".\n");

if Length(lowerWitnesses) > 0 then
    Print("Proper subgroup weak-GP", TargetLower, " witness found:\n");
    Print(lowerWitnesses[1], "\n");
    Print("Therefore a proper subgroup has i >= ", TargetLower,
          "; M22 is flat but not strongly flat once i(M22) = ", TargetLower,
          " is established.\n");
else
    Print("No proper subgroup weak-GP", TargetLower,
          " witness found by this run.\n");
    Print("Therefore every proper subgroup of M22 has i <= ",
          TargetLower - 1, ".\n");
fi;

Print("SUCCESS: i(M22) <= ", TargetUpper - 1,
      " by recursive MaxDim obstruction for proper subgroups.\n");
if Length(lowerWitnesses) = 0 and TargetLower = TargetUpper - 1 then
    Print("SUCCESS: M22 is strongly flat once m(M22) = ",
          TargetLower, " is combined with this proper-subgroup bound.\n");
fi;

fi;

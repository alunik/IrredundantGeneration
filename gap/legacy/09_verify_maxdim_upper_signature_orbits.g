if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;
Read(Concatenation(WorkspaceRoot, "/gap/00_common.g"));

if not IsBound(TargetLength) then
    TargetLength := 7;
fi;

if not IsBound(NodeLimit) then
    NodeLimit := infinity;
fi;

if not IsBound(ProgressEvery) then
    ProgressEvery := 10000;
fi;

NodesVisited := 0;
NodesAtDepth := [];
BranchStats := [];

NonemptyBlist := function(b)
    return SizeBlist(b) > 0;
end;

DifferenceNonempty := function(a, b)
    return not IsSubsetBlist(b, a);
end;

CanAddSignatureState := function(sigB, state, idx)
    local pos, filtered, newPrivate;

    for pos in [1..Length(state.family)] do
        filtered := IntersectionBlist(state.possible[pos], sigB[idx]);
        if not NonemptyBlist(filtered) then
            return false;
        fi;
    od;

    # Private witnesses for the new subgroup are signatures containing all
    # old selected maximal subgroups but not the new one.
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

    if NodesVisited mod ProgressEvery = 0 then
        Print("progress nodes=", NodesVisited,
              " depth=", depth,
              " classes=", List(state.family, i -> classOf[i]),
              " possible_sizes=", List(state.possible, SizeBlist), "\n");
    fi;

    if NodesVisited > NodeLimit then
        Error("Node limit exceeded.");
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

G := BuildM22();
Print("Built M22, order = ", Size(G), "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("Target weak-GP length = ", TargetLength, "\n");

Print("Enumerating elements...\n");
elts := Elements(G);
Print("Element count = ", Length(elts), "\n");

maxReps := MaximalSubgroupClassReps(G);
allMax := [];
classOf := [];
firstOfClass := [];
signaturesByElement := List([1..Length(elts)], i -> []);

Print("Building maximal subgroup conjugates and element overgroup signatures...\n");
idx := 0;
for c in [1..Length(maxReps)] do
    classList := AsList(ConjugacyClassSubgroups(G, maxReps[c]));
    Print("Max class ", c, ": ", Length(classList), " conjugates, size ",
          Size(maxReps[c]), ", ", StructureDescription(maxReps[c]), "\n");
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

Print("Total maximal subgroups = ", Length(allMax), "\n");

eligiblePositions := Filtered([1..Length(elts)],
    i -> Order(elts[i]) <> 1 and Length(signaturesByElement[i]) >= TargetLength - 1);
signatures := Set(List(eligiblePositions, i -> signaturesByElement[i]));
Print("Eligible private-witness elements = ", Length(eligiblePositions), "\n");
Print("Distinct overgroup signatures = ", Length(signatures), "\n");

sigUniverse := [1..Length(signatures)];
sigContains := List([1..Length(allMax)], i -> []);
for sidx in sigUniverse do
    for idx in signatures[sidx] do
        Add(sigContains[idx], sidx);
    od;
od;

sigB := List(sigContains, inds -> BlistList(sigUniverse, inds));
allSigB := BlistList(sigUniverse, sigUniverse);

Print("Building conjugation action on maximal subgroups...\n");
t := Runtime();
permAction := Action(G, allMax, function(H, g) return H^g; end);
Print("Action degree = ", LargestMovedPoint(permAction),
      " size = ", Size(permAction),
      " build_ms = ", Runtime() - t, "\n");

for firstClass in [1..Length(firstOfClass)] do
    first := firstOfClass[firstClass];
    Print("Branch minimum_class=", firstClass, " first_index=", first, "\n");

    NodesVisited := 0;
    NodesAtDepth := List([1..TargetLength], i -> 0);
    BranchStats := List([1..TargetLength], i -> 0);

    initialState := rec(
        family := [first],
        possible := [DifferenceBlist(allSigB, sigB[first])],
        allSelected := sigB[first]
    );
    initialStab := Stabilizer(permAction, [first], OnSets);

    result := SearchSignatureRecursive(sigB, classOf, initialState,
                                       initialStab, firstClass,
                                       TargetLength);

    Print("Completed branch minimum_class=", firstClass,
          " nodes=", NodesVisited,
          " nodes_by_depth=", NodesAtDepth,
          " orbit_reps_by_next_depth=", BranchStats, "\n");

    if result <> fail then
        Print("FOUND weak-GP", TargetLength, " family: ", result.family, "\n");
        Print("Class pattern: ", List(result.family, i -> classOf[i]), "\n");
        Error("Counterexample family found.");
    fi;
od;

Print("SUCCESS: no weak-GP", TargetLength,
      " family of maximal subgroups exists in M22.\n");

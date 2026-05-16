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
    ProgressEvery := 1000;
fi;

if not IsBound(CandidateSupportThreshold) then
    CandidateSupportThreshold := 20000;
fi;

if not IsBound(VerboseDepth) then
    VerboseDepth := false;
fi;

NodesVisited := 0;
NodesAtDepth := [];
BranchStats := [];

NonemptyBlist := function(b)
    return SizeBlist(b) > 0;
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

SignatureSupportSet := function(signatures, sigUniverse, possible)
    local sigIdxs, support, sidx;

    if SizeBlist(possible) > CandidateSupportThreshold then
        return fail;
    fi;

    sigIdxs := ListBlist(sigUniverse, possible);
    support := [];
    for sidx in sigIdxs do
        Append(support, signatures[sidx]);
    od;
    return Set(support);
end;

CandidateListSignatureState := function(sigB, classOf, signatures, sigUniverse,
                                        state, minClass)
    local out, idx, last, supportSets, pos, support, candidateSet, i,
          rawCandidates;

    out := [];
    last := state.family[Length(state.family)];

    supportSets := [];
    for pos in [1..Length(state.possible)] do
        support := SignatureSupportSet(signatures, sigUniverse,
                                       state.possible[pos]);
        if support <> fail then
            Add(supportSets, support);
        fi;
    od;

    if Length(supportSets) = 0 then
        rawCandidates := [last + 1..Length(sigB)];
    else
        candidateSet := supportSets[1];
        for i in [2..Length(supportSets)] do
            candidateSet := Intersection(candidateSet, supportSets[i]);
        od;
        rawCandidates := Filtered(candidateSet, idx -> idx > last);
    fi;

    for idx in rawCandidates do
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

SearchSignatureRecursive := function(sigB, classOf, signatures, sigUniverse,
                                     state, stab, minClass, target)
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

    candidates := CandidateListSignatureState(sigB, classOf, signatures,
                                              sigUniverse, state, minClass);
    if VerboseDepth then
        Print("depth=", depth, " family=", state.family,
              " classes=", List(state.family, i -> classOf[i]),
              " candidates=", Length(candidates), "\n");
    fi;
    if Length(candidates) = 0 then
        return fail;
    fi;

    reps := OrbitRepresentativesInCandidates(stab, candidates);
    reps := SortRepsBySignaturePressure(sigB, state, reps);
    BranchStats[depth+1] := BranchStats[depth+1] + Length(reps);
    if VerboseDepth then
        Print("depth=", depth, " orbit_reps=", Length(reps), "\n");
    fi;

    for idx in reps do
        newState := AddSignatureState(sigB, state, idx);
        newStab := Stabilizer(stab, idx);
        result := SearchSignatureRecursive(sigB, classOf, signatures,
                                           sigUniverse, newState, newStab,
                                           minClass, target);
        if result <> fail then
            return result;
        fi;
    od;

    return fail;
end;

G := MathieuGroup(23);
if Size(G) <> 10200960 then
    Error("Wrong group size for M23.");
fi;
Print("Built M23, order = ", Size(G), "\n");
Print("GAP version = ", GAPInfo.Version, "\n");
Print("Target weak-GP length = ", TargetLength, "\n");

Print("Enumerating elements...\n");
t := Runtime();
elts := Elements(G);
Print("Element count = ", Length(elts),
      " runtime_ms=", Runtime() - t, "\n");

maxReps := MaximalSubgroupClassReps(G);
allMax := [];
classOf := [];
firstOfClass := [];
signaturesByElement := List([1..Length(elts)], i -> []);

Print("Building maximal subgroup conjugates and element overgroup signatures...\n");
idx := 0;
t := Runtime();
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
    Print("  cumulative maximals=", idx,
          " elapsed_ms=", Runtime() - t, "\n");
od;

Print("Total maximal subgroups = ", Length(allMax), "\n");

eligiblePositions := Filtered([1..Length(elts)],
    i -> Order(elts[i]) <> 1 and
         Length(signaturesByElement[i]) >= TargetLength - 1);
signatures := Set(List(eligiblePositions, i -> signaturesByElement[i]));
Print("Eligible private-witness elements = ", Length(eligiblePositions), "\n");
Print("Distinct overgroup signatures = ", Length(signatures), "\n");
Print("Eligible signature length histogram = ",
      Collected(List(eligiblePositions, i -> Length(signaturesByElement[i]))),
      "\n");

Unbind(signaturesByElement);
Unbind(eligiblePositions);
Unbind(elts);
GASMAN("collect");

sigUniverse := [1..Length(signatures)];
sigContains := List([1..Length(allMax)], i -> []);
Print("Building signature incidence blists...\n");
t := Runtime();
for sidx in sigUniverse do
    for idx in signatures[sidx] do
        Add(sigContains[idx], sidx);
    od;
    if sidx mod 100000 = 0 then
        Print("  signature ", sidx, "/", Length(signatures),
              " elapsed_ms=", Runtime() - t, "\n");
    fi;
od;

sigB := List(sigContains, inds -> BlistList(sigUniverse, inds));
allSigB := BlistList(sigUniverse, sigUniverse);
Unbind(sigContains);
GASMAN("collect");

Print("Building conjugation action on maximal subgroups...\n");
t := Runtime();
permAction := Action(G, allMax, function(H, g) return H^g; end);
Print("Action degree = ", LargestMovedPoint(permAction),
      " size = ", Size(permAction),
      " build_ms = ", Runtime() - t, "\n");

if not IsBound(FirstClasses) then
    FirstClasses := [1..Length(firstOfClass)];
fi;

for firstClass in FirstClasses do
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

    result := SearchSignatureRecursive(sigB, classOf, signatures, sigUniverse,
                                       initialState,
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
      " family of maximal subgroups exists in M23 for branches ",
      FirstClasses, ".\n");

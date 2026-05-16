
SIG_FrameworkVersion := "2026-05-12-cleanup";

SIG_NonemptyBlist := function(b)
    return SizeBlist(b) > 0;
end;

SIG_OrbitRepresentativesInCandidates := function(stab, candidates)
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

SIG_CanAddState := function(sigB, state, idx)
    local pos, filtered, newPrivate;

    for pos in [1..Length(state.family)] do
        filtered := IntersectionBlist(state.possible[pos], sigB[idx]);
        if not SIG_NonemptyBlist(filtered) then
            return false;
        fi;
    od;

    newPrivate := DifferenceBlist(state.allSelected, sigB[idx]);
    return SIG_NonemptyBlist(newPrivate);
end;

SIG_AddState := function(sigB, state, idx)
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

SIG_CandidateList := function(sigB, classOf, state, minClass)
    local out, idx, last;

    out := [];
    last := state.family[Length(state.family)];
    for idx in [last + 1..Length(sigB)] do
        if classOf[idx] < minClass then
            continue;
        fi;
        if SIG_CanAddState(sigB, state, idx) then
            Add(out, idx);
        fi;
    od;
    return out;
end;

SIG_SortByPressure := function(sigB, state, reps)
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

SIG_SearchRecursive := function(sigB, classOf, state, stab, minClass, target,
                                opts, stats)
    local depth, candidates, reps, idx, newState, newStab, result;

    depth := Length(state.family);
    stats.nodes := stats.nodes + 1;
    stats.nodesByDepth[depth] := stats.nodesByDepth[depth] + 1;

    if opts.progress_every <> infinity
       and stats.nodes mod opts.progress_every = 0 then
        Print("    signature-progress nodes=", stats.nodes,
              " depth=", depth,
              " family=", state.family, "\n");
    fi;

    if stats.nodes > opts.node_limit then
        Error("Node limit exceeded in signature weak-GP search.");
    fi;

    if depth = target then
        return state;
    fi;

    candidates := SIG_CandidateList(sigB, classOf, state, minClass);
    if Length(candidates) = 0 then
        return fail;
    fi;

    reps := SIG_OrbitRepresentativesInCandidates(stab, candidates);
    reps := SIG_SortByPressure(sigB, state, reps);
    stats.branchStats[depth+1] := stats.branchStats[depth+1] + Length(reps);

    for idx in reps do
        newState := SIG_AddState(sigB, state, idx);
        newStab := Stabilizer(stab, idx);
        result := SIG_SearchRecursive(sigB, classOf, newState, newStab,
                                      minClass, target, opts, stats);
        if result <> fail then
            return result;
        fi;
    od;

    return fail;
end;

SIG_DefaultOptions := function()
    return rec(
        node_limit := 1000000,
        progress_every := infinity
    );
end;

SIG_NormalizeOptions := function(opts)
    local out;

    out := SIG_DefaultOptions();
    if IsRecord(opts) then
        if IsBound(opts.node_limit) then
            out.node_limit := opts.node_limit;
        fi;
        if IsBound(opts.progress_every) then
            out.progress_every := opts.progress_every;
        fi;
    fi;
    return out;
end;

SIG_WeakGPFamily := function(K, target, opts)
    local maxReps, allMax, classOf, firstOfClass, elts, signaturesByElement,
          idx, c, classList, H, x, eligiblePositions, signatures, sigUniverse,
          sigContains, sidx, sigB, allSigB, permAction, firstClass, first,
          initialState, initialStab, result, p, d, stats, pos;

    opts := SIG_NormalizeOptions(opts);

    if Size(K) < 2^target then
        return fail;
    fi;

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
                pos := Position(elts, x);
                if pos = fail then
                    Error("Element lookup failed in signature construction.");
                fi;
                Add(signaturesByElement[pos], idx);
            od;
        od;
    od;

    if Length(allMax) < target then
        return fail;
    fi;

    eligiblePositions := Filtered([1..Length(elts)],
        i -> Order(elts[i]) <> 1
             and Length(signaturesByElement[i]) >= target - 1);
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
        stats := rec(
            nodes := 0,
            nodesByDepth := List([1..target], i -> 0),
            branchStats := List([1..target], i -> 0)
        );
        initialState := rec(
            family := [first],
            possible := [DifferenceBlist(allSigB, sigB[first])],
            allSelected := sigB[first]
        );
        initialStab := Stabilizer(permAction, [first], OnSets);

        result := SIG_SearchRecursive(sigB, classOf, initialState, initialStab,
                                      firstClass, target, opts, stats);
        if result <> fail then
            return rec(
                family := result.family,
                classPattern := List(result.family, i -> classOf[i]),
                maximalCount := Length(allMax),
                maxClassCount := Length(maxReps),
                eligibleElementCount := Length(eligiblePositions),
                signatureCount := Length(signatures),
                stats := stats
            );
        fi;
    od;

    return fail;
end;

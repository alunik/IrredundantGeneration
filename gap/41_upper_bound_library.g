
if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;
Read(Concatenation(WorkspaceRoot, "/gap/40_signature_weakgp_library.g"));

UB_FrameworkVersion := "2026-05-12-known-i-shortcut";

UB_NoKnownIUpperBound := function(K)
    return fail;
end;

UB_DefaultOptions := function()
    return rec(
        node_limit := infinity,
        progress_every := 10000,
        use_orbit_first := true,
        use_fixed_support_cache := true,
        use_rank_monotone_order := true,
        use_moved_point_candidate_filter := true,
        use_omega_prune := true,
        use_dead_set_cache := true,
        dead_set_cache_min_depth := 3,
        witness_support_threshold := 5000,
        witness_pool_limit := 10000,
        first_ranks := fail,
        fixed_prefix := fail,
        fixed_prefixes := fail,
        list_next_reps_only := false,
        known_i_upper_bound := UB_NoKnownIUpperBound,
        member_filter_signature_opts := rec(node_limit := 1000000,
                                            progress_every := infinity)
    );
end;

UB_NormalizeOptions := function(opts)
    local out, name;

    out := UB_DefaultOptions();
    if IsRecord(opts) then
        for name in RecNames(opts) do
            out.(name) := opts.(name);
        od;
    fi;
    return out;
end;

UB_ValidateClassList := function(classList, label)
    if Length(Set(classList)) <> Length(classList) then
        Error(label, " contains duplicate maximal classes.");
    fi;
end;

UB_IsNotSubsetSubgroup := function(A, B)
    local gen;

    if Size(A) = 1 then
        return false;
    fi;
    if Size(A) > Size(B) then
        return true;
    fi;
    for gen in GeneratorsOfGroup(A) do
        if not gen in B then
            return true;
        fi;
    od;
    return false;
end;

UB_OmegaInt := function(n)
    return Length(FactorsInt(n));
end;

UB_CanStillHaveIrredundantLength := function(H, r, opts)
    if not opts.use_omega_prune then
        return true;
    fi;
    if r <= 0 then
        return true;
    fi;
    return UB_OmegaInt(Size(H)) >= r;
end;

UB_TryAddState := function(allMax, state, idx)
    local M, newExcept, pos, E, newFull;

    M := allMax[idx];
    if not UB_IsNotSubsetSubgroup(state.full, M) then
        return fail;
    fi;

    newExcept := [];
    for pos in [1..Length(state.family)] do
        E := Intersection(state.except[pos], M);
        if not UB_IsNotSubsetSubgroup(E, allMax[state.family[pos]]) then
            return fail;
        fi;
        Add(newExcept, E);
    od;

    newFull := Intersection(state.full, M);
    Add(newExcept, state.full);

    return rec(
        family := Concatenation(state.family, [idx]),
        except := newExcept,
        full := newFull
    );
end;

UB_OrbitRepresentativesInCandidates := function(stab, candidates)
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

UB_FixedSupportBlist := function(data, x)
    local pos, p, fixed, degree;

    if data.use_fixed_support_cache then
        pos := Position(data.fixedSupportCacheKeys, x);
        if pos <> fail then
            return data.fixedSupportCacheValues[pos];
        fi;
    fi;

    degree := Length(data.allMax);
    p := Image(data.actionHom, x);
    fixed := BlistList([1..degree], Filtered([1..degree], i -> i^p = i));
    if data.use_fixed_support_cache then
        Add(data.fixedSupportCacheKeys, x);
        Add(data.fixedSupportCacheValues, fixed);
    fi;
    return fixed;
end;

UB_PrivateWitnessSupportBlist := function(data, state, pos)
    local support, Mpos, witnessSet, pool, x;

    witnessSet := state.except[pos];
    if Size(witnessSet) > data.witness_support_threshold then
        return fail;
    fi;

    Mpos := data.allMax[state.family[pos]];
    pool := Filtered(Elements(witnessSet), x -> not x in Mpos);
    if Length(pool) = 0 or Length(pool) > data.witness_pool_limit then
        return fail;
    fi;

    support := BlistList([1..Length(data.allMax)], []);
    for x in pool do
        support := UnionBlist(support, UB_FixedSupportBlist(data, x));
    od;

    return support;
end;

UB_MovedPointBlist := function(stab, degree)
    local moved, gen;

    moved := BlistList([1..degree], []);
    for gen in GeneratorsOfGroup(stab) do
        moved := UnionBlist(moved, BlistList([1..degree], MovedPoints(gen)));
    od;
    return moved;
end;

UB_RerankSelectedClasses := function(classOf, activeClasses)
    local selectedRank, firstOfRank, i, r;

    selectedRank := List(classOf, c -> Position(activeClasses, c));
    firstOfRank := [];
    for i in [1..Length(selectedRank)] do
        if selectedRank[i] = fail then
            selectedRank[i] := 0;
        else
            r := selectedRank[i];
            if not IsBound(firstOfRank[r]) then
                firstOfRank[r] := i;
            fi;
        fi;
    od;

    for r in [1..Length(activeClasses)] do
        if not IsBound(firstOfRank[r]) then
            Error("Active maximal class ", activeClasses[r],
                  " is not present in the action data.");
        fi;
    od;

    return rec(selectedRank := selectedRank, firstOfRank := firstOfRank);
end;

UB_RestrictActionData := function(data, activeClasses)
    local ranks;

    UB_ValidateClassList(activeClasses, "activeClasses");
    ranks := UB_RerankSelectedClasses(data.classOf, activeClasses);
    return rec(
        G := data.G,
        maxReps := data.maxReps,
        selectedClasses := activeClasses,
        allMax := data.allMax,
        classOf := data.classOf,
        selectedRank := ranks.selectedRank,
        firstOfRank := ranks.firstOfRank,
        actionHom := data.actionHom,
        permAction := data.permAction,
        fixedSupportCacheKeys := [],
        fixedSupportCacheValues := [],
        witness_support_threshold := data.witness_support_threshold,
        witness_pool_limit := data.witness_pool_limit,
        use_fixed_support_cache := data.use_fixed_support_cache
    );
end;

UB_ValidateActionDataForOptions := function(data, opts)
    local c;

    if opts.use_moved_point_candidate_filter then
        for c in data.selectedClasses do
            if Normalizer(data.G, data.maxReps[c]) <> data.maxReps[c] then
                Error("Moved-point candidate filter requires self-normalizing ",
                      "maximal representatives; class ", c, " is not.");
            fi;
        od;
    fi;
end;

UB_RawCandidates := function(data, state, stab, minRank, opts)
    local supports, pos, support, candidateB, movedB, raw, out, idx, lastIdx;

    supports := [];
    for pos in [1..Length(state.family)] do
        support := UB_PrivateWitnessSupportBlist(data, state, pos);
        if support <> fail then
            Add(supports, support);
        fi;
    od;

    if Length(supports) = 0 then
        candidateB := BlistList([1..Length(data.allMax)],
                                [1..Length(data.allMax)]);
    else
        candidateB := supports[1];
        for pos in [2..Length(supports)] do
            candidateB := IntersectionBlist(candidateB, supports[pos]);
        od;
    fi;

    if opts.use_moved_point_candidate_filter then
        movedB := UB_MovedPointBlist(stab, Length(data.allMax));
        candidateB := IntersectionBlist(candidateB, movedB);
    fi;

    raw := ListBlist([1..Length(data.allMax)], candidateB);
    out := [];
    lastIdx := state.family[Length(state.family)];
    for idx in raw do
        if data.selectedRank[idx] < minRank or idx in state.family then
            continue;
        fi;
        if opts.use_rank_monotone_order
           and data.selectedRank[idx] < data.selectedRank[lastIdx] then
            continue;
        fi;
        Add(out, idx);
    od;
    return out;
end;

UB_SelectedSetKey := function(family)
    return Concatenation("k", JoinStringsWithSeparator(List(Set(family), String), "_"));
end;

UB_SearchRecursive := function(data, state, stab, minRank, target, opts, stats)
    local depth, candidates, reps, idx, newState, newStab, result, scored,
          row, cacheKey;

    depth := Length(state.family);
    stats.nodes := stats.nodes + 1;
    stats.nodesByDepth[depth] := stats.nodesByDepth[depth] + 1;

    if opts.progress_every <> infinity
       and stats.nodes mod opts.progress_every = 0 then
        Print("progress nodes=", stats.nodes,
              " depth=", depth,
              " classes=", List(state.family, i -> data.classOf[i]),
              " full_size=", Size(state.full), "\n");
    fi;

    if stats.nodes > opts.node_limit then
        Error("Node limit exceeded.");
    fi;
    if depth = target then
        return state;
    fi;
    if Size(state.full) = 1 then
        return fail;
    fi;
    if not UB_CanStillHaveIrredundantLength(state.full,
                                            target - depth, opts) then
        return fail;
    fi;

    cacheKey := fail;
    if opts.use_dead_set_cache and depth >= opts.dead_set_cache_min_depth then
        cacheKey := UB_SelectedSetKey(state.family);
        if IsBound(stats.deadSetCache.(cacheKey)) then
            return fail;
        fi;
    fi;

    candidates := UB_RawCandidates(data, state, stab, minRank, opts);
    if Length(candidates) = 0 then
        return fail;
    fi;

    scored := [];
    if opts.use_orbit_first then
        reps := UB_OrbitRepresentativesInCandidates(stab, candidates);
    else
        reps := candidates;
    fi;
    for idx in reps do
        newState := UB_TryAddState(data.allMax, state, idx);
        if newState <> fail then
            if not UB_CanStillHaveIrredundantLength(newState.full,
                                                    target - (depth + 1),
                                                    opts) then
                continue;
            fi;
            Add(scored, [UB_OmegaInt(Size(newState.full)),
                         Size(newState.full), idx, newState]);
        fi;
    od;

    Sort(scored);
    stats.branchStats[depth+1] := stats.branchStats[depth+1] + Length(scored);

    for row in scored do
        idx := row[3];
        newState := row[4];
        newStab := Stabilizer(stab, idx);
        result := UB_SearchRecursive(data, newState, newStab, minRank,
                                     target, opts, stats);
        if result <> fail then
            return result;
        fi;
    od;

    if cacheKey <> fail then
        stats.deadSetCache.(cacheKey) := true;
    fi;
    return fail;
end;

UB_BuildActionData := function(G, selectedClasses, opts)
    local maxReps, allMax, classOf, selectedRank, firstOfRank, r, c,
          classList, H, actionHom, permAction;

    opts := UB_NormalizeOptions(opts);
    maxReps := MaximalSubgroupClassReps(G);
    if selectedClasses = fail then
        selectedClasses := [1..Length(maxReps)];
    fi;
    UB_ValidateClassList(selectedClasses, "selectedClasses");

    allMax := [];
    classOf := [];
    selectedRank := [];
    firstOfRank := [];

    for r in [1..Length(selectedClasses)] do
        c := selectedClasses[r];
        classList := AsList(ConjugacyClassSubgroups(G, maxReps[c]));
        Print("Max class ", c, ": ", Length(classList), " conjugates, size ",
              Size(maxReps[c]), ", ", StructureDescription(maxReps[c]), "\n");
        if opts.use_moved_point_candidate_filter
           and Normalizer(G, maxReps[c]) <> maxReps[c] then
            Error("Moved-point candidate filter requires self-normalizing ",
                  "maximal representatives; class ", c, " is not.");
        fi;
        for H in classList do
            Add(allMax, H);
            Add(classOf, c);
            Add(selectedRank, r);
            if not IsBound(firstOfRank[r]) then
                firstOfRank[r] := Length(allMax);
            fi;
        od;
    od;

    Print("Building conjugation action on selected maximal subgroups...\n");
    actionHom := ActionHomomorphism(G, allMax, function(H, g) return H^g; end);
    permAction := Image(actionHom);

    return rec(
        G := G,
        maxReps := maxReps,
        selectedClasses := selectedClasses,
        allMax := allMax,
        classOf := classOf,
        selectedRank := selectedRank,
        firstOfRank := firstOfRank,
        actionHom := actionHom,
        permAction := permAction,
        fixedSupportCacheKeys := [],
        fixedSupportCacheValues := [],
        witness_support_threshold := opts.witness_support_threshold,
        witness_pool_limit := opts.witness_pool_limit,
        use_fixed_support_cache := opts.use_fixed_support_cache
    );
end;

UB_NoWeakGPBranch := function(data, firstRank, fixedPrefix, target, opts, stats)
    local first, initialState, initialStab, prefixPos, prefixIdx, newState,
          candidates, reps, addableReps, result, idx;

    if firstRank < 1 or not IsBound(data.firstOfRank[firstRank]) then
        Error("Invalid first rank ", firstRank, " for active action data.");
    fi;

    first := data.firstOfRank[firstRank];
    initialState := rec(
        family := [first],
        except := [data.G],
        full := data.allMax[first]
    );
    initialStab := Stabilizer(data.permAction, first);

    if fixedPrefix <> fail then
        if Length(Set(fixedPrefix)) <> Length(fixedPrefix) then
            Error("FixedPrefix contains duplicate subgroup indices.");
        fi;
        if Length(fixedPrefix) > target then
            Error("FixedPrefix is longer than the target weak-GP length.");
        fi;
        if fixedPrefix[1] <> first then
            Error("FixedPrefix must start with the selected first subgroup.");
        fi;
        for prefixPos in [2..Length(fixedPrefix)] do
            prefixIdx := fixedPrefix[prefixPos];
            if prefixIdx < 1 or prefixIdx > Length(data.allMax) then
                Error("FixedPrefix index out of range at position ",
                      prefixPos, ".");
            fi;
            if data.selectedRank[prefixIdx] = 0 then
                Error("FixedPrefix contains inactive subgroup index ",
                      prefixIdx, ".");
            fi;
            if opts.use_rank_monotone_order
               and data.selectedRank[prefixIdx]
                   < data.selectedRank[initialState.family[Length(initialState.family)]] then
                Error("FixedPrefix violates rank-monotone order.");
            fi;
            newState := UB_TryAddState(data.allMax, initialState, prefixIdx);
            if newState = fail then
                Error("FixedPrefix is not weak-addable.");
            fi;
            initialState := newState;
            initialStab := Stabilizer(initialStab, prefixIdx);
        od;
        Print("Using fixed prefix: ", initialState.family, " classes=",
              List(initialState.family, i -> data.classOf[i]), "\n");
    fi;

    if opts.list_next_reps_only then
        candidates := UB_RawCandidates(data, initialState, initialStab,
                                       firstRank, opts);
        if opts.use_orbit_first then
            reps := UB_OrbitRepresentativesInCandidates(initialStab, candidates);
        else
            reps := candidates;
        fi;
        addableReps := [];
        for idx in reps do
            newState := UB_TryAddState(data.allMax, initialState, idx);
            if newState <> fail and
               UB_CanStillHaveIrredundantLength(newState.full,
                   target - (Length(initialState.family) + 1), opts) then
                Add(addableReps, idx);
            fi;
        od;
        Print("Next orbit representatives for firstRank=", firstRank,
              ": ", addableReps, "\n");
        Print("Next classes: ", List(addableReps, i -> data.classOf[i]), "\n");
        return rec(status := "listed", reps := addableReps);
    fi;

    result := UB_SearchRecursive(data, initialState, initialStab, firstRank,
                                 target, opts, stats);
    if result <> fail then
        return rec(status := "found", family := result.family,
                   classPattern := List(result.family, i -> data.classOf[i]));
    fi;
    return rec(status := "success");
end;

UB_NoWeakGP := function(data, target, opts)
    local firstRanks, stats, branchResults, firstRank, fixedPrefixForRun,
          fixedPrefix, branchLabel, result;

    opts := UB_NormalizeOptions(opts);
    UB_ValidateActionDataForOptions(data, opts);
    if opts.first_ranks = fail then
        firstRanks := [1..Length(data.firstOfRank)];
    else
        firstRanks := opts.first_ranks;
    fi;

    stats := rec(
        nodes := 0,
        nodesByDepth := List([1..target], i -> 0),
        branchStats := List([1..target], i -> 0),
        deadSetCache := rec()
    );
    branchResults := [];

    if opts.fixed_prefixes <> fail then
        for branchLabel in [1..Length(opts.fixed_prefixes)] do
            fixedPrefix := opts.fixed_prefixes[branchLabel];
            if Length(fixedPrefix) = 0 then
                Error("FixedPrefixes contains an empty prefix.");
            fi;
            if data.selectedRank[fixedPrefix[1]] = 0 then
                Error("FixedPrefix starts in an inactive maximal class.");
            fi;
            result := UB_NoWeakGPBranch(data, data.selectedRank[fixedPrefix[1]],
                                        fixedPrefix, target, opts, stats);
            Add(branchResults, result);
            if result.status = "found" then
                return rec(status := "found", result := result, stats := stats);
            fi;
        od;
        if opts.list_next_reps_only then
            return rec(status := "listed", branches := branchResults,
                       stats := stats);
        fi;
        return rec(status := "partial_success", branches := branchResults,
                   stats := stats);
    elif opts.fixed_prefix <> fail then
        fixedPrefixForRun := opts.fixed_prefix;
        if Length(fixedPrefixForRun) = 0 then
            Error("FixedPrefix is empty.");
        fi;
        if data.selectedRank[fixedPrefixForRun[1]] = 0 then
            Error("FixedPrefix starts in an inactive maximal class.");
        fi;
        result := UB_NoWeakGPBranch(data, data.selectedRank[fixedPrefixForRun[1]],
                                    fixedPrefixForRun, target, opts, stats);
        Add(branchResults, result);
        if result.status = "found" then
            return rec(status := "found", result := result, stats := stats);
        fi;
        if opts.list_next_reps_only then
            return rec(status := "listed", branches := branchResults,
                       stats := stats);
        fi;
        return rec(status := "partial_success", branches := branchResults,
                   stats := stats);
    else
        for firstRank in firstRanks do
            Print("Branch minimum_selected_rank=", firstRank,
                  " class=", data.classOf[data.firstOfRank[firstRank]],
                  " first_index=", data.firstOfRank[firstRank], "\n");
            result := UB_NoWeakGPBranch(data, firstRank, fail,
                                        target, opts, stats);
            Add(branchResults, result);
            if result.status = "found" then
                return rec(status := "found", result := result, stats := stats);
            fi;
        od;
    fi;

    if opts.list_next_reps_only then
        return rec(status := "listed", branches := branchResults,
                   stats := stats);
    fi;
    if opts.first_ranks <> fail
       and Set(firstRanks) <> [1..Length(data.firstOfRank)] then
        return rec(status := "partial_success", branches := branchResults,
                   stats := stats);
    fi;
    return rec(status := "success", branches := branchResults, stats := stats);
end;

UB_MemberClassFilterClasses := function(G, ambientTarget, selectedTopClasses,
                                        opts)
    local maxReps, c, M, subReps, K, checked, survivors, excluded, found,
          result, knownIUpper, knownIUpperValue, knownIUpperProof,
          knownIUpperGroup;

    opts := UB_NormalizeOptions(opts);
    maxReps := MaximalSubgroupClassReps(G);
    if selectedTopClasses = fail then
        selectedTopClasses := [1..Length(maxReps)];
    fi;
    UB_ValidateClassList(selectedTopClasses, "selectedTopClasses");
    survivors := [];
    excluded := [];

    for c in selectedTopClasses do
        M := maxReps[c];
        Print("Top class ", c, ": size=", Size(M),
              " struct=", StructureDescription(M), "\n");

        knownIUpper := opts.known_i_upper_bound(M);
        knownIUpperValue := fail;
        knownIUpperProof := fail;
        knownIUpperGroup := fail;
        if knownIUpper <> fail then
            if IsRecord(knownIUpper) then
                knownIUpperValue := knownIUpper.i_upper;
                if IsBound(knownIUpper.proof) then
                    knownIUpperProof := knownIUpper.proof;
                fi;
                if IsBound(knownIUpper.group) then
                    knownIUpperGroup := knownIUpper.group;
                fi;
            else
                knownIUpperValue := knownIUpper;
            fi;
        fi;
        if knownIUpperValue <> fail
           and knownIUpperValue <= ambientTarget - 2 then
            Add(excluded, c);
            Print("  EXCLUDE class ", c,
                  ": known i-upper=", knownIUpperValue,
                  " rules out weak-GP", ambientTarget - 1,
                  " in every subgroup of this representative");
            if knownIUpperGroup <> fail then
                Print(" group=", knownIUpperGroup);
            fi;
            if knownIUpperProof <> fail then
                Print(" dependency=", knownIUpperProof);
            fi;
            Print(".\n");
            continue;
        fi;

        subReps := List(ConjugacyClassesSubgroups(M), Representative);
        Print("  subgroup class reps = ", Length(subReps), "\n");
        found := false;
        checked := 0;
        for K in subReps do
            checked := checked + 1;
            result := SIG_WeakGPFamily(K, ambientTarget - 1,
                                       opts.member_filter_signature_opts);
            if result <> fail then
                found := true;
                Print("  KEEP class ", c, ": subgroup index ", checked,
                      " size=", Size(K),
                      " struct=", StructureDescription(K),
                      " has weak-GP", ambientTarget - 1,
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
                  ambientTarget - 1, ".\n");
        fi;
    od;

    return rec(survivors := survivors, excluded := excluded);
end;

UB_MemberClassFilter := function(G, ambientTarget, opts)
    return UB_MemberClassFilterClasses(G, ambientTarget, fail, opts);
end;

UB_NoWeakGPWithMemberFilter := function(G, ambientTarget, opts)
    local filter, data, search;

    opts := UB_NormalizeOptions(opts);
    filter := UB_MemberClassFilter(G, ambientTarget, opts);
    if Length(filter.survivors) = 0 then
        return rec(status := "success",
                   filter := filter,
                   search := fail,
                   reason := "member filter excluded every maximal class");
    fi;

    data := UB_BuildActionData(G, filter.survivors, opts);
    search := UB_NoWeakGP(data, ambientTarget, opts);
    if search.status = "success" then
        return rec(status := "success",
                   filter := filter,
                   search := search,
                   reason := "member filter plus ambient search");
    fi;
    if search.status = "partial_success" or search.status = "listed" then
        return rec(status := search.status,
                   filter := filter,
                   search := search,
                   reason := "member filter plus restricted ambient search");
    fi;
    return rec(status := "found",
               filter := filter,
               search := search,
               reason := "ambient search found an obstruction");
end;

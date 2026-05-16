if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;
Read(Concatenation(WorkspaceRoot, "/gap/00_common.g"));

if not IsBound(TargetGroupName) then
    Error("Set TargetGroupName.");
fi;

if not IsBound(ActionWorkspacePath) then
    Error("Set ActionWorkspacePath.");
fi;

BuildTargetSporadicGroup := function(name)
    local G;

    if name = "HS" then
        G := PrimitiveGroup(100, 3);
        if Size(G) <> 44352000 then
            Error("PrimitiveGroup(100,3) did not build HS.");
        fi;
        return G;
    fi;

    G := AtlasGroup(name);
    if G = fail then
        Error("AtlasGroup failed for ", name);
    fi;
    return G;
end;

Print("Building reusable action workspace for ", TargetGroupName, "\n");
Print("GAP version = ", GAPInfo.Version, "\n");

G := BuildTargetSporadicGroup(TargetGroupName);
Print("Built ", TargetGroupName, ", order = ", Size(G));
if IsPermGroup(G) then
    Print(", degree = ", LargestMovedPoint(G));
fi;
Print("\n");

maxReps := MaximalSubgroupClassReps(G);
if not IsBound(SelectedClasses) then
    SelectedClasses := [1..Length(maxReps)];
fi;
Print("Selected maximal classes = ", SelectedClasses, "\n");

allMax := [];
classOf := [];
selectedRank := [];
firstOfRank := [];

for r in [1..Length(SelectedClasses)] do
    c := SelectedClasses[r];
    classList := AsList(ConjugacyClassSubgroups(G, maxReps[c]));
    Print("Max class ", c, ": ", Length(classList), " conjugates, size ",
          Size(maxReps[c]), ", ", StructureDescription(maxReps[c]), "\n");
    for H in classList do
        Add(allMax, H);
        Add(classOf, c);
        Add(selectedRank, r);
        if not IsBound(firstOfRank[r]) then
            firstOfRank[r] := Length(allMax);
        fi;
    od;
od;

Print("Total selected maximal subgroups = ", Length(allMax), "\n");
Print("Building conjugation action on selected maximal subgroups...\n");
t := Runtime();
actionHom := ActionHomomorphism(G, allMax, function(H, g) return H^g; end);
permAction := Image(actionHom);
Print("Action degree = ", LargestMovedPoint(permAction),
      " size = ", Size(permAction),
      " build_ms = ", Runtime() - t, "\n");

PrebuiltTargetGroupName := TargetGroupName;
PrebuiltSelectedClasses := ShallowCopy(SelectedClasses);

Print("Saving workspace to ", ActionWorkspacePath, "\n");
if not SaveWorkspace(ActionWorkspacePath) then
    Error("SaveWorkspace failed.");
fi;
Print("SUCCESS: saved reusable action workspace.\n");

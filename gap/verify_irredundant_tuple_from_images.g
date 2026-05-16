if not IsBound(TupleImages) then
    Error("Set TupleImages before reading this file.");
fi;

if not IsBound(GeneratorImages) then
    Error("Set GeneratorImages before reading this file.");
fi;

if not IsBound(ExpectedGroupOrder) then
    Error("Set ExpectedGroupOrder before reading this file.");
fi;

if not IsBound(ExpectedGeneratedOrder) then
    ExpectedGeneratedOrder := ExpectedGroupOrder;
fi;

if not IsBound(RequireGenerating) then
    RequireGenerating := true;
fi;

if not IsBound(TargetGroupName) then
    TargetGroupName := "finite group";
fi;

FrameworkSubtupleWithout := function(T, i)
    if Length(T) = 1 then
        return [];
    elif i = 1 then
        return T{[2..Length(T)]};
    elif i = Length(T) then
        return T{[1..Length(T)-1]};
    fi;
    return Concatenation(T{[1..i-1]}, T{[i+1..Length(T)]});
end;

G := Group(List(GeneratorImages, PermList));
if Size(G) <> ExpectedGroupOrder then
    Error("Wrong group order for ", TargetGroupName,
          ": expected ", ExpectedGroupOrder, ", got ", Size(G));
fi;

T := List(TupleImages, PermList);

Print("Built ", TargetGroupName, " from certificate generators, order = ",
      Size(G), "\n");
Print("Tuple length = ", Length(T), "\n");
Print("orders = ", List(T, Order), "\n");

for i in [1..Length(T)] do
    if not T[i] in G then
        Error("Tuple element not in G at position ", i);
    fi;
od;

H := Group(T);
Print("Generated order = ", Size(H), "\n");
Print("Expected generated order = ", ExpectedGeneratedOrder, "\n");
if Size(H) <> ExpectedGeneratedOrder then
    Error("Tuple generated order mismatch for ", TargetGroupName,
          ": expected ", ExpectedGeneratedOrder, ", got ", Size(H));
fi;

if RequireGenerating and Size(H) <> Size(G) then
    Error("Tuple does not generate ", TargetGroupName);
fi;

for i in [1..Length(T)] do
    U := Group(FrameworkSubtupleWithout(T, i));
    Print("Omitting ", i, ": generated order = ", Size(U),
          " structure = ", StructureDescription(U), "\n");
    if Size(U) = Size(H) then
        Error("Tuple is redundant at position ", i);
    fi;
od;

if RequireGenerating then
    Print("SUCCESS: irredundant generating tuple for ", TargetGroupName, ".\n");
else
    Print("SUCCESS: irredundant tuple for ", TargetGroupName, ".\n");
fi;

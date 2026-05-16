if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

CertPath := function(name)
    return Concatenation(WorkspaceRoot, "/certs/", name);
end;

LogPath := function(name)
    return Concatenation(WorkspaceRoot, "/logs/", name);
end;

ImageListOfPerm := function(p, degree)
    return List([1..degree], i -> i^p);
end;

PermImageListString := function(p, degree)
    return String(ImageListOfPerm(p, degree));
end;

M22WriteLine := function(stream, s)
    AppendTo(stream, s, "\n");
end;

SubtupleWithout := function(T, i)
    if i = 1 then
        return T{[2..Length(T)]};
    elif i = Length(T) then
        return T{[1..Length(T)-1]};
    fi;
    return Concatenation(T{[1..i-1]}, T{[i+1..Length(T)]});
end;

BuildM22 := function()
    local G;

    G := MathieuGroup(22);

    if Size(G) <> 443520 then
        Error("Wrong group size; expected M22 of order 443520.");
    fi;

    if not IsTransitive(G, [1..22]) then
        Error("Expected transitive degree-22 action.");
    fi;

    return G;
end;

VerifyIrredundantGeneratingTuple := function(G, T)
    local H, i, U, orders;

    Print("Tuple length = ", Length(T), "\n");
    orders := [];

    for i in [1..Length(T)] do
        if not T[i] in G then
            Error("Tuple element not in G at position ", i);
        fi;
        Add(orders, Order(T[i]));
        Print("g", i, " order = ", Order(T[i]), "\n");
        Print("g", i, " image list = ", ImageListOfPerm(T[i], 22), "\n");
    od;

    H := Group(T);
    Print("Full generated order = ", Size(H), "\n");

    if Size(H) <> Size(G) then
        Error("Tuple does not generate G.");
    fi;

    for i in [1..Length(T)] do
        U := Group(SubtupleWithout(T, i));
        Print("Omitting ", i, ": generated order = ", Size(U));
        Print(" structure = ", StructureDescription(U), "\n");

        if Size(U) = Size(G) then
            Error("Tuple is redundant at position ", i);
        fi;
    od;

    Print("SUCCESS: irredundant generating tuple.\n");
    return true;
end;

WriteTupleCertificate := function(G, T, filename, method)
    local out, gens, orders, omittedOrders, omittedStructures, i, U;

    gens := GeneratorsOfGroup(G);
    orders := List(T, Order);
    omittedOrders := [];
    omittedStructures := [];

    for i in [1..Length(T)] do
        U := Group(SubtupleWithout(T, i));
        Add(omittedOrders, Size(U));
        Add(omittedStructures, StructureDescription(U));
    od;

    out := OutputTextFile(filename, false);
    SetPrintFormattingStatus(out, false);
    AppendTo(out, "{\n");
    AppendTo(out, "  \"group\": {\n");
    AppendTo(out, "    \"name\": \"M22\",\n");
    AppendTo(out, "    \"degree\": 22,\n");
    AppendTo(out, "    \"order\": ", String(Size(G)), ",\n");
    AppendTo(out, "    \"generators\": [\n");
    for i in [1..Length(gens)] do
        AppendTo(out, "      ", String(ImageListOfPerm(gens[i], 22)));
        if i < Length(gens) then
            AppendTo(out, ",");
        fi;
        AppendTo(out, "\n");
    od;
    AppendTo(out, "    ]\n");
    AppendTo(out, "  },\n");
    AppendTo(out, "  \"tuple\": [\n");
    for i in [1..Length(T)] do
        AppendTo(out, "    ", String(ImageListOfPerm(T[i], 22)));
        if i < Length(T) then
            AppendTo(out, ",");
        fi;
        AppendTo(out, "\n");
    od;
    AppendTo(out, "  ],\n");
    AppendTo(out, "  \"orders\": ", String(orders), ",\n");
    AppendTo(out, "  \"full_generated_order\": ", String(Size(Group(T))), ",\n");
    AppendTo(out, "  \"omitted_generated_orders\": ", String(omittedOrders), ",\n");
    AppendTo(out, "  \"omitted_subgroup_structures\": ", String(omittedStructures), ",\n");
    AppendTo(out, "  \"source\": {\n");
    AppendTo(out, "    \"search_method\": \"", method, "\",\n");
    AppendTo(out, "    \"gap_version\": \"", GAPInfo.Version, "\"\n");
    AppendTo(out, "  }\n");
    AppendTo(out, "}\n");
    CloseStream(out);
end;

ReadTupleCertificate := function(filename)
    Error("Use gap/06_verify_tuple_from_images.g for certificate verification.");
end;

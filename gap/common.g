if not IsBound(WorkspaceRoot) then
    WorkspaceRoot := ".";
fi;

ImageListOfPerm := function(p, degree)
    return List([1..degree], i -> i^p);
end;

SubtupleWithout := function(T, i)
    if i = 1 then
        return T{[2..Length(T)]};
    elif i = Length(T) then
        return T{[1..Length(T)-1]};
    fi;
    return Concatenation(T{[1..i-1]}, T{[i+1..Length(T)]});
end;

ReadGapValueFile := function(path)
    local input, line, text, value;

    input := InputTextFile(path);
    if input = fail then
        Error("Could not open ", path);
    fi;

    text := "";
    line := ReadLine(input);
    while line <> fail do
        text := Concatenation(text, line);
        line := ReadLine(input);
    od;
    CloseStream(input);

    value := EvalString(text);
    if value = fail then
        Error("Could not parse GAP value from ", path);
    fi;
    return value;
end;

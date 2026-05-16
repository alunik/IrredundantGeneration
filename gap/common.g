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


SP_Bounds := rec(
    J1 := rec(m_lower := 4, m_upper := 4, i_lower := 4, i_upper := 4,
              m_no_weak_gp := 5),
    J2 := rec(m_lower := 5, m_upper := 5, i_lower := 5, i_upper := 5,
              m_no_weak_gp := 6),
    J3 := rec(m_lower := 4, m_upper := 4, i_lower := 5, i_upper := 5,
              m_no_weak_gp := 5,
              member_filter_survivors := [1, 2, 3, 4, 6, 7, 8, 9]),
    M22 := rec(m_lower := 6, m_upper := 6, i_lower := 6, i_upper := 6,
               m_no_weak_gp := 7),
    M23 := rec(m_lower := 6, m_upper := 6, i_lower := 6, i_upper := 6,
               m_no_weak_gp := 7),
    M24 := rec(m_lower := 7, m_upper := 7, i_lower := 7, i_upper := 7,
               m_no_weak_gp := 8,
               member_filter_survivors := [2, 3, 5, 7]),
    HS := rec(m_lower := 7, m_upper := 7, i_lower := 7, i_upper := 7,
              m_no_weak_gp := 8,
              member_filter_survivors := [5]),
    McL := rec(m_lower := 6, m_upper := 6, i_lower := 6, i_upper := 6,
               m_no_weak_gp := 7,
               member_filter_survivors := [1, 2, 3, 6, 7, 8, 9, 10])
);

SP_BuildGroup := function(name)
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
    if not IsPermGroup(G) then
        G := Image(IsomorphismPermGroup(G));
    fi;
    return G;
end;

SP_Record := function(name)
    if not IsBound(SP_Bounds.(name)) then
        Error("No sporadic-bound registry entry for ", name);
    fi;
    return SP_Bounds.(name);
end;

SP_MUpperTarget := function(name)
    return SP_Record(name).m_no_weak_gp;
end;

SP_RecordedMemberFilterSurvivors := function(name)
    local info;
    info := SP_Record(name);
    if IsBound(info.member_filter_survivors) then
        return info.member_filter_survivors;
    fi;
    return fail;
end;

SP_SelectedClassesForMUpper := function(name)
    return SP_RecordedMemberFilterSurvivors(name);
end;

SP_KnownIUpperBoundSubgroup := function(K)
    local n, desc;

    n := Size(K);
    desc := StructureDescription(K);

    # Values certified in this workspace or in the Brooks Mathieu computations.
    # The structure string is used only as a guard against an accidental order
    # collision; the surrounding computations still construct the subgroup in
    # GAP and verify all containment/intersection conditions directly.
    if n = 7920 and desc = "M11" then
        return rec(group := "M11", i_upper := 5, proof := "Brooks/GAP certificate");
    fi;
    if n = 95040 and desc = "M12" then
        return rec(group := "M12", i_upper := 6, proof := "Brooks");
    fi;
    if n = 443520 and desc = "M22" then
        return rec(group := "M22", i_upper := 6,
                   proof := "certs/m22_tuple6.json; logs/m22_no_gp7_signature_orbits.log; logs/m22_i_upper_strong_flat.log");
    fi;
    if n = 10200960 and desc = "M23" then
        return rec(group := "M23", i_upper := 6,
                   proof := "certs/m23_tuple6.json; logs/m23_no_gp7_signature_branch1.log; logs/m23_no_gp7_signature_branches2_7.log; logs/m23_proper_i_upper.log");
    fi;
    if n = 244823040 and desc = "M24" then
        return rec(group := "M24", i_upper := 7,
                   proof := "certs/m24_i_upper_manifest.json");
    fi;
    if n = 175560 and desc = "J1" then
        return rec(group := "J1", i_upper := 4, proof := "workspace certificate");
    fi;
    if n = 604800 and desc = "J2" then
        return rec(group := "J2", i_upper := 5, proof := "workspace certificate");
    fi;
    if n = 50232960 and desc = "J3" then
        return rec(group := "J3", i_upper := 5, proof := "workspace certificate");
    fi;
    if n = 44352000 and desc = "HS" then
        return rec(group := "HS", i_upper := 7, proof := "logs/hs_i_upper_manifest.md");
    fi;
    if n = 898128000 and desc = "McL" then
        return rec(group := "McL", i_upper := 6, proof := "logs/mcl_i_upper_manifest.md");
    fi;

    return fail;
end;

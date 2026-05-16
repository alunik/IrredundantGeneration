#!/usr/bin/env python3
"""Utilities for GAP weak-GP upper-bound logs.

These helpers validate the operational layer of the recursive weak-GP
computations.  They do not replace GAP's group-theoretic checks; they make sure
that split logs really cover the prefix tree emitted by the framework.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
from typing import Iterable


FORBIDDEN_PATTERNS = [
    re.compile(r"\bError,", re.I),
    re.compile(r"\bError\(", re.I),
    re.compile(r"Node limit exceeded", re.I),
    re.compile(r"FOUND weak-GP", re.I),
    re.compile(r"Counterexample family found", re.I),
    re.compile(r"\*\*\* JOB .* CANCELLED", re.I),
    re.compile(r"reached the pre-set memory limit", re.I),
    re.compile(r"Cannot extend fixed prefix", re.I),
    re.compile(r"FixedPrefix .* not weak-addable", re.I),
    re.compile(r"syntax error", re.I),
    re.compile(r"Exited with exit code", re.I),
    re.compile(r"you can 'quit;'", re.I),
    re.compile(r"brk>", re.I),
]


BRANCH_BLOCK_RE = re.compile(
    r"Branch minimum_selected_rank=(\d+) class=(\d+) first_index=(\d+)\n"
    r"(.*?)(?=\nBranch minimum_selected_rank=|\nUsing fixed prefix:|\nRESULT=|\Z)",
    re.S,
)


FIXED_BLOCK_RE = re.compile(
    r"Using fixed prefix:\s*\[(.*?)\].*?\n"
    r"(.*?)(?=\nUsing fixed prefix:|\nBranch minimum_selected_rank=|\nRESULT=|\Z)",
    re.S,
)


NEXT_REPS_RE = re.compile(
    r"Next orbit representatives for firstRank=\d+:\s*\[(.*?)\]\s*"
    r"Next classes:",
    re.S,
)


@dataclass(frozen=True)
class ListingEdge:
    """One prefix-splitting edge from a listing log."""

    parent: tuple[int, ...]
    child: tuple[int, ...]
    source: Path


@dataclass(frozen=True)
class SearchCover:
    """One ordinary search log covering one or more fixed prefixes."""

    path: Path
    prefixes: tuple[tuple[int, ...], ...]
    nodes: int


def read_text(path: Path) -> str:
    try:
        return path.read_text()
    except FileNotFoundError:
        raise SystemExit(f"missing file: {path}") from None


def check_clean(label: str, text: str) -> None:
    for pattern in FORBIDDEN_PATTERNS:
        if pattern.search(text) is not None:
            raise SystemExit(f"{label}: forbidden pattern {pattern.pattern!r}")


def parse_gap_int_list(text: str) -> tuple[int, ...]:
    range_match = re.fullmatch(r"\s*\[\s*(\d+)\s*\.\.\s*(\d+)\s*\]\s*", text)
    if range_match is not None:
        lo = int(range_match.group(1))
        hi = int(range_match.group(2))
        return tuple(range(lo, hi + 1))
    return tuple(int(x) for x in re.findall(r"\d+", text))


def parse_required_value(text: str, label: str) -> str | None:
    match = re.search(rf"^{re.escape(label)}\s*=\s*(.*?)$", text, re.M)
    if match is None:
        return None
    return match.group(1).strip()


def parse_group_name(text: str) -> str | None:
    for pattern in [
        r"Framework upper-bound run for\s+([A-Za-z0-9_']+)",
        r"Framework cached upper-bound run for\s+([A-Za-z0-9_']+)",
        r"Framework filtered upper-bound run for\s+([A-Za-z0-9_']+)",
        r"Framework member-filter run for\s+([A-Za-z0-9_']+)",
    ]:
        match = re.search(pattern, text)
        if match is not None:
            return match.group(1)
    return None


def parse_target_length(text: str) -> int | None:
    value = parse_required_value(text, "Target weak-GP length")
    if value is None:
        value = parse_required_value(text, "Ambient target weak-GP length")
    if value is None:
        return None
    match = re.search(r"\d+", value)
    return int(match.group(0)) if match is not None else None


def parse_gap_version(text: str) -> str | None:
    return parse_required_value(text, "GAP version")


def parse_framework_version(text: str) -> str | None:
    return parse_required_value(text, "UB framework version")


def parse_selected_classes(text: str) -> tuple[int, ...] | None:
    value = parse_required_value(text, "Selected classes")
    if value is None:
        value = parse_required_value(text, "Active maximal classes")
    if value is None:
        value = parse_required_value(text, "Selected maximal classes")
    if value is None:
        value = parse_required_value(text, "Prebuilt selected maximal classes")
    if value is None:
        return None
    return parse_gap_int_list(value)


def parse_action_degree(text: str) -> int | None:
    for label in [
        "Action degree",
        "Total selected maximal subgroups",
        "Total prebuilt maximal subgroups",
    ]:
        value = parse_required_value(text, label)
        if value is not None:
            match = re.search(r"\d+", value)
            if match is not None:
                return int(match.group(0))

    counts = [int(x) for x in re.findall(r"^Max class \d+:\s*(\d+)\s+conjugates", text, re.M)]
    if counts:
        return sum(counts)
    return None


def normalize_space(text: str) -> str:
    return " ".join(text.split())


def parse_max_class_table(text: str) -> tuple[tuple[int, int, int, str], ...]:
    """Parse the selected maximal-class table printed by the GAP framework."""

    rows: list[tuple[int, int, int, str]] = []
    pattern = re.compile(
        r"^Max class\s+(\d+):\s+(\d+)\s+conjugates,\s+size\s+"
        r"(\d+),\s+(.*?)(?=\nMax class\s+\d+:|\nBuilding conjugation action|\Z)",
        re.M | re.S,
    )
    for match in pattern.finditer(text):
        rows.append(
            (
                int(match.group(1)),
                int(match.group(2)),
                int(match.group(3)),
                normalize_space(match.group(4)),
            )
        )
    return tuple(rows)


def parse_nodes(text: str) -> int:
    matches = re.findall(r"^NODES=(\d+)$", text, re.M)
    if not matches:
        matches = re.findall(r"^SEARCH_NODES=(\d+)$", text, re.M)
    return sum(int(x) for x in matches)


def _parse_reps(body: str) -> tuple[int, ...]:
    match = NEXT_REPS_RE.search(body)
    if match is None:
        return ()
    return parse_gap_int_list(match.group(1))


def parse_listing_edges(path: Path) -> list[ListingEdge]:
    text = read_text(path)
    check_clean(str(path), text)
    if "RESULT=listed" not in text and "LISTING_COMPLETE" not in text:
        raise SystemExit(
            f"{path}: listing log does not contain RESULT=listed or LISTING_COMPLETE"
        )

    edges: list[ListingEdge] = []
    for match in BRANCH_BLOCK_RE.finditer(text):
        parent = (int(match.group(3)),)
        for rep in _parse_reps(match.group(4)):
            edges.append(ListingEdge(parent=parent, child=parent + (rep,), source=path))

    for match in FIXED_BLOCK_RE.finditer(text):
        parent = parse_gap_int_list(match.group(1))
        if not parent:
            raise SystemExit(f"{path}: could not parse fixed-prefix listing parent")
        for rep in _parse_reps(match.group(2)):
            edges.append(ListingEdge(parent=parent, child=parent + (rep,), source=path))

    return edges


def parse_listing_terminal_prefixes(path: Path) -> set[tuple[int, ...]]:
    text = read_text(path)
    check_clean(str(path), text)
    terminals: set[tuple[int, ...]] = set()

    for match in BRANCH_BLOCK_RE.finditer(text):
        parent = (int(match.group(3)),)
        if not _parse_reps(match.group(4)):
            terminals.add(parent)

    for match in FIXED_BLOCK_RE.finditer(text):
        parent = parse_gap_int_list(match.group(1))
        if parent and not _parse_reps(match.group(2)):
            terminals.add(parent)

    return terminals


def parse_top_level_branch_ranks(path: Path) -> list[int]:
    text = read_text(path)
    check_clean(str(path), text)
    return [int(match.group(1)) for match in BRANCH_BLOCK_RE.finditer(text)]


def parse_search_cover(path: Path) -> SearchCover:
    text = read_text(path)
    check_clean(str(path), text)
    if "RESULT=listed" in text:
        raise SystemExit(f"{path}: search log is a listing run")
    if "RESULT=partial_success" not in text and "RESULT=success" not in text:
        raise SystemExit(f"{path}: no success result marker")

    prefixes = tuple(
        parse_gap_int_list(match.group(1))
        for match in re.finditer(r"Using fixed prefix:\s*\[(.*?)\]", text)
    )
    if not prefixes:
        raise SystemExit(f"{path}: no fixed prefix recorded")
    if any(not prefix for prefix in prefixes):
        raise SystemExit(f"{path}: could not parse a fixed prefix")
    return SearchCover(path=path, prefixes=prefixes, nodes=parse_nodes(text))


def assert_metadata(
    path: Path,
    *,
    text: str,
    group: str | None = None,
    target: int | None = None,
    selected_classes: tuple[int, ...] | None = None,
    gap_version: str | None = None,
    framework_version: str | None = None,
    action_degree: int | None = None,
    require_present: bool = False,
) -> None:
    seen_group = parse_group_name(text)
    if require_present and group is not None and seen_group is None:
        raise SystemExit(f"{path}: missing group metadata")
    if group is not None and seen_group is not None and seen_group != group:
        raise SystemExit(f"{path}: group {seen_group!r} != expected {group!r}")

    seen_target = parse_target_length(text)
    if require_present and target is not None and seen_target is None:
        raise SystemExit(f"{path}: missing target metadata")
    if target is not None and seen_target is not None and seen_target != target:
        raise SystemExit(f"{path}: target {seen_target} != expected {target}")

    seen_selected = parse_selected_classes(text)
    if require_present and selected_classes is not None and seen_selected is None:
        raise SystemExit(f"{path}: missing selected-classes metadata")
    if (
        selected_classes is not None
        and seen_selected is not None
        and tuple(seen_selected) != selected_classes
    ):
        raise SystemExit(
            f"{path}: selected classes {seen_selected} != expected {selected_classes}"
        )

    seen_gap = parse_gap_version(text)
    if require_present and gap_version is not None and seen_gap is None:
        raise SystemExit(f"{path}: missing GAP version metadata")
    if gap_version is not None and seen_gap is not None and seen_gap != gap_version:
        raise SystemExit(f"{path}: GAP version {seen_gap} != expected {gap_version}")

    seen_framework = parse_framework_version(text)
    if require_present and framework_version is not None and seen_framework is None:
        raise SystemExit(f"{path}: missing framework-version metadata")
    if (
        framework_version is not None
        and seen_framework is not None
        and seen_framework != framework_version
    ):
        raise SystemExit(
            f"{path}: framework version {seen_framework} != expected {framework_version}"
        )

    seen_degree = parse_action_degree(text)
    if require_present and action_degree is not None and seen_degree is None:
        raise SystemExit(f"{path}: missing action-degree metadata")
    if action_degree is not None and seen_degree is not None and seen_degree != action_degree:
        raise SystemExit(
            f"{path}: action degree {seen_degree} != expected {action_degree}"
        )


def iter_paths_from_globs(patterns: Iterable[str]) -> list[Path]:
    paths: list[Path] = []
    for pattern in patterns:
        matched = sorted(Path().glob(pattern))
        if not matched:
            raise SystemExit(f"glob matched no files: {pattern}")
        paths.extend(matched)
    return sorted(set(paths))

#!/usr/bin/env python3
"""Validate a split weak-GP prefix computation.

The validator checks the operational certificate layer around GAP prefix runs:

* the depth-2 map log completed in listing mode;
* the prefix file exactly matches the prefixes parsed from the map log;
* every expected chunk log exists;
* no log contains GAP errors, node-limit failures, or found counterexamples;
* every chunk log reports success or partial success.

It deliberately does not re-prove the group theory; it makes sure the split
logs form a complete set of ordinary GAP searches.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path


FORBIDDEN_PATTERNS = [
    re.compile(r"\bError,", re.I),
    re.compile(r"\bError\(", re.I),
    re.compile(r"Node limit exceeded", re.I),
    re.compile(r"FOUND weak-GP", re.I),
    re.compile(r"Counterexample family found", re.I),
    re.compile(r"\*\*\* JOB .* CANCELLED", re.I),
    re.compile(r"reached the pre-set memory limit", re.I),
    re.compile(r"brk>", re.I),
]


BRANCH_RE = re.compile(
    r"Branch minimum_selected_rank=(\d+) class=\d+ first_index=(\d+)\n"
    r"(.*?)(?=\nBranch minimum_selected_rank=|\n(?:LISTING_COMPLETE|SUCCESS:)|\Z)",
    re.S,
)


def read(path: Path) -> str:
    try:
        return path.read_text()
    except FileNotFoundError:
        raise SystemExit(f"missing file: {path}") from None


def check_clean(label: str, text: str) -> None:
    for pattern in FORBIDDEN_PATTERNS:
        match = pattern.search(text)
        if match is not None:
            raise SystemExit(f"{label}: forbidden pattern {pattern.pattern!r}")


def parse_prefixes(map_text: str) -> list[str]:
    lines: list[str] = []
    for branch in BRANCH_RE.finditer(map_text):
        rank = int(branch.group(1))
        first = int(branch.group(2))
        body = branch.group(3)
        reps_match = re.search(
            rf"Next orbit representatives for firstRank={rank}:\s*\[(.*?)\]\s*Next classes:",
            body,
            re.S,
        )
        if reps_match is None:
            continue
        reps = [int(x) for x in re.findall(r"\d+", reps_match.group(1))]
        for rep in reps:
            lines.append(f"{rank}|[{first},{rep}]")
    return lines


def parse_prefix_tuple(prefix_line: str) -> tuple[int, ...]:
    if "|" in prefix_line:
        prefix_line = prefix_line.split("|", 1)[1]
    values = tuple(int(x) for x in re.findall(r"\d+", prefix_line))
    if not values:
        raise SystemExit(f"could not parse prefix tuple from {prefix_line!r}")
    return values


def parse_used_prefixes(log_text: str) -> list[tuple[int, ...]]:
    used: list[tuple[int, ...]] = []
    for match in re.finditer(r"Using fixed prefix:\s*\[(.*?)\]", log_text):
        used.append(tuple(int(x) for x in re.findall(r"\d+", match.group(1))))
    return used


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--map-log", required=True, type=Path)
    parser.add_argument("--prefix-file", required=True, type=Path)
    parser.add_argument(
        "--chunk-log-template",
        required=True,
        help="Path template containing {task}, e.g. logs/foo_{task}_create.log",
    )
    parser.add_argument("--chunk-size", required=True, type=int)
    args = parser.parse_args()

    map_text = read(args.map_log)
    check_clean(str(args.map_log), map_text)
    if "LISTING_COMPLETE" not in map_text:
        raise SystemExit("map log does not contain LISTING_COMPLETE")

    parsed = parse_prefixes(map_text)
    if not parsed:
        raise SystemExit("no prefixes parsed from map log")

    prefix_lines = [
        line.strip()
        for line in read(args.prefix_file).splitlines()
        if line.strip()
    ]
    if parsed != prefix_lines:
        raise SystemExit(
            "prefix file does not match map log "
            f"(parsed={len(parsed)}, file={len(prefix_lines)})"
        )

    expected_chunks = math.ceil(len(prefix_lines) / args.chunk_size)
    total_nodes = 0
    max_nodes = 0
    max_node_chunk = -1
    for task in range(expected_chunks):
        path = Path(args.chunk_log_template.format(task=task))
        text = read(path)
        check_clean(str(path), text)
        if "RESULT=partial_success" not in text and "RESULT=success" not in text:
            raise SystemExit(f"{path}: no RESULT success marker")
        if "LISTING_COMPLETE" in text:
            raise SystemExit(f"{path}: chunk log is a listing run, not a search")

        expected = [
            parse_prefix_tuple(line)
            for line in prefix_lines[task * args.chunk_size : (task + 1) * args.chunk_size]
        ]
        used = parse_used_prefixes(text)
        if used != expected:
            raise SystemExit(
                f"{path}: fixed prefixes do not match assignment "
                f"(expected={expected}, used={used})"
            )

        nodes_match = re.search(r"^NODES=(\d+)$", text, re.M)
        if nodes_match is not None:
            nodes = int(nodes_match.group(1))
            total_nodes += nodes
            if nodes > max_nodes:
                max_nodes = nodes
                max_node_chunk = task

    print(
        "VALID_PREFIX_CERTIFICATE "
        f"prefixes={len(prefix_lines)} chunks={expected_chunks} "
        f"total_nodes={total_nodes} max_nodes={max_nodes} "
        f"max_node_chunk={max_node_chunk}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

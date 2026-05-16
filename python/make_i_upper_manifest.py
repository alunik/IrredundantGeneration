#!/usr/bin/env python3
"""Build a JSON manifest for proper-subgroup weak-GP exclusion logs."""

from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path
import re
import sys

from validate_i_upper_manifest import (
    parse_done_records,
    parse_subgroup_counts,
)
from weakgp_logs import iter_paths_from_globs, normalize_space, read_text


def parse_expected_classes(paths: list[Path], *, group: str) -> list[int]:
    for path in paths:
        text = read_text(path)
        match = re.search(r"Maximal subgroup classes\s+=\s+(\d+)", text)
        if match is not None:
            return list(range(1, int(match.group(1)) + 1))
    raise SystemExit(f"could not infer maximal-class count for {group}")


def class_blocks(path: Path, *, group: str) -> dict[int, str]:
    text = read_text(path)
    pattern = re.compile(
        rf"Checking\s+{re.escape(group)}\s+maximal class\s+(\d+):"
        rf"(.*?)(?=Checking\s+{re.escape(group)}\s+maximal class\s+\d+:|\Z)",
        re.S,
    )
    return {int(match.group(1)): match.group(0) for match in pattern.finditer(text)}


def parse_shortcut(block: str, *, target: int) -> dict[str, object] | None:
    norm = re.sub(r"\\\s*", "", normalize_space(block))
    if "shortcut: top maximal class" not in norm:
        return None
    match = re.search(
        r"shortcut:\s+(?P<kind>\w+)\s+(?P<body>.*?)\s+excludes weak-GP\s*"
        rf"{target}\b",
        norm,
    )
    if match is None:
        raise SystemExit(f"top shortcut block did not parse: {norm[:240]}")
    kind = match.group("kind")
    body = match.group("body")
    shortcut: dict[str, object] = {"type": kind}
    if kind == "known_i_upper":
        group_match = re.search(r"group=([A-Za-z0-9_']+)", body)
        upper_match = re.search(r"i_upper=\s*(\d+)", body)
        if group_match is not None:
            shortcut["group"] = group_match.group(1)
        if upper_match is None:
            raise SystemExit(f"known_i_upper shortcut lacks i_upper: {norm[:240]}")
        shortcut["i_upper"] = int(upper_match.group(1))
    elif kind == "known_no_weak_gp":
        group_match = re.search(r"group=([A-Za-z0-9_']+)", body)
        weak_match = re.search(r"no_weak_gp=\s*(\d+)", body)
        if group_match is not None:
            shortcut["group"] = group_match.group(1)
        if weak_match is None:
            raise SystemExit(f"known_no_weak_gp shortcut lacks no_weak_gp: {norm[:240]}")
        shortcut["no_weak_gp"] = int(weak_match.group(1))
    elif kind == "order_bound":
        shortcut["proof"] = "Size(K) < 2^target"
    else:
        raise SystemExit(f"unsupported shortcut type {kind}")
    return shortcut


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--group", required=True)
    parser.add_argument("--target", required=True, type=int)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-classes")
    parser.add_argument("--log", action="append", type=Path, default=[])
    parser.add_argument("--log-glob", action="append", default=[])
    args = parser.parse_args()

    paths = sorted(set(args.log + iter_paths_from_globs(args.log_glob)))
    if not paths:
        raise SystemExit("no logs supplied")

    if args.expected_classes:
        expected_classes = [int(x) for x in args.expected_classes.split(",") if x]
    else:
        expected_classes = parse_expected_classes(paths, group=args.group)

    records_by_class: dict[int, list[tuple[Path, dict[str, int]]]] = defaultdict(list)
    counts_by_class: dict[int, int] = {}
    shortcuts_by_class: dict[int, dict[str, object]] = {}

    for path in paths:
        for cls, count in parse_subgroup_counts(path, group=args.group).items():
            old = counts_by_class.get(cls)
            if old is not None and old != count:
                raise SystemExit(f"class {cls}: subgroup counts differ ({old}, {count})")
            counts_by_class[cls] = count
        for record in parse_done_records(path, group=args.group):
            records_by_class[record["class"]].append((path, record))
        for cls, block in class_blocks(path, group=args.group).items():
            shortcut = parse_shortcut(block, target=args.target)
            if shortcut is not None:
                shortcut["source_log"] = str(path)
                shortcuts_by_class[cls] = shortcut

    classes = []
    for cls in expected_classes:
        if cls in shortcuts_by_class:
            classes.append({"class": cls, "shortcut": shortcuts_by_class[cls]})
            continue
        if cls not in records_by_class:
            raise SystemExit(f"class {cls}: no completed records or shortcut")
        if cls not in counts_by_class:
            raise SystemExit(f"class {cls}: no subgroup count")
        logs = []
        for path, record in sorted(
            records_by_class[cls], key=lambda item: (item[1]["start"], item[1]["stop"], str(item[0]))
        ):
            logs.append({
                "path": str(path),
                "start": record["start"],
                "stop": record["stop"],
                "target": record["target"],
            })
        classes.append({
            "class": cls,
            "subgroup_count": counts_by_class[cls],
            "logs": logs,
        })

    manifest = {
        "group": args.group,
        "target_no_weak_gp": args.target,
        "expected_classes": expected_classes,
        "classes": classes,
    }
    args.output.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"WROTE {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

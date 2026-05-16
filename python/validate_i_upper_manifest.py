#!/usr/bin/env python3
"""Validate proper-subgroup weak-GP exclusion manifests.

The manifest describes, for each top maximal subgroup class, either a shortcut
or a set of completed GAP range logs.  A log excluding weak-GP r also excludes
weak-GP s for every s >= r, because weak general position is hereditary under
passing to subfamilies.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from weakgp_logs import check_clean, normalize_space, read_text


DONE_RE = re.compile(
    r"completed\s+(?P<group>[A-Za-z0-9_']+)\s+maximal class\s+"
    r"(?P<class>\d+)\s+checked=(?P<checked>\d+)\s+"
    r"requested_range=\[(?P<start>\d+),\s*(?P<stop>\d+)\]\s+"
    r"no weak-GP\s*(?P<target>\d+)\s+found",
    re.S,
)

SUBGROUP_COUNT_RE = re.compile(
    r"Checking\s+(?P<group>[A-Za-z0-9_']+)\s+maximal class\s+"
    r"(?P<class>\d+):.*?subgroup class representatives = (?P<count>\d+)",
    re.S,
)


def parse_done_records(path: Path, *, group: str) -> list[dict[str, int]]:
    text = read_text(path)
    check_clean(str(path), text)
    if "SUCCESS:" not in text:
        raise SystemExit(f"{path}: no SUCCESS marker")
    records: list[dict[str, int]] = []
    for match in DONE_RE.finditer(text):
        record_group = match.group("group")
        if record_group != group:
            raise SystemExit(f"{path}: completed group {record_group} != {group}")
        records.append({
            "class": int(match.group("class")),
            "checked": int(match.group("checked")),
            "start": int(match.group("start")),
            "stop": int(match.group("stop")),
            "target": int(match.group("target")),
        })
    return records


def parse_subgroup_counts(path: Path, *, group: str) -> dict[int, int]:
    text = read_text(path)
    out: dict[int, int] = {}
    block_re = re.compile(
        rf"Checking\s+{re.escape(group)}\s+maximal class\s+(\d+):"
        rf"(.*?)(?=Checking\s+{re.escape(group)}\s+maximal class\s+\d+:|\Z)",
        re.S,
    )
    for block in block_re.finditer(text):
        count_match = re.search(
            r"subgroup class representatives = (?P<count>\d+)",
            block.group(2),
            re.S,
        )
        if count_match is not None:
            out[int(block.group(1))] = int(count_match.group("count"))
    return out


def class_block(path: Path, *, group: str, class_index: int) -> str:
    text = read_text(path)
    check_clean(str(path), text)
    pattern = re.compile(
        rf"Checking\s+{re.escape(group)}\s+maximal class\s+{class_index}:"
        rf".*?(?=Checking\s+{re.escape(group)}\s+maximal class\s+\d+:|\Z)",
        re.S,
    )
    match = pattern.search(text)
    if match is None:
        raise SystemExit(f"{path}: no block for {group} class {class_index}")
    return match.group(0)


def validate_shortcut_source(
    path: Path,
    *,
    group: str,
    class_index: int,
    target: int,
    shortcut_type: str,
) -> None:
    block = normalize_space(class_block(path, group=group, class_index=class_index))
    if f"shortcut: {shortcut_type}" not in block:
        raise SystemExit(
            f"{path}: class {class_index} does not record shortcut {shortcut_type}"
        )
    if f"shortcut: top maximal class {class_index} has certified no weak-GP" not in block:
        raise SystemExit(
            f"{path}: class {class_index} lacks top-class shortcut confirmation"
        )
    if re.search(rf"top maximal class {class_index} has certified no weak-GP\s*{target}\b", block) is None:
        raise SystemExit(
            f"{path}: class {class_index} shortcut does not certify weak-GP{target}"
        )


def interval_union(intervals: list[tuple[int, int]]) -> list[tuple[int, int]]:
    if not intervals:
        return []
    intervals = sorted(intervals)
    out = [intervals[0]]
    for start, stop in intervals[1:]:
        last_start, last_stop = out[-1]
        if start <= last_stop + 1:
            out[-1] = (last_start, max(last_stop, stop))
        else:
            out.append((start, stop))
    return out


def find_record(
    records: list[dict[str, int]],
    *,
    class_index: int,
    start: int,
    stop: int,
    target: int,
) -> dict[str, int]:
    for record in records:
        if (
            record["class"] == class_index
            and record["start"] == start
            and record["stop"] == stop
            and record["target"] <= target
        ):
            return record
    raise SystemExit(
        "no matching completed range "
        f"class={class_index} range=[{start},{stop}] target<={target}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    group = str(manifest["group"])
    target = int(manifest["target_no_weak_gp"])
    completed_classes = 0
    completed_ranges = 0
    shortcuts = 0

    record_cache: dict[Path, list[dict[str, int]]] = {}
    count_cache: dict[Path, dict[int, int]] = {}

    classes = [int(class_info["class"]) for class_info in manifest["classes"]]
    if len(classes) != len(set(classes)):
        raise SystemExit(f"duplicate classes in manifest: {classes}")
    if "expected_classes" in manifest:
        expected = {int(x) for x in manifest["expected_classes"]}
        seen = set(classes)
        if seen != expected:
            raise SystemExit(
                f"manifest classes {sorted(seen)} != expected {sorted(expected)}"
            )
    elif "maximal_class_count" in manifest:
        expected = set(range(1, int(manifest["maximal_class_count"]) + 1))
        seen = set(classes)
        if seen != expected:
            raise SystemExit(
                f"manifest classes {sorted(seen)} != expected {sorted(expected)}"
            )

    for class_info in manifest["classes"]:
        class_index = int(class_info["class"])
        if "shortcut" in class_info:
            shortcut = class_info["shortcut"]
            if not isinstance(shortcut, dict):
                raise SystemExit(f"class {class_index}: shortcut must be structured")
            shortcut_type = str(shortcut.get("type"))
            source = shortcut.get("source_log")
            if source is not None:
                validate_shortcut_source(
                    Path(str(source)),
                    group=group,
                    class_index=class_index,
                    target=target,
                    shortcut_type=shortcut_type,
                )

            if shortcut_type == "known_i_upper":
                i_upper = int(shortcut["i_upper"])
                if i_upper >= target:
                    raise SystemExit(
                        f"class {class_index}: i_upper={i_upper} does not exclude "
                        f"weak-GP{target}"
                    )
            elif shortcut_type == "known_no_weak_gp":
                no_weak_gp = int(shortcut["no_weak_gp"])
                if no_weak_gp > target:
                    raise SystemExit(
                        f"class {class_index}: no_weak_gp={no_weak_gp} is weaker "
                        f"than manifest target weak-GP{target}"
                    )
            elif shortcut_type == "order_bound":
                if "order" in shortcut and int(shortcut["order"]) >= 2 ** target:
                    raise SystemExit(
                        f"class {class_index}: order_bound has order="
                        f"{shortcut['order']} >= 2^{target}"
                    )
            else:
                raise SystemExit(f"class {class_index}: unsupported shortcut {shortcut}")

            dependencies = shortcut.get("dependency_paths", [])
            if isinstance(dependencies, str):
                dependencies = [dependencies]
            for dep in dependencies:
                dep_path = Path(str(dep))
                if not dep_path.exists():
                    raise SystemExit(
                        f"class {class_index}: shortcut dependency is missing: {dep}"
                    )
            shortcuts += 1
            completed_classes += 1
            continue

        subgroup_count = int(class_info["subgroup_count"])
        intervals: list[tuple[int, int]] = []
        for log_info in class_info["logs"]:
            path = Path(log_info["path"])
            if path not in record_cache:
                record_cache[path] = parse_done_records(path, group=group)
            if path not in count_cache:
                count_cache[path] = parse_subgroup_counts(path, group=group)
            log_target = int(log_info.get("target", target))
            if log_target > target:
                raise SystemExit(
                    f"{path}: per-log target {log_target} is weaker than manifest "
                    f"target {target}"
                )
            start = int(log_info["start"])
            stop = int(log_info["stop"])
            record = find_record(
                record_cache[path],
                class_index=class_index,
                start=start,
                stop=stop,
                target=log_target,
            )
            if int(record["target"]) != log_target:
                raise SystemExit(
                    f"{path}: completed target {record['target']} != manifest "
                    f"log target {log_target}"
                )
            seen_count = count_cache[path].get(class_index)
            if seen_count is None:
                raise SystemExit(
                    f"{path}: missing subgroup count for class {class_index}"
                )
            if seen_count != subgroup_count:
                raise SystemExit(
                    f"{path}: subgroup count {seen_count} != manifest "
                    f"{subgroup_count} for class {class_index}"
                )
            expected_checked = stop - start + 1
            if int(record["checked"]) != expected_checked:
                raise SystemExit(
                    f"{path}: checked={record['checked']} but "
                    f"range [{start},{stop}] has {expected_checked} entries"
                )
            intervals.append((start, stop))
            completed_ranges += 1

        merged = interval_union(intervals)
        if merged != [(1, subgroup_count)]:
            raise SystemExit(
                f"class {class_index}: intervals {merged} do not cover "
                f"[1,{subgroup_count}]"
            )
        completed_classes += 1

    print(
        "VALID_I_UPPER_MANIFEST "
        f"group={group} target={target} "
        f"classes={completed_classes} shortcuts={shortcuts} "
        f"ranges={completed_ranges}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

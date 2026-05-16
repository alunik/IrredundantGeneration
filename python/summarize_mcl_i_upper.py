#!/usr/bin/env python3
"""Summarize the McL proper-subgroup i(G) upper-bound verification logs."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


SUCCESS_RE = re.compile(r"SUCCESS: no proper subgroup of McL has weak-GP\s*7", re.S)
FOUND_RE = re.compile(r"FOUND weak-GP")
ERROR_RE = re.compile(r"\nError,|Node limit|memory limit|Syntax error", re.I)
CHECKED_RE = re.compile(r"Checked subgroup-class representatives = (?P<n>\d+)")
SELECTED_RE = re.compile(r"Selected top maximal classes = (?P<classes>.+)")


def read_ranges(path: Path) -> list[tuple[int, int, int]]:
    ranges: list[tuple[int, int, int]] = []
    for line_no, line in enumerate(path.read_text().splitlines(), start=1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split()
        if len(parts) != 3:
            raise ValueError(f"bad range line {line_no}: {line!r}")
        ranges.append(tuple(map(int, parts)))
    return ranges


def parse_log(path: Path) -> dict[str, object]:
    text = path.read_text(errors="ignore") if path.exists() else ""
    status = "missing" if not path.exists() else "incomplete"
    if FOUND_RE.search(text):
        status = "found"
    elif ERROR_RE.search(text):
        status = "error"
    elif SUCCESS_RE.search(text):
        status = "success"

    checked_match = CHECKED_RE.search(text)
    selected_match = SELECTED_RE.search(text)
    return {
        "path": path,
        "status": status,
        "checked": int(checked_match.group("n")) if checked_match else "",
        "selected": selected_match.group("classes").strip() if selected_match else "",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--range-file", required=True, type=Path)
    parser.add_argument("--log-dir", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    ranges = read_ranges(args.range_file)
    rows = []
    counts = {"success": 0, "found": 0, "error": 0, "incomplete": 0, "missing": 0}

    for task_id, (top_class, start, stop) in enumerate(ranges):
        replacement = args.log_dir / f"mcl_i_upper_range_{task_id}_corrected_local.log"
        if replacement.exists():
            path = replacement
            source = "corrected local"
        else:
            path = args.log_dir / f"mcl_i_upper_range_{task_id}_create.log"
            source = "create"
        info = parse_log(path)
        counts[str(info["status"])] = counts.get(str(info["status"]), 0) + 1
        rows.append((task_id, top_class, start, stop, source, info))

    u4_logs = [
        ("U4 member filter", args.log_dir / "u43_member_i6_filter.log",
         re.compile(r"SURVIVORS=\[ 1 \].*SUCCESS: member-i filter complete", re.S)),
        ("U4 class-1 MaxDim", args.log_dir / "u43_no_weakgp7_class1_only.log",
         re.compile(r"SUCCESS: no weak-GP7 family exists in U4\(3\).*SelectedClasses|\nSUCCESS: no weak-GP7 family exists in U4\(3\)", re.S)),
        ("U4 proper subgroups", args.log_dir / "u43_proper_i_upper_target7.log",
         re.compile(r"SUCCESS: no proper subgroup of U4\(3\) has weak-GP\s*7", re.S)),
    ]
    u4_status = []
    for label, path, pattern in u4_logs:
        text = path.read_text(errors="ignore") if path.exists() else ""
        u4_status.append((label, path.name, bool(path.exists() and pattern.search(text))))

    all_success = counts.get("success", 0) == len(ranges) and all(ok for _, _, ok in u4_status)

    lines = [
        "# McL Proper-Subgroup i Upper-Bound Verification",
        "",
        "Theorem target: every proper subgroup of McL has no weak-GP7 family; hence, together with the McL irredundant generating 6-tuple, i(McL)=6 once m(McL)=6 is established.",
        "",
        f"Range file: `{args.range_file}`",
        f"Log directory: `{args.log_dir}`",
        "",
        "## Summary",
        "",
        f"- slices: {len(ranges)}",
        f"- success: {counts.get('success', 0)}",
        f"- found obstruction: {counts.get('found', 0)}",
        f"- errors: {counts.get('error', 0)}",
        f"- incomplete: {counts.get('incomplete', 0)}",
        f"- missing logs: {counts.get('missing', 0)}",
        "",
        "## U4(3) Dependency",
        "",
    ]
    for label, name, ok in u4_status:
        lines.append(f"- {label}: {'success' if ok else 'not verified'} (`{name}`)")
    lines.extend(["", "## Ranges", "", "| task | top class | range | source | status | checked | log |", "| ---: | ---: | --- | --- | --- | ---: | --- |"])
    for task_id, top_class, start, stop, source, info in rows:
        lines.append(
            f"| {task_id} | {top_class} | [{start}, {stop}] | {source} | "
            f"{info['status']} | {info['checked']} | `{Path(info['path']).name}` |"
        )

    if all_success:
        lines.extend(["", "All scheduled ranges and the U4(3) dependency completed successfully."])
    else:
        lines.extend(["", "This manifest is not complete."])

    args.out.write_text("\n".join(lines) + "\n")
    print(args.out)
    return 0 if all_success else 1


if __name__ == "__main__":
    raise SystemExit(main())

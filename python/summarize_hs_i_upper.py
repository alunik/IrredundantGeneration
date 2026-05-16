#!/usr/bin/env python3
"""Summarize the distributed HS proper-subgroup i(G) verification logs."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


SUCCESS_RE = re.compile(r"SUCCESS: selected HS maximal classes")
FOUND_RE = re.compile(r"FOUND weak-GP")
ERROR_RE = re.compile(r"\nError,|Node limit|memory limit|Syntax error")
TOP_SHORTCUT_RE = re.compile(r"shortcut: top class is M22")
CLASS_RE = re.compile(
    r"Checking HS maximal class (?P<class>\d+): size=\s*(?P<size>\d+)\s+"
    r"struct=(?P<struct>.*?)\s+target_no_weakGP=\s*(?P<target>\d+)",
    re.S,
)
SUBGROUPS_RE = re.compile(r"subgroup class representatives = (?P<count>\d+)")
DONE_RE = re.compile(
    r"completed HS maximal class (?P<class>\d+) checked=(?P<checked>\d+)\s+"
    r"requested_range=\[(?P<start>\d+),\s*(?P<stop>\d+)\]\s+"
    r"no weak-GP\s*(?P<target>\d+) found",
    re.S,
)


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
    info: dict[str, object] = {
        "path": str(path),
        "status": "missing" if not path.exists() else "incomplete",
    }

    class_match = CLASS_RE.search(text)
    if class_match:
        info.update(
            {
                "class": int(class_match.group("class")),
                "size": int(class_match.group("size")),
                "struct": class_match.group("struct"),
                "target": int(class_match.group("target")),
            }
        )

    subgroups_match = SUBGROUPS_RE.search(text)
    if subgroups_match:
        info["subgroup_classes"] = int(subgroups_match.group("count"))

    done_match = DONE_RE.search(text)
    if done_match:
        info.update(
            {
                "checked": int(done_match.group("checked")),
                "done_start": int(done_match.group("start")),
                "done_stop": int(done_match.group("stop")),
                "done_target": int(done_match.group("target")),
            }
        )
    elif TOP_SHORTCUT_RE.search(text):
        info["checked"] = "shortcut"

    if FOUND_RE.search(text):
        info["status"] = "found"
    elif ERROR_RE.search(text):
        info["status"] = "error"
    elif SUCCESS_RE.search(text):
        info["status"] = "success"

    return info


def build_manifest(
    range_file: Path, log_dir: Path, job_id: str | None, theorem: str
) -> tuple[str, int]:
    ranges = read_ranges(range_file)
    rows = []
    counts = {"success": 0, "found": 0, "error": 0, "incomplete": 0, "missing": 0}

    for task_id, (top_class, start, stop) in enumerate(ranges):
        log_path = log_dir / f"hs_i_upper_range_{task_id}_create.log"
        info = parse_log(log_path)
        status = str(info["status"])
        counts[status] = counts.get(status, 0) + 1
        rows.append((task_id, top_class, start, stop, info))

    lines = [
        "# HS Proper-Subgroup i Upper-Bound Verification",
        "",
        f"Theorem target: {theorem}",
        "",
        f"Range file: `{range_file}`",
        f"Log directory: `{log_dir}`",
    ]
    if job_id:
        lines.append(f"Slurm job id: `{job_id}`")
    lines.extend(
        [
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
        ]
    )

    all_success = counts.get("success", 0) == len(ranges)
    if all_success:
        lines.extend(
            [
                "All scheduled ranges completed successfully and no weak-GP8 "
                "family was found in any checked subgroup.",
                "",
            ]
        )
    else:
        lines.extend(["This manifest is not yet complete.", ""])

    lines.extend(
        [
            "## Ranges",
            "",
            "| task | top class | requested range | status | checked | subgroup classes | struct | log |",
            "| ---: | ---: | --- | --- | ---: | ---: | --- | --- |",
        ]
    )
    for task_id, top_class, start, stop, info in rows:
        checked = info.get("checked", "")
        subgroup_classes = info.get("subgroup_classes", "")
        struct = str(info.get("struct", "")).replace("|", "\\|")
        log_name = Path(str(info["path"])).name
        lines.append(
            f"| {task_id} | {top_class} | [{start}, {stop}] | "
            f"{info['status']} | {checked} | {subgroup_classes} | "
            f"{struct} | `{log_name}` |"
        )

    exit_code = 0 if all_success else 1
    return "\n".join(lines) + "\n", exit_code


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--range-file", required=True, type=Path)
    parser.add_argument("--log-dir", required=True, type=Path)
    parser.add_argument("--job-id")
    parser.add_argument(
        "--theorem",
        default="Every proper subgroup of HS has no weak-GP8 family; hence i(HS)=7 with m(HS)=7.",
    )
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    manifest, exit_code = build_manifest(
        args.range_file, args.log_dir, args.job_id, args.theorem
    )
    if args.out:
        args.out.write_text(manifest)
    print(manifest)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())

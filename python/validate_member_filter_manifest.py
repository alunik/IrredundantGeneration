#!/usr/bin/env python3
"""Validate a member-filter plus restricted ambient-search certificate."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from weakgp_logs import (
    assert_metadata,
    check_clean,
    parse_gap_int_list,
    parse_required_value,
    parse_selected_classes,
    read_text,
)


def parse_gap_assignment_list(text: str, label: str) -> tuple[int, ...]:
    match = re.search(rf"^{re.escape(label)}=\s*(.*?)$", text, re.M)
    if match is None:
        raise SystemExit(f"missing {label}= line")
    return parse_gap_int_list(match.group(1))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    group = str(manifest["group"])
    target = int(manifest["target_no_weak_gp"])

    filter_info = manifest["member_filter"]
    filter_path = Path(filter_info["path"])
    filter_text = read_text(filter_path)
    check_clean(str(filter_path), filter_text)
    assert_metadata(
        filter_path,
        text=filter_text,
        group=group,
        target=target,
        require_present=True,
    )
    if "SUCCESS: framework member-filter run completed" not in filter_text:
        raise SystemExit(f"{filter_path}: missing member-filter success marker")

    survivors = parse_gap_assignment_list(filter_text, "SURVIVORS")
    excluded = parse_gap_assignment_list(filter_text, "EXCLUDED")
    expected_survivors = tuple(int(x) for x in filter_info["survivors"])
    expected_excluded = tuple(int(x) for x in filter_info["excluded"])
    if survivors != expected_survivors:
        raise SystemExit(f"{filter_path}: survivors {survivors} != {expected_survivors}")
    if excluded != expected_excluded:
        raise SystemExit(f"{filter_path}: excluded {excluded} != {expected_excluded}")
    if set(survivors).intersection(excluded):
        raise SystemExit(f"{filter_path}: survivor/excluded overlap")

    search_info = manifest["ambient_search"]
    search_path = Path(search_info["path"])
    search_text = read_text(search_path)
    check_clean(str(search_path), search_text)
    assert_metadata(
        search_path,
        text=search_text,
        group=group,
        target=target,
        selected_classes=expected_survivors,
        require_present=True,
    )
    if f"RESULT={search_info.get('result', 'success')}" not in search_text:
        raise SystemExit(f"{search_path}: missing expected result")
    if f"SUCCESS: framework no weak-GP{target}" not in search_text:
        raise SystemExit(f"{search_path}: missing ambient upper-bound success marker")

    selected = parse_selected_classes(search_text)
    if selected != expected_survivors:
        raise SystemExit(f"{search_path}: selected classes {selected} != survivors")

    print(
        "VALID_MEMBER_FILTER_MANIFEST "
        f"group={group} target={target} survivors={list(survivors)} "
        f"excluded={len(excluded)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())


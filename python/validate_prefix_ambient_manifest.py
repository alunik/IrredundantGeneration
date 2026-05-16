#!/usr/bin/env python3
"""Validate a dynamic member-filter plus prefix-cover ambient certificate."""

from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path
import sys

from validate_member_filter_manifest import parse_gap_assignment_list
from validate_weakgp_cover import (
    build_tree,
    cover_prefix,
    root_prefixes,
    validate_metadata,
)
from weakgp_logs import (
    SearchCover,
    assert_metadata,
    check_clean,
    iter_paths_from_globs,
    parse_search_cover,
    read_text,
)


def validate_filter(
    manifest: dict[str, object],
) -> tuple[str, int, tuple[int, ...], tuple[int, ...]]:
    group = str(manifest["group"])
    target = int(manifest["target_no_weak_gp"])
    filter_info = manifest["member_filter"]  # type: ignore[index]
    filter_path = Path(str(filter_info["path"]))  # type: ignore[index]
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
    expected_survivors = tuple(int(x) for x in filter_info["survivors"])  # type: ignore[index]
    expected_excluded = tuple(int(x) for x in filter_info["excluded"])  # type: ignore[index]
    if survivors != expected_survivors:
        raise SystemExit(f"{filter_path}: survivors {survivors} != {expected_survivors}")
    if excluded != expected_excluded:
        raise SystemExit(f"{filter_path}: excluded {excluded} != {expected_excluded}")
    return group, target, survivors, excluded


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    group, target, survivors, excluded = validate_filter(manifest)

    cover_info = manifest["prefix_cover"]
    listing_paths = [Path(str(path)) for path in cover_info["listings"]]
    search_paths = [Path(str(path)) for path in cover_info.get("search_logs", [])]
    search_paths.extend(iter_paths_from_globs(cover_info.get("search_globs", [])))
    search_paths = sorted(set(search_paths))

    if not listing_paths:
        raise SystemExit("prefix cover has no listing logs")
    if not search_paths:
        raise SystemExit("prefix cover has no search logs")

    validate_metadata(
        listing_paths + search_paths,
        group=group,
        target=target,
        selected_classes=survivors,
        gap_version=cover_info.get("expected_gap_version"),
        framework_version=cover_info.get("expected_framework_version"),
        action_degree=cover_info.get("expected_action_degree"),
        require_present=True,
    )

    tree, terminals = build_tree(listing_paths)
    if not tree and not terminals:
        raise SystemExit("no prefix edges or terminal prefixes parsed")

    direct: dict[tuple[int, ...], list[SearchCover]] = defaultdict(list)
    covers: list[SearchCover] = []
    for path in search_paths:
        cover = parse_search_cover(path)
        covers.append(cover)
        for prefix in cover.prefixes:
            direct[prefix].append(cover)

    roots = sorted(root_prefixes(tree, terminals))
    if not roots:
        raise SystemExit("no root prefixes found")

    leaves = 0
    for prefix in roots:
        leaves += cover_prefix(
            prefix,
            tree=tree,
            direct=direct,
            terminals=terminals,
            seen=set(),
        )

    print(
        "VALID_PREFIX_AMBIENT_MANIFEST "
        f"group={group} target={target} survivors={list(survivors)} "
        f"excluded={len(excluded)} roots={len(roots)} leaves={leaves} "
        f"search_logs={len(search_paths)} total_nodes={sum(c.nodes for c in covers)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Validate recursive fixed-prefix coverage for weak-GP searches.

Example:

    python3 python/validate_weakgp_cover.py \
      --group M24 \
      --target 8 \
      --selected-classes 2,3,5,7 \
      --listing logs/m24_classes2357_depth2_listing_current.log \
      --listing logs/m24_classes2357_branch1_prefixes_1036_1038_listing_current.log \
      --search-glob 'logs/m24_current_no_gp8_prefix_*.log'

The validator reads GAP listing logs as a prefix tree.  A prefix is covered if
either an ordinary GAP search log completed for that exact fixed prefix, or a
listing log split that prefix into children and every child is covered.
"""

from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

from weakgp_logs import (
    SearchCover,
    assert_metadata,
    parse_max_class_table,
    parse_listing_edges,
    parse_listing_terminal_prefixes,
    parse_top_level_branch_ranks,
    parse_search_cover,
    read_text,
    iter_paths_from_globs,
)


def parse_classes(value: str | None) -> tuple[int, ...] | None:
    if value is None:
        return None
    return tuple(int(part) for part in value.split(",") if part.strip())


def build_tree(
    listing_paths: list[Path],
) -> tuple[dict[tuple[int, ...], set[tuple[int, ...]]], set[tuple[int, ...]]]:
    tree: dict[tuple[int, ...], set[tuple[int, ...]]] = defaultdict(set)
    terminals: set[tuple[int, ...]] = set()
    for path in listing_paths:
        for edge in parse_listing_edges(path):
            tree[edge.parent].add(edge.child)
        terminals.update(parse_listing_terminal_prefixes(path))
    return tree, terminals


def root_prefixes(
    tree: dict[tuple[int, ...], set[tuple[int, ...]]],
    terminals: set[tuple[int, ...]],
) -> set[tuple[int, ...]]:
    children = {child for branch in tree.values() for child in branch}
    roots = set()
    for parent, branch in tree.items():
        if len(parent) == 1:
            roots.update(branch)
        elif parent not in children:
            roots.add(parent)
    for terminal in terminals:
        if len(terminal) == 1 or terminal not in children:
            roots.add(terminal)
    return roots


def validate_metadata(
    paths: list[Path],
    *,
    group: str | None,
    target: int | None,
    selected_classes: tuple[int, ...] | None,
    gap_version: str | None,
    framework_version: str | None,
    action_degree: int | None,
    require_present: bool,
) -> None:
    for path in paths:
        assert_metadata(
            path,
            text=read_text(path),
            group=group,
            target=target,
            selected_classes=selected_classes,
            gap_version=gap_version,
            framework_version=framework_version,
            action_degree=action_degree,
            require_present=require_present,
        )


def validate_class_table_consistency(paths: list[Path]) -> None:
    expected: tuple[tuple[int, int, int, str], ...] | None = None
    expected_path: Path | None = None
    for path in paths:
        table = parse_max_class_table(read_text(path))
        if not table:
            raise SystemExit(f"{path}: missing selected maximal-class table")
        if expected is None:
            expected = table
            expected_path = path
        elif table != expected:
            raise SystemExit(
                f"{path}: maximal-class table differs from {expected_path}"
            )


def cover_prefix(
    prefix: tuple[int, ...],
    *,
    tree: dict[tuple[int, ...], set[tuple[int, ...]]],
    direct: dict[tuple[int, ...], list[SearchCover]],
    terminals: set[tuple[int, ...]],
    seen: set[tuple[int, ...]],
) -> int:
    """Return the number of covered leaf prefixes in the subtree."""

    if prefix in direct:
        return 1
    if prefix in terminals:
        return 1

    if prefix in seen:
        raise SystemExit(f"cycle in prefix split tree at {prefix}")
    seen.add(prefix)

    children = sorted(tree.get(prefix, ()))
    if not children:
        raise SystemExit(f"uncovered prefix: {list(prefix)}")

    leaves = 0
    for child in children:
        leaves += cover_prefix(
            child, tree=tree, direct=direct, terminals=terminals, seen=seen
        )
    seen.remove(prefix)
    return leaves


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--group")
    parser.add_argument("--target", type=int)
    parser.add_argument("--selected-classes")
    parser.add_argument("--expected-first-ranks", type=int)
    parser.add_argument("--expected-gap-version")
    parser.add_argument("--expected-framework-version")
    parser.add_argument("--expected-action-degree", type=int)
    parser.add_argument("--require-metadata", action="store_true")
    parser.add_argument("--require-class-table", action="store_true")
    parser.add_argument("--fail-extra-search-prefixes", action="store_true")
    parser.add_argument("--listing", action="append", type=Path, required=True)
    parser.add_argument("--search-log", action="append", type=Path, default=[])
    parser.add_argument("--search-glob", action="append", default=[])
    args = parser.parse_args()

    selected_classes = parse_classes(args.selected_classes)
    listing_paths = args.listing
    search_paths = list(args.search_log) + iter_paths_from_globs(args.search_glob)

    validate_metadata(
        listing_paths + search_paths,
        group=args.group,
        target=args.target,
        selected_classes=selected_classes,
        gap_version=args.expected_gap_version,
        framework_version=args.expected_framework_version,
        action_degree=args.expected_action_degree,
        require_present=args.require_metadata,
    )
    if args.require_class_table:
        validate_class_table_consistency(listing_paths + search_paths)

    if args.expected_first_ranks is not None:
        ranks: set[int] = set()
        for listing in listing_paths:
            ranks.update(parse_top_level_branch_ranks(listing))
        expected = set(range(1, args.expected_first_ranks + 1))
        if ranks != expected:
            raise SystemExit(
                f"top-level branch ranks {sorted(ranks)} != expected {sorted(expected)}"
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

    total_leaves = 0
    for prefix in roots:
        total_leaves += cover_prefix(
            prefix, tree=tree, direct=direct, terminals=terminals, seen=set()
        )

    used_direct = set()
    for prefix in roots:
        stack = [prefix]
        while stack:
            current = stack.pop()
            if current in direct:
                used_direct.add(current)
            elif current in terminals:
                continue
            else:
                stack.extend(tree.get(current, ()))

    extra = sorted(set(direct) - used_direct)
    if extra:
        if args.fail_extra_search_prefixes:
            raise SystemExit(f"extra search prefixes: {list(map(list, extra))}")
        print(f"WARNING_EXTRA_SEARCH_PREFIXES={list(map(list, extra))}")

    total_nodes = sum(cover.nodes for cover in covers)
    print(
        "VALID_WEAKGP_COVER "
        f"roots={len(roots)} leaves={total_leaves} "
        f"search_logs={len(search_paths)} total_nodes={total_nodes}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

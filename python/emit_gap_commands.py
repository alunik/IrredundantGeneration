#!/usr/bin/env python3
"""Emit GAP command templates from the computation manifest."""

from __future__ import annotations

import argparse
import json
import shlex
import sys
from pathlib import Path
from typing import Any


def gap_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(value, list):
        return "[" + ",".join(gap_value(x) for x in value) + "]"
    raise TypeError(f"cannot render GAP value {value!r}")


def gap_assign(name: str, value: Any) -> str:
    return f"{name}:={gap_value(value)};"


def gap_command(assignments: list[tuple[str, Any]], read_path: str, *, load: str | None = None) -> str:
    script = "".join(gap_assign(name, value) for name, value in assignments)
    script += f'Read("{read_path}");'
    parts = ["gap", "-q"]
    if load is not None:
        parts.extend(["-L", load])
    parts.extend(["-c", script])
    return " ".join(shlex.quote(part) for part in parts)


def m_upper_commands(group: str, manifest: dict[str, Any]) -> list[str]:
    entrypoints = manifest["generic_gap_entrypoints"]
    section = manifest["groups"][group]["m_upper"]
    settings = section["settings"]
    action = section["action"]

    build_assignments: list[tuple[str, Any]] = [
        ("WorkspaceRoot", "."),
        ("TargetGroupName", group),
        ("ActionWorkspacePath", action["workspace"]),
    ]
    if action["selected_classes"] != "all":
        build_assignments.append(("SelectedClasses", action["selected_classes"]))

    run_assignments: list[tuple[str, Any]] = [
        ("WorkspaceRoot", "."),
        ("TargetGroupName", group),
        ("TargetLength", settings["TargetLength"]),
    ]

    commands = [
        f"mkdir -p {shlex.quote(str(Path(action['workspace']).parent))}",
        "# build the reusable conjugation-action workspace",
        gap_command(build_assignments, entrypoints["action_builder"]),
        "# run the ambient weak-GP exclusion using the saved action",
    ]

    if settings.get("prefix") is True:
        commands.append(
            "# prefix runs use FixedPrefix or FixedPrefixes from the manifest "
            "prefix file/cover"
        )
        commands.append(
            gap_command(
                run_assignments + [("ListDepth2RepsOnly", True)],
                entrypoints["cached_or_prefix_upper"],
                load=action["workspace"],
            )
        )
        commands.append(
            "# example chunk template; replace the list by a prefix from the prefix file"
        )
        commands.append(
            gap_command(
                run_assignments + [("FixedPrefix", [1, 2])],
                entrypoints["cached_or_prefix_upper"],
                load=action["workspace"],
            )
        )
    else:
        commands.append(
            gap_command(
                run_assignments,
                entrypoints["cached_or_prefix_upper"],
                load=action["workspace"],
            )
        )

    return commands


def proper_upper_command(group: str, manifest: dict[str, Any]) -> str:
    entrypoints = manifest["generic_gap_entrypoints"]
    section = manifest["groups"][group]["i_upper"]
    settings = section["settings"]
    assignments = [
        ("WorkspaceRoot", "."),
        ("TargetGroupName", group),
        ("TargetProperUpper", settings["TargetProperUpper"]),
    ]
    if "CheckStrongFlatTarget" in settings:
        assignments.append(("CheckStrongFlatTarget", settings["CheckStrongFlatTarget"]))
    if settings.get("SelectedTopClasses") != "all":
        assignments.append(("SelectedTopClasses", settings["SelectedTopClasses"]))
    return gap_command(assignments, entrypoints["proper_subgroup_upper"])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=Path("data/certificate_runs.json"))
    parser.add_argument("--group", action="append")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--section", choices=["m_upper", "i_upper"], default="m_upper")
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    groups = sorted(manifest["groups"])
    if args.group:
        groups = args.group
    if not args.group and not args.all:
        raise SystemExit("use --group GROUP or --all")

    for group in groups:
        if group not in manifest["groups"]:
            raise SystemExit(f"unknown group: {group}")
        print(f"## {group} {args.section}")
        if args.section == "m_upper":
            print("\n".join(m_upper_commands(group, manifest)))
        else:
            print(proper_upper_command(group, manifest))
        print()

    return 0


if __name__ == "__main__":
    sys.exit(main())

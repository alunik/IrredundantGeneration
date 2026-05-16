#!/usr/bin/env python3
"""Validate the specs that map groups to generic computation settings."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def require_path(root: Path, path: str, *, label: str) -> None:
    candidate = root / path
    if not candidate.exists():
        raise SystemExit(f"{label} does not exist: {path}")


def validate_class_selection(value: object, *, label: str) -> None:
    if value == "all":
        return
    if isinstance(value, list) and all(isinstance(x, int) and x > 0 for x in value):
        if len(set(value)) != len(value):
            raise SystemExit(f"{label} contains duplicate classes: {value!r}")
        return
    raise SystemExit(f"{label} must be 'all' or a list of positive integers")


def validate_action(entrypoints: dict[str, object], group: str, section: dict[str, object]) -> None:
    action = section.get("action")
    if not isinstance(action, dict):
        raise SystemExit(f"{group}.m_upper: missing cached action block")
    if action.get("builder") != "action_builder":
        raise SystemExit(f"{group}.m_upper.action: builder must be 'action_builder'")
    if "action_builder" not in entrypoints:
        raise SystemExit("specs are missing generic action_builder entrypoint")

    workspace = action.get("workspace")
    if not isinstance(workspace, str) or not workspace:
        raise SystemExit(f"{group}.m_upper.action: workspace must be a nonempty string")
    if Path(workspace).is_absolute() or ".." in Path(workspace).parts:
        raise SystemExit(f"{group}.m_upper.action: workspace must be a relative safe path")
    if not (workspace.startswith("workspaces/") or workspace.startswith("cache/")):
        raise SystemExit(
            f"{group}.m_upper.action: workspace should live under workspaces/ or cache/"
        )
    if action.get("build_once_reuse") is not True:
        raise SystemExit(f"{group}.m_upper.action: build_once_reuse must be true")

    selected = action.get("selected_classes")
    validate_class_selection(selected, label=f"{group}.m_upper.action.selected_classes")

    settings = section["settings"]
    setting_classes = settings.get("SelectedClasses", "all")
    if "survivors" in settings:
        setting_classes = settings["survivors"]
    if selected != setting_classes:
        raise SystemExit(
            f"{group}.m_upper: action selected_classes {selected!r} "
            f"do not match search classes {setting_classes!r}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--specs",
        type=Path,
        default=Path("data/computation_specs.json"),
    )
    args = parser.parse_args()

    root = args.specs.resolve().parents[1]
    specs = json.loads(args.specs.read_text())

    entrypoints = specs["generic_gap_entrypoints"]
    python_tools = specs["python_tools"]

    allowed_runners = set(entrypoints)
    for name, path in entrypoints.items():
        require_path(root, str(path), label=f"GAP entrypoint {name}")
    for name, path in python_tools.items():
        require_path(root, str(path), label=f"Python tool {name}")

    groups = specs["groups"]
    for group, info in groups.items():
        for section_name in ("m_upper", "i_upper"):
            section = info.get(section_name)
            if section is None:
                raise SystemExit(f"{group}: missing {section_name}")
            runner = section.get("runner")
            if runner not in allowed_runners:
                raise SystemExit(f"{group}.{section_name}: non-generic runner {runner!r}")
            if section_name == "m_upper" and runner != "cached_or_prefix_upper":
                raise SystemExit(
                    f"{group}.m_upper: ambient upper bounds must use "
                    "cached_or_prefix_upper"
                )

            settings = section.get("settings")
            if not isinstance(settings, dict):
                raise SystemExit(f"{group}.{section_name}: settings must be an object")
            if settings.get("TargetGroupName") != group:
                raise SystemExit(
                    f"{group}.{section_name}: TargetGroupName "
                    f"{settings.get('TargetGroupName')!r} does not match group"
                )

            if section_name == "m_upper":
                validate_action(entrypoints, group, section)
                prefix = settings.get("prefix")
                if not isinstance(prefix, bool):
                    raise SystemExit(f"{group}.m_upper: prefix must be true or false")
                if prefix:
                    chunk_size = settings.get("chunk_size")
                    if chunk_size is not None and (
                        not isinstance(chunk_size, int) or chunk_size <= 0
                    ):
                        raise SystemExit(
                            f"{group}.m_upper: chunk_size must be a positive integer"
                        )

    print(
        "VALID_COMPUTATION_SPECS "
        f"groups={len(groups)} gap_entrypoints={len(entrypoints)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

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


def validate_output_path(value: object, *, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise SystemExit(f"{label} must be a nonempty string")
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        raise SystemExit(f"{label} must be a relative safe path")
    if not (value.startswith("workspaces/") or value.startswith("cache/")):
        raise SystemExit(f"{label} should live under workspaces/ or cache/")
    return value


def validate_action(entrypoints: dict[str, object], group: str, section: dict[str, object]) -> None:
    filter_spec = section.get("filter")
    if not isinstance(filter_spec, dict):
        raise SystemExit(f"{group}.m_upper: missing dynamic filter block")
    if filter_spec.get("runner") != "member_filter":
        raise SystemExit(f"{group}.m_upper.filter: runner must be 'member_filter'")
    if "member_filter" not in entrypoints:
        raise SystemExit("specs are missing generic member_filter entrypoint")

    survivor_path = validate_output_path(
        filter_spec.get("survivors_path"),
        label=f"{group}.m_upper.filter.survivors_path",
    )
    validate_output_path(
        filter_spec.get("excluded_path"),
        label=f"{group}.m_upper.filter.excluded_path",
    )

    action = section.get("action")
    if not isinstance(action, dict):
        raise SystemExit(f"{group}.m_upper: missing cached action block")
    if action.get("builder") != "action_builder":
        raise SystemExit(f"{group}.m_upper.action: builder must be 'action_builder'")
    if "action_builder" not in entrypoints:
        raise SystemExit("specs are missing generic action_builder entrypoint")

    validate_output_path(action.get("workspace"), label=f"{group}.m_upper.action.workspace")
    if action.get("build_once_reuse") is not True:
        raise SystemExit(f"{group}.m_upper.action: build_once_reuse must be true")

    if action.get("selected_classes") != "from_member_filter":
        raise SystemExit(
            f"{group}.m_upper.action: selected_classes must be 'from_member_filter'"
        )
    if action.get("selected_classes_path") != survivor_path:
        raise SystemExit(
            f"{group}.m_upper.action: selected_classes_path must match "
            "filter.survivors_path"
        )

    settings = section["settings"]
    forbidden = ("SelectedClasses", "survivors", "member_filter_excluded_classes")
    for key in forbidden:
        if key in settings:
            raise SystemExit(
                f"{group}.m_upper.settings: {key} hard-codes filter output"
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

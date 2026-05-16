#!/usr/bin/env python3
"""Validate the manifest that maps groups to generic computation settings."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def as_list(value: object) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [str(x) for x in value]
    raise SystemExit(f"expected path or path list, got {value!r}")


def require_path(root: Path, path: str, *, label: str) -> None:
    candidate = root / path
    if not candidate.exists():
        raise SystemExit(f"{label} does not exist: {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("data/certificate_runs.json"),
    )
    args = parser.parse_args()

    root = args.manifest.resolve().parents[1]
    manifest = json.loads(args.manifest.read_text())

    entrypoints = manifest["generic_gap_entrypoints"]
    validators = manifest["python_validators"]

    allowed_runners = set(entrypoints)
    for name, path in entrypoints.items():
        require_path(root, str(path), label=f"GAP entrypoint {name}")
    for name, path in validators.items():
        require_path(root, str(path), label=f"Python validator {name}")

    groups = manifest["groups"]
    for group, info in groups.items():
        for cert in info.get("tuple_certificates", []):
            require_path(root, str(cert), label=f"{group} tuple certificate")

        for section_name in ("m_upper", "i_upper"):
            section = info.get(section_name)
            if section is None:
                raise SystemExit(f"{group}: missing {section_name}")
            runner = section.get("runner")
            if runner not in allowed_runners:
                raise SystemExit(f"{group}.{section_name}: non-generic runner {runner!r}")

            settings = section.get("settings")
            if not isinstance(settings, dict):
                raise SystemExit(f"{group}.{section_name}: settings must be an object")
            if settings.get("TargetGroupName") != group:
                raise SystemExit(
                    f"{group}.{section_name}: TargetGroupName "
                    f"{settings.get('TargetGroupName')!r} does not match group"
                )

            for key in ("logs", "manifest"):
                for path in as_list(section.get(key)):
                    require_path(root, path, label=f"{group}.{section_name}.{key}")

    print(
        "VALID_CERTIFICATE_RUNS "
        f"groups={len(groups)} gap_entrypoints={len(entrypoints)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

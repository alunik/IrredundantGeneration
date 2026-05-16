#!/usr/bin/env python3
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def gap_executable() -> str:
    gap = shutil.which("gap")
    if gap:
        return gap
    local = Path.home() / ".local" / "bin" / "gap"
    if local.exists():
        return str(local)
    raise SystemExit("Could not find GAP on PATH or at ~/.local/bin/gap")


def validate_image_list(xs: list[int], degree: int) -> None:
    if sorted(xs) != list(range(1, degree + 1)):
        raise SystemExit(f"Not a degree-{degree} permutation image list: {xs}")


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    cert_path = root / "certs" / "m22_tuple6.json"
    if len(sys.argv) > 1:
        cert_path = Path(sys.argv[1]).resolve()

    cert = json.loads(cert_path.read_text())
    group_name = cert["group"]["name"]
    degree = int(cert["group"]["degree"])
    expected_order = int(cert["group"]["order"])
    expected_generated_order = int(cert.get("full_generated_order", expected_order))
    require_generating = expected_generated_order == expected_order
    generator_images = cert["group"]["generators"]
    tuple_images = cert["tuple"]
    for xs in generator_images:
        validate_image_list(xs, degree)
    for xs in tuple_images:
        validate_image_list(xs, degree)

    gap_generators = json.dumps(generator_images)
    gap_list = json.dumps(tuple_images)
    script = f'''
WorkspaceRoot := "{root}";;
TargetGroupName := "{group_name}";;
ExpectedGroupOrder := {expected_order};;
ExpectedGeneratedOrder := {expected_generated_order};;
RequireGenerating := {"true" if require_generating else "false"};;
GeneratorImages := {gap_generators};;
TupleImages := {gap_list};;
Read(Concatenation(WorkspaceRoot, "/gap/42_verify_irredundant_tuple_from_images.g"));
'''

    with tempfile.NamedTemporaryFile("w", suffix=".g", delete=False) as handle:
        handle.write(script)
        temp_name = handle.name

    try:
        result = subprocess.run([gap_executable(), "-q", temp_name], cwd=root)
        return result.returncode
    finally:
        Path(temp_name).unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env bash
# CUDA 12.x host compile: disambiguate make_float3 in pulsar headers (fabibo3 MeshesXD fork).
set -euo pipefail
ROOT="${1:?usage: patch_pytorch3d_cuda12_pulsar.sh PYTORCH3D_SRC}"
PULSAR="${ROOT}/pytorch3d/csrc/pulsar/include"
[[ -d "$PULSAR" ]] || { echo "missing $PULSAR" >&2; exit 2; }
export ROOT PULSAR
python3 <<'PY'
import re
from pathlib import Path
import os

pulsar = Path(os.environ["PULSAR"])
pat = re.compile(r"make_float3\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\s*\)")

def patch_file(path: Path) -> int:
    text = path.read_text()
    if "DLSurfer CUDA12 pulsar patch" in text:
        return 0
    new, n = pat.subn(r"float3{\1, \2, \3}", text)
    if n:
        new = "// DLSurfer CUDA12 pulsar patch\n" + new
        path.write_text(new)
    return n

total = 0
for path in pulsar.rglob("*.h"):
    total += patch_file(path)
print(f"patched make_float3 in {total} places under {pulsar}")
PY

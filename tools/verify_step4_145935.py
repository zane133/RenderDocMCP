"""Reverse every Step 4 rename and confirm the result is byte-identical to Step 1."""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_step4_145935 import CB_ALIASES, SAMPLERS, SHADERS, TEXTURES  # noqa: E402

STEP1 = SHADERS / "zmd_ps_20260922_145935_step1_renderdoc.hlsl"
STEP4 = SHADERS / "zmd_ps_20260922_145935_step4_readable.hlsl"


def strip_comments(lines: list[str]) -> list[str]:
    return [l for l in lines if l.strip() and not l.lstrip().startswith("//")]


def unrename(text: str) -> str:
    for name, bank, index, _ in CB_ALIASES:
        if bank is None:
            continue
        text = re.sub(rf"\b{name}\b", f"cb{bank}[{index}]", text)
    for reg, name in TEXTURES.items():
        text = re.sub(rf"\b{name}\b", reg, text)
    for reg, name in SAMPLERS.items():
        text = re.sub(rf"\b{name}\b", reg, text)
    return text


def main() -> int:
    want = strip_comments(STEP1.read_text(encoding="utf-8").split("\n"))

    got = STEP4.read_text(encoding="utf-8").split("\n")
    got = [l for l in got if not re.match(r"\s*const float4 \w+ = cb\d\[\d+\];", l)]
    got = strip_comments(unrename("\n".join(got)).split("\n"))

    if got == want:
        print(f"[ok] {len(want)} code lines identical to Step 1")
        return 0

    print(f"[fail] {STEP4.name} diverges from {STEP1.name}", file=sys.stderr)
    for i, (a, b) in enumerate(zip(want, got)):
        if a != b:
            print(
                f"  first diff at code line {i}:\n    step1: {a}\n    step4: {b}",
                file=sys.stderr,
            )
            break
    if len(want) != len(got):
        print(f"  line count: step1={len(want)} step4={len(got)}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

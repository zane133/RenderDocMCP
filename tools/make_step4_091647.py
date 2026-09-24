"""Build Step 4 for the Apply-verified 2026-09-24 09:16:47 dump.

The shader body matches the 2026-09-22 14:03:15 family, so reuse its
value-preserving rename/alias/section transform with current input/output paths.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT = ROOT / "tools" / "make_step4_140315.py"

spec = importlib.util.spec_from_file_location("make_step4_140315", BASE_SCRIPT)
assert spec is not None and spec.loader is not None
step4 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(step4)

step4.SRC = ROOT / "shaders" / "zmd_ps_20260924_091647_step1_renderdoc.hlsl"
step4.DST = ROOT / "shaders" / "zmd_ps_20260924_091647_step4_readable.hlsl"
step4.HEADER = """// ZMD / Endfield PS - Step 4: readable resource names, CB aliases, section map
// Source dump: 3Dmigoto 2026-09-24 09:16:47
//
// Apply-verified Step 1. This pass changes NO shader math:
//   - Texture / sampler symbols renamed; register(tN/sN) bindings untouched
//   - const float4 aliases replace cbN[i] references without repacking CBs
//   - section comments map the toon-skin, GI, light, rim, and fog stages
// Interpolators v0..v10 remain direct inputs; no shader path was removed.
//
"""


if __name__ == "__main__":
    step4.main()

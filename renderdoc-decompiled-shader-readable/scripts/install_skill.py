#!/usr/bin/env python3
"""把本仓库的 renderdoc-decompiled-shader-readable 用目录联接/符号链接装到各产品的 skills 目录。"""

from __future__ import annotations

import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "renderdoc-decompiled-shader-readable"


def skill_src() -> Path:
    return Path(__file__).resolve().parents[1]


def default_targets() -> dict[str, Path]:
    h = Path.home()
    repo = skill_src().parent
    return {
        "cursor": h / ".cursor" / "skills" / SKILL_NAME,
        "claude": h / ".claude" / "skills" / SKILL_NAME,
        "codex": h / ".codex" / "skills" / SKILL_NAME,
        "repo-agents": repo / ".agents" / "skills" / SKILL_NAME,
    }


def make_link(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if sys.platform == "win32":
        proc = subprocess.run(
            ["cmd", "/c", "mklink", "/J", str(dest), str(src)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if proc.returncode != 0:
            raise RuntimeError((proc.stdout or "") + (proc.stderr or ""))
        return
    dest.symlink_to(src, target_is_directory=True)


def install_one(name: str, dest: Path, src: Path, replace: bool) -> str:
    src_r = src.resolve()
    if dest.exists() or dest.is_symlink():
        try:
            resolved = dest.resolve()
        except OSError:
            resolved = None
        if resolved == src_r:
            return f"完成   {name}: 已指向本仓库（{dest}）"
        if dest.is_symlink() and not replace:
            return f"跳过   {name}: 已是别的链接（{dest} -> {resolved}）。加 --replace 再跑。"
        if not replace:
            return (
                f"跳过   {name}: {dest} 已有一份拷贝。"
                "加 --replace 会先备份再做目录联接。"
            )
        bak = dest.with_name(dest.name + ".bak-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
        dest.rename(bak)
        make_link(src, dest)
        return f"已链接 {name}: {dest} -> {src}  （备份 {bak.name}）"
    if not dest.parent.exists():
        return f"跳过   {name}: 父目录不存在（{dest.parent}）。先建 skills 目录，或不装这一项。"
    make_link(src, dest)
    return f"已链接 {name}: {dest} -> {src}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="只列出安装目标")
    parser.add_argument(
        "--only",
        choices=list(default_targets().keys()),
        action="append",
        help="只装一部分（可重复）",
    )
    parser.add_argument(
        "--replace",
        action="store_true",
        help="先备份已有拷贝，再换成目录联接/符号链接",
    )
    args = parser.parse_args()

    src = skill_src()
    if not (src / "SKILL.md").is_file():
        print(f"错误: 在 {src} 下找不到 SKILL.md", file=sys.stderr)
        return 1

    targets = default_targets()
    names = args.only or list(targets.keys())

    if args.list:
        print(f"源目录: {src}")
        for name in names:
            print(f"  {name:12} {targets[name]}")
        return 0

    print(f"源目录: {src}")
    for name in names:
        dest = targets[name]
        try:
            print(install_one(name, dest, src, args.replace))
        except (OSError, RuntimeError) as exc:
            print(f"错误  {name}: {exc}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

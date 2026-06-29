#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import stat
import subprocess
import sys
from pathlib import Path


def eprint(*a, **k):
    print(*a, file=sys.stderr, **k)


def chmod_x(path: Path):
    """chmod +x ELF_path"""
    st = path.stat()
    path.chmod(st.st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def detect_arch(path: Path) -> str:
    """
    识别 ELF文件是 x86_32 还是 x86_64，并返回：
        x86_32 -> i386
        x85_64 -> amd64
    """

    data = path.read_bytes()
    if len(data) < 20 or data[:4] != b"\x7fELF":
        raise ValueError("不是有效 ELF (magic不匹配)")

    # 判断大小端序
    if data[5] == 1:
        endian = "little"
    elif data[5] == 2:
        endian = "big"
    else:
        raise (f"未知 ELF_DATA = {data[5]}")

    # 判断架构
    e_machine = int.from_bytes(data[18:19], endian)
    if e_machine == 3:
        return "i386"
    elif e_machine == 62:
        return "amd64"
    else:
        raise ValueError(f"非 x86 ELF (e_machine={e_machine})，目前仅支持x86_32/x86_64")


def run_checksec(elf_ads: Path) -> int:
    cmd = ["pwn", "checksec", f"--file={str(elf_ads)}"]

    try:
        return subprocess.run(cmd).returncode  # 直接输出到终端
    except FileNotFoundError:
        eprint("[WARN] 找不到 'pwn' 命令：请确认安装 pwntools 且 'pwn' 在 PATH 中")
        return 127


def scripts_dir_from_self() -> Path:
    return Path(__file__).resolve().parent.parent


# 全局变量：模板目录
TEMPLATES_DIR = scripts_dir_from_self() / "templates"

# 模板类型 -> 模板文件名
TEMPLATE_BY_TYPE = {
    "": "exp.py",
    "heap": "exp_heap.py",
}


def main() -> int:
    if len(sys.argv) not in (2, 3):
        eprint("用法：pwninit ELF_PATH [heap]")
        return 2

    tpl_type = sys.argv[2] if len(sys.argv) == 3 else ""
    if tpl_type not in TEMPLATE_BY_TYPE:
        eprint(f"[WARN] 未知模板类型：{tpl_type}（可选：heap，留空为默认）")
        return 2
    tql = TEMPLATES_DIR / TEMPLATE_BY_TYPE[tpl_type]

    elf = Path(sys.argv[1]).expanduser()
    if not elf.exists() or not elf.is_file():
        eprint(f"[WARN] ELF 不存在或者不是文件：{elf}")
        return 2

    elf_abs = elf.resolve()
    elf_dir = elf.resolve().parent

    # chmod +x ELF
    try:
        chmod_x(elf_abs)
    except PermissionError:
        eprint(f"[WARN] 无权限执行 chmod + x {elf_abs}")

    # checksec
    run_checksec(elf_abs)

    # detect_arch
    try:
        arch = detect_arch(elf_abs)
    except Exception as e:
        eprint(f"[WARN] 架构识别失败：{e}")

    # copy exp.py
    if not tql.exists():
        eprint(f"[WARN] 找不到exp模板：{tql}")
        return 4

    template_text = tql.read_text(encoding="utf-8", errors="replace")

    # 替换占位符
    filled = (
        template_text.replace("[ARCH]", arch)
        .replace("[ELF_PATH]", str(elf_abs))
        .replace("[PWNKIT_PATH]", str(scripts_dir_from_self()))
    )

    out_path = (elf_dir / "exp.py").resolve()

    # 若已经存在 exp.py，备份
    if out_path.exists():
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        bak = out_path.with_suffix(out_path.suffix + f".bak_{ts}")
        out_path.rename(bak)
        eprint(f"[INFO] 已备份原 exp.py -> {bak.name}")

    out_path.write_text(filled, encoding="utf-8")

    try:
        chmod_x(out_path)
    except PermissionError:
        eprint(f"[WARN] 无权限 chmod +x {out_path}")

    eprint(f"[*] template: {tql} -> {out_path}")
    eprint(f"[*] arch={arch} elf={elf_abs}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

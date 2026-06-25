import json
import os
from pathlib import Path

import gdb


def _split_path(value):
    if not value:
        return []
    return [item for item in str(value).split(os.pathsep) if item]


def _add_unique(paths, path):
    text = str(path)
    if text not in paths:
        paths.append(text)


def _existing_dir(path):
    return path.is_dir()


def _load_config():
    config_path = Path(__file__).resolve().with_name("config.json")
    if not config_path.is_file():
        return {}

    try:
        with config_path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:
        gdb.write(f"[pwn-scripts] failed to read {config_path}: {exc}\n", gdb.STDERR)
        return {}


def _get_libs_root():
    env_path = os.environ.get("PWN_GLIBC_LIBS_DIR")
    if env_path:
        return Path(env_path).expanduser()

    config = _load_config()
    libs_dir = config.get("glibc_libs_dir")
    if libs_dir:
        return Path(libs_dir).expanduser()

    return None


def pwn_scripts_reload_glibc_debug():
    libs_root = _get_libs_root()

    debug_dirs = []
    thread_db_dirs = []

    if libs_root and libs_root.is_dir():
        for glibc_dir in sorted(libs_root.iterdir()):
            if not glibc_dir.is_dir():
                continue

            for candidate in (glibc_dir / ".debug" / "debug", glibc_dir / ".debug"):
                if _existing_dir(candidate / ".build-id"):
                    _add_unique(debug_dirs, candidate)

            for candidate in (glibc_dir / "x86_64-linux-gnu", glibc_dir / "i386-linux-gnu", glibc_dir):
                if _existing_dir(candidate) and any(candidate.glob("libthread_db*.so*")):
                    _add_unique(thread_db_dirs, candidate)

    current_debug_dirs = _split_path(gdb.parameter("debug-file-directory"))
    for path in current_debug_dirs:
        _add_unique(debug_dirs, path)

    if debug_dirs:
        gdb.execute("set debug-file-directory " + os.pathsep.join(debug_dirs), to_string=True)

    if thread_db_dirs:
        gdb.execute("set libthread-db-search-path " + os.pathsep.join(thread_db_dirs), to_string=True)

    if os.environ.get("PWN_GLIBC_DEBUG_VERBOSE") == "1":
        if libs_root:
            gdb.write(f"[pwn-scripts] loaded {len(debug_dirs)} glibc debug dirs from {libs_root}\n")
        else:
            gdb.write("[pwn-scripts] glibc_libs_dir is not configured\n")


class PwnGlibcDebugReload(gdb.Command):
    def __init__(self):
        super().__init__("pwn-glibc-debug-reload", gdb.COMMAND_SUPPORT)

    def invoke(self, arg, from_tty):
        pwn_scripts_reload_glibc_debug()
        gdb.write("[pwn-scripts] glibc debug paths reloaded\n")


PwnGlibcDebugReload()
pwn_scripts_reload_glibc_debug()

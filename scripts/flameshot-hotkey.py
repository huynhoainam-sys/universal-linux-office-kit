#!/usr/bin/env python3
"""Repair GNOME Flameshot hotkey without silently stealing other apps' shortcuts.

Only duplicates which launch Flameshot and built-in screenshot bindings are
unbound. Any other user's Ctrl+Alt+S shortcut is treated as a blocker.
Changes are backed up and rolled back if the GNOME write fails.
"""
import argparse
import ast
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys

BASE = "org.gnome.settings-daemon.plugins.media-keys"
CUSTOM = BASE + ".custom-keybinding"
MANAGED = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/namhh-flameshot/"
LEGACY = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/"
ACCEL = "<Primary><Alt>s"
SCHEMAS = (
    "org.gnome.shell.keybindings",
    BASE,
    "org.gnome.desktop.wm.keybindings",
)


def gs(*args):
    process = subprocess.run(["gsettings", *args], capture_output=True, text=True)
    if process.returncode:
        raise RuntimeError(f"gsettings {' '.join(args)}: {process.stderr.strip()}")
    return process.stdout.strip()


def read_value(schema, key):
    return gs("get", schema, key)


def set_value(schema, key, value):
    gs("set", schema, key, value)


def parse_gvariant(text, fallback=None):
    try:
        if text.startswith("@as "):
            text = text[4:]
        return ast.literal_eval(text)
    except (ValueError, SyntaxError):
        return fallback


def chord(text):
    """Normalize Ctrl/Primary and modifier ordering for collision checks."""
    if not isinstance(text, str):
        return None
    tags = re.findall(r"<([^>]+)>", text)
    key = re.sub(r"<[^>]+>", "", text).strip().lower()
    modifiers = set()
    for tag in tags:
        m = tag.lower()
        modifiers.add({"ctrl": "ctrl", "control": "ctrl", "primary": "ctrl",
                       "mod1": "alt"}.get(m, m))
    return tuple(sorted(modifiers)), key


def bindings(value):
    parsed = parse_gvariant(value, value)
    if isinstance(parsed, str):
        return [parsed]
    if isinstance(parsed, (tuple, list)):
        return [v for v in parsed if isinstance(v, str)]
    return []


def owned(command):
    cmd = command.lower()
    return "flameshot" in cmd


def custom_schema(path):
    return f"{CUSTOM}:{path}"


def read_custom(path):
    schema = custom_schema(path)
    return {field: read_value(schema, field) for field in ("name", "command", "binding")}


def builtin_conflicts():
    conflicts = []
    for schema in SCHEMAS:
        try:
            listing = gs("list-recursively", schema)
        except RuntimeError:
            continue
        for line in listing.splitlines():
            fields = line.split(maxsplit=2)
            if len(fields) != 3:
                continue
            _, key, value = fields
            if any(chord(v) == chord(ACCEL) for v in bindings(value)):
                conflicts.append((schema, key, value))
    return conflicts


def apply(launcher, state_dir):
    if not Path(launcher).is_file():
        raise RuntimeError(f"Không có launcher Flameshot: {launcher}")
    raw = read_value(BASE, "custom-keybindings")
    paths = parse_gvariant(raw)
    if not isinstance(paths, list) or not all(isinstance(p, str) for p in paths):
        raise RuntimeError("Không phân tích được danh sách shortcut GNOME; giữ nguyên.")
    entries = {p: read_custom(p) for p in paths}
    if MANAGED in entries and not owned(str(parse_gvariant(entries[MANAGED]["command"], ""))):
        raise RuntimeError("Shortcut namhh-flameshot thuộc ứng dụng khác; không ghi đè.")
    target = LEGACY if LEGACY in entries and owned(str(parse_gvariant(entries[LEGACY]["command"], ""))) else MANAGED
    if target in entries and not owned(str(parse_gvariant(entries[target]["command"], ""))):
        raise RuntimeError("Shortcut mục tiêu thuộc ứng dụng khác; không ghi đè.")
    duplicates = []
    collisions = []
    for p, entry in entries.items():
        if p == target:
            continue
        if any(chord(v) == chord(ACCEL) for v in bindings(entry["binding"])):
            if owned(str(parse_gvariant(entry["command"], ""))):
                duplicates.append(p)
            else:
                collisions.append(p)
        # Remove stale Office Kit-owned Ctrl+Shift+S / Alt+S bindings too
        elif owned(str(parse_gvariant(entry["command"], ""))) and p in (LEGACY, MANAGED):
            duplicates.append(p)
    if collisions:
        raise RuntimeError("Ctrl+Alt+S đang thuộc shortcut cá nhân: " + ", ".join(collisions)
                           + ". Giữ nguyên shortcut đó, vui lòng đổi phím trong Settings > Keyboard.")
    builtins = builtin_conflicts()
    protected = [(sch, key) for sch, key, _ in builtins
                 if not re.search(r"screenshot|screen-shot|screencast", key, re.I)]
    if protected:
        raise RuntimeError("Ctrl+Alt+S trùng phím hệ thống ngoài chụp ảnh: "
                           + ", ".join(f"{s}/{k}" for s, k in protected)
                           + ". Không vô hiệu hóa phím hệ thống khác.")
    changes = []
    backup = {
        "created": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "shortcut": ACCEL, "target": target, "previous_list": raw,
        "previous_custom": entries, "builtin_collisions": builtins,
    }
    state_dir = Path(state_dir)
    state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    target_file = state_dir / ("flameshot-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f") + ".json")
    fd = os.open(target_file, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(backup, stream, indent=2, ensure_ascii=False)

    def change(schema, key, val):
        old = read_value(schema, key)
        if old == val or parse_gvariant(old) == parse_gvariant(val):
            return
        set_value(schema, key, val)
        changes.append((schema, key, old))
    try:
        for path in sorted(set(duplicates)):
            change(custom_schema(path), "binding", "''")
        for schema, key, _ in builtins:
            change(schema, key, "[]")
        if target not in entries:
            change(BASE, "custom-keybindings", repr(paths + [target]))
        change(custom_schema(target), "name", "'Flameshot'")
        change(custom_schema(target), "command", repr(str(Path(launcher))))
        change(custom_schema(target), "binding", repr(ACCEL))
        if chord(str(parse_gvariant(read_value(custom_schema(target), "binding"), ""))) != chord(ACCEL):
            raise RuntimeError("GNOME không lưu được shortcut mong muốn")
    except Exception:
        for schema, key, old in reversed(changes):
            try:
                set_value(schema, key, old)
            except RuntimeError:
                pass
        raise
    print("PASS: Ctrl+Alt+S → Flameshot; đã xử lý %d shortcut trùng do Flameshot quản lý, %d phím chụp ảnh hệ thống." %
          (len(set(duplicates)), len(builtins)))
    print("Backup:", target_file)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", required=True)
    parser.add_argument("--state-dir", default=str(Path.home() / ".local/state/ulok/backups"))
    args = parser.parse_args()
    try:
        apply(args.launcher, args.state_dir)
    except (RuntimeError, OSError) as exc:
        print("WARN:", exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

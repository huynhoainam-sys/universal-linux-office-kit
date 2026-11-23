#!/usr/bin/env python3
"""Mock GNOME GSettings: duplicate/legacy/builtin/conflict/rollback scenarios."""
import importlib.util
from pathlib import Path
import tempfile
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/flameshot-hotkey.py"
spec = importlib.util.spec_from_file_location("hotkey", SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

OLD = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/"
OTHER = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/personal/"
OWN = mod.MANAGED


def test_scenarios():
    with tempfile.TemporaryDirectory() as tmp:
        launcher = Path(tmp) / "ulok-flameshot"
        launcher.write_text("#!/usr/bin/env bash\nexec flameshot gui\n")
        backup = Path(tmp) / "backups"
        data = {
            (mod.BASE, "custom-keybindings"): repr([OLD, OTHER]),
            (mod.custom_schema(OLD), "name"): "'Flameshot'",
            (mod.custom_schema(OLD), "command"): repr(str(launcher)),
            (mod.custom_schema(OLD), "binding"): "'<Primary><Shift>s'",
            (mod.custom_schema(OTHER), "name"): "'Personal'",
            (mod.custom_schema(OTHER), "command"): "'terminal'",
            (mod.custom_schema(OTHER), "binding"): "'<Primary><Alt>t'",
            (mod.custom_schema(OWN), "name"): "''",
            (mod.custom_schema(OWN), "command"): "''",
            (mod.custom_schema(OWN), "binding"): "''",
            ("org.gnome.shell.keybindings", "show-screenshot-ui"): "['<Ctrl><Alt>s']",
        }

        def read(schema, key):
            return data.get((schema, key), "''")

        def write(schema, key, value):
            data[(schema, key)] = value

        def builtin():
            v = data[("org.gnome.shell.keybindings", "show-screenshot-ui")]
            return [("org.gnome.shell.keybindings", "show-screenshot-ui", v)] if any(
                mod.chord(b) == mod.chord(mod.ACCEL) for b in mod.bindings(v)) else []

        with patch.object(mod, "read_value", side_effect=read), \
             patch.object(mod, "set_value", side_effect=write), \
             patch.object(mod, "builtin_conflicts", side_effect=builtin):
            mod.apply(str(launcher), backup)
            assert mod.parse_gvariant(data[(mod.custom_schema(OLD), "binding")]) == mod.ACCEL
            assert data[("org.gnome.shell.keybindings", "show-screenshot-ui")] == "[]"
            assert data[(mod.custom_schema(OTHER), "binding")] == "'<Primary><Alt>t'"
            assert len(list(backup.glob("flameshot-*.json"))) == 1
            # Repeat is idempotent.
            mod.apply(str(launcher), backup)
            assert mod.parse_gvariant(data[(mod.custom_schema(OLD), "binding")]) == mod.ACCEL
            # Duplicate independent Flameshot hotkey should be disabled.
            data[(mod.BASE, "custom-keybindings")] = repr([OLD, OTHER, OWN])
            data[(mod.custom_schema(OWN), "command")] = "'flameshot gui'"
            data[(mod.custom_schema(OWN), "binding")] = "'<Ctrl><Alt>s'"
            mod.apply(str(launcher), backup)
            assert data[(mod.custom_schema(OWN), "binding")] == "''"
            # An unrelated personal shortcut must never be stolen.
            data[(mod.custom_schema(OTHER), "binding")] = "'<Ctrl><Alt>s'"
            try:
                mod.apply(str(launcher), backup)
                raise AssertionError("expected protected personal shortcut collision")
            except RuntimeError as exc:
                assert "shortcut cá nhân" in str(exc)
            assert data[(mod.custom_schema(OTHER), "binding")] == "'<Ctrl><Alt>s'"
            # A non-screenshot GNOME binding must not be disabled.
            with patch.object(mod, "builtin_conflicts",
                              return_value=[("org.gnome.desktop.wm.keybindings", "activate-window-menu",
                                             "['<Ctrl><Alt>s']")]):
                data[(mod.custom_schema(OTHER), "binding")] = "'<Primary><Alt>t'"
                try:
                    mod.apply(str(launcher), backup)
                    raise AssertionError("expected system collision")
                except RuntimeError as exc:
                    assert "phím hệ thống" in str(exc)


if __name__ == "__main__":
    test_scenarios()
    print("PASS: Flameshot Alt+S, legacy shortcut, duplicate cleanup, personal & system collision guards")

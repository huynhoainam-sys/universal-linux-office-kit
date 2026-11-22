#!/usr/bin/env python3
"""Render the offline newcomer guide and verify safety of embedded diagnostic text."""

import subprocess
import sys
import tempfile
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent.parent


class HtmlReportTests(unittest.TestCase):
    def test_guide_contains_office_unikey_logout_zalo_and_safe_text(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / "setup-report.txt"
            output = Path(temporary) / "setup-report.html"
            report.write_text(
                "Universal Linux Office Kit report\n"
                "Warnings: 1\n - <script>alert('unsafe')</script>\n"
                "Failures: 0\n", encoding="utf-8",
            )
            proc = subprocess.run([
                sys.executable, str(ROOT / "report-html.py"),
                "--report", str(report), "--output", str(output),
                "--backup", str(Path(temporary) / "backups"),
            ], capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            content = output.read_text(encoding="utf-8")
            for phrase in (
                "<!doctype html>", "lang=\"vi\"", "WPS Office", "GenOffice",
                "Flameshot", "Ctrl", "Log Out", "Restart", "Zalo",
                "Quick Settings", "Log Out…", "Restart…", "Add Input Source",
                "Output charset:", "Scan QR Code", "Telex", "VNI",
                "tie6ng1 vie6t5", "Windows", "huynhoainam@gmail.com",
            ):
                self.assertIn(phrase, content)
            self.assertIn("&lt;script&gt;alert", content)
            self.assertNotIn("<script>alert('unsafe')</script>", content)
            self.assertIn('<symbol id="i-power"', content)
            self.assertIn('<use href="#i-power"', content)
            self.assertIn('<use href="#i-wifi"', content)
            self.assertIn('<use href="#i-logout"', content)
            self.assertIn('<use href="#i-restart"', content)
            self.assertIn('href="mailto:huynhoainam@gmail.com"', content)
            self.assertIn('color-scheme: dark', content)
            self.assertIn('--bg:#061021', content)
            self.assertIn('class="brand-mark"', content)
            self.assertIn('OFFLINE READY', content)
            self.assertIn('id="unikey"', content)
            self.assertIn('Hướng dẫn Unikey', content)
            self.assertIn('id="method-telex"', content)
            self.assertIn('id="method-vni"', content)
            self.assertIn('class="click-guide"', content)
            self.assertEqual(content.count('<details class="click-step"'), 4)
            self.assertIn('for="sim-add-unikey"', content)
            self.assertIn('name="sim-active-input"', content)
            self.assertIn('<symbol id="i-gear"', content)
            self.assertNotIn('href="#vni"', content)
            self.assertNotIn('<script', content)
            self.assertNotIn('<script', content)
            self.assertNotIn('src="https://', content)
            self.assertLess(len(content.encode("utf-8")), 90_000)

    def test_dry_run_is_never_reported_as_a_successful_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / "dry.txt"
            output = Path(temporary) / "dry.html"
            report.write_text("Dry-run: 1\nWarnings: 0\nFailures: 0\n", encoding="utf-8")
            proc = subprocess.run([
                sys.executable, str(ROOT / "report-html.py"),
                "--report", str(report), "--output", str(output),
            ], capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            content = output.read_text(encoding="utf-8")
            self.assertIn("mô phỏng (dry-run)", content)
            self.assertIn("không cài ứng dụng và không đăng nhập Zalo", content)
            self.assertNotIn("Đã hoàn tất cài đặt", content)


if __name__ == "__main__":
    unittest.main()

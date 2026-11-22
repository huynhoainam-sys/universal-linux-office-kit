#!/usr/bin/env python3
"""Render the offline newcomer guide and verify safety of embedded diagnostic text."""

import subprocess
import sys
import tempfile
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent.parent


class HtmlReportTests(unittest.TestCase):
    def test_guide_contains_office_vni_logout_zalo_and_safe_text(self):
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
                "VNI", "tie6ng1 vie6t5", "Windows", "huynhoainam@gmail.com",
            ):
                self.assertIn(phrase, content)
            self.assertIn("&lt;script&gt;alert", content)
            self.assertNotIn("<script>alert('unsafe')</script>", content)


if __name__ == "__main__":
    unittest.main()

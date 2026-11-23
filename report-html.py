#!/usr/bin/env python3
"""Friendly, offline HTML handoff for someone moving from Windows to Ubuntu."""

import argparse
from datetime import datetime
from html import escape
import os
from pathlib import Path
import platform
import shutil
import subprocess
from string import Template


# name, everyday purpose, binaries, Debian packages
APP_GROUPS = (
    ("Văn phòng và tài liệu", (
        ("WPS Office", "Soạn Word, bảng tính Excel, trình chiếu PowerPoint và mở PDF.", ("wps",), ("wps-office",)),
        ("LibreOffice", "Bộ Writer, Calc, Impress miễn phí; dùng như Word, Excel, PowerPoint.", ("libreoffice",), ("libreoffice-common", "libreoffice")),
        ("GenOffice", "Bộ văn phòng có tính năng AI, chỉ cài thêm nếu bạn chọn.", ("genoffice",), ("genoffice",)),
        ("Trình đọc PDF", "Mở tài liệu PDF để xem hoặc in.", ("evince", "papers"), ("evince", "papers")),
        ("PDF Arranger", "Ghép, tách hoặc sắp xếp lại trang PDF.", ("pdfarranger",), ("pdfarranger",)),
        ("Máy in CUPS", "Kết nối và quản lý máy in.", ("lpstat",), ("cups",)),
    )),
    ("Tiếng Việt và chụp màn hình", (
        ("Unikey tiếng Việt", "Gõ tiếng Việt và tự chọn kiểu gõ phù hợp.", ("ibus-daemon", "fcitx5"), ("ibus-unikey", "fcitx5-unikey")),
        ("Flameshot", "Chụp vùng màn hình bằng Ctrl + Alt + S.", ("flameshot",), ("flameshot",)),
        ("Font văn phòng", "Hiển thị chữ tiếng Việt và tài liệu Word đúng hơn.", (), ("fonts-crosextra-carlito", "fonts-liberation2")),
    )),
    ("Liên lạc và Internet", (
        ("Zalo Linux", "Nhắn tin và trao đổi công việc bằng tài khoản Zalo.", ("zalo-linux",), ()),
        ("Outlook Microsoft 365 (Web)", "Mở Outlook của công ty qua Edge/Chrome hoặc Firefox; đăng nhập trong trình duyệt.", ("ulok-outlook-web",), ()),
        ("Google Chrome", "Duyệt web, Gmail, Google Drive và họp trực tuyến.", ("google-chrome", "google-chrome-stable"), ("google-chrome-stable",)),
        ("Microsoft Edge", "Duyệt web và dùng Microsoft 365 trên trình duyệt.", ("microsoft-edge", "microsoft-edge-stable"), ("microsoft-edge-stable",)),
        ("Firefox", "Trình duyệt web có sẵn trên nhiều máy Ubuntu.", ("firefox",), ("firefox",)),
        ("Thunderbird", "Ứng dụng email độc lập hỗ trợ nhiều loại tài khoản.", ("thunderbird",), ("thunderbird",)),
        ("Zoom", "Họp video và chia sẻ màn hình.", ("zoom",), ("zoom",)),
    )),
    ("Hình ảnh, dữ liệu và công cụ", (
        ("Simple Scan", "Quét tài liệu bằng máy scan.", ("simple-scan",), ("simple-scan",)),
        ("VLC", "Xem video và nghe nhạc.", ("vlc",), ("vlc",)),
        ("GIMP", "Chỉnh sửa ảnh.", ("gimp",), ("gimp",)),
        ("Remmina", "Điều khiển máy tính khác qua Remote Desktop (RDP/VNC).", ("remmina",), ("remmina",)),
        ("VS Code", "Chỉnh sửa mã nguồn và làm việc kỹ thuật.", ("code",), ("code",)),
        ("Docker", "Chạy môi trường ứng dụng riêng cho người làm kỹ thuật.", ("docker",), ("docker-ce", "docker.io")),
    )),
    ("Tiện ích Windows → Ubuntu", (
        ("Sao lưu Backups", "Mở Backups để chọn nơi lưu bản sao tài liệu; chưa tự sao lưu nếu bạn chưa thiết lập.", ("deja-dup",), ("deja-dup",)),
        ("Archive Manager", "Mở và giải nén tệp ZIP, 7z và các định dạng được hỗ trợ.", ("file-roller",), ("file-roller",)),
        ("Xem nhanh tệp", "Trong Files, chọn tệp và nhấn Space để xem nhanh nếu được hỗ trợ.", ("gnome-sushi",), ("gnome-sushi",)),
        ("Disk Usage Analyzer", "Xem thư mục nào đang chiếm nhiều dung lượng.", ("baobab",), ("baobab",)),
        ("Disks", "Kiểm tra ổ cứng/USB; không tự định dạng hoặc thay đổi phân vùng.", ("gnome-disks",), ("gnome-disk-utility",)),
        ("Ổ NTFS và exFAT", "Hỗ trợ ổ đĩa di động từ Windows.", ("ntfs-3g",), ("ntfs-3g", "exfatprogs")),
        ("Chia sẻ Windows / NAS", "Trong Files → Other Locations, kết nối smb://máy-chủ/thư-mục.", ("gio",), ("gvfs-backends",)),
    )),
)


def pkg_installed(package):
    if not shutil.which("dpkg-query"):
        return False
    try:
        answer = subprocess.run(
            ["dpkg-query", "-W", "-f=${Status}", package],
            capture_output=True, text=True, timeout=3, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return answer.returncode == 0 and answer.stdout.strip() == "install ok installed"


def app_installed(name, binaries, packages):
    if name == "Zalo Linux":
        bindir = Path(os.environ.get("XDG_BIN_HOME", str(Path.home() / ".local/bin")))
        appdir = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "zalo-linux"
        return (bindir / "zalo-linux").is_file() and (appdir / "Zalo-x86_64.AppImage").is_file()
    if name == "Outlook Microsoft 365 (Web)":
        bindir = Path(os.environ.get("XDG_BIN_HOME", str(Path.home() / ".local/bin")))
        desktop = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "applications"
        return (bindir / "ulok-outlook-web").is_file() and (desktop / "namhh-outlook-web.desktop").is_file()
    if name == "Unikey tiếng Việt":
        return pkg_installed("ibus-unikey") or pkg_installed("fcitx5-unikey")
    if name in ("Ổ NTFS và exFAT", "Chia sẻ Windows / NAS"):
        return all(pkg_installed(p) for p in packages)
    return any(shutil.which(program) for program in binaries) or any(pkg_installed(p) for p in packages)


def report_diagnostics(report_text):
    warnings, failures = [], []
    section = None
    for line in report_text.splitlines():
        if line.startswith("Warnings:"):
            section = warnings
        elif line.startswith("Failures:"):
            section = failures
        elif line.startswith(" - ") and section is not None:
            section.append(line[3:])
    return warnings, failures


def cards_html():
    chunks, ready, total = [], 0, 0
    office = {}
    for group, apps in APP_GROUPS:
        rows = []
        for name, purpose, binaries, packages in apps:
            installed = app_installed(name, binaries, packages)
            total += 1
            ready += int(installed)
            if name in ("WPS Office", "LibreOffice", "GenOffice"):
                office[name] = installed
            cls = "ready" if installed else "optional"
            status = "Đã cài" if installed else "Chưa cài"
            symbol = "i-check" if installed else "i-minus"
            rows.append(
                f'<tr><td><strong>{escape(name)}</strong><small>{escape(purpose)}</small></td>'
                f'<td class="status-cell"><span class="pill {cls}"><svg class="icon icon-xs" aria-hidden="true"><use href="#{symbol}"/></svg>{status}</span></td></tr>'
            )
        chunks.append(f'<section class="app-group"><h3>{escape(group)}</h3>'
                      f'<table><tbody>{"".join(rows)}</tbody></table></section>')
    return "\n".join(chunks), ready, total, sum(office.values())


def render(report, output, backup=""):
    report_path = Path(report)
    text = report_path.read_text(encoding="utf-8", errors="replace")
    warnings, failures = report_diagnostics(text)
    tables, ready, total, office_count = cards_html()
    dry_run = any(line.strip() == "Dry-run: 1" for line in text.splitlines())
    os_name = platform.system()
    try:
        os_name = platform.freedesktop_os_release().get("PRETTY_NAME", os_name)
    except (AttributeError, OSError):
        pass
    if dry_run:
        page_title = "Bản xem trước Ubuntu Setup"
        status_title = "Đã chạy thử bản mô phỏng (dry-run)"
        status_note = "Chưa cài thêm phần mềm hoặc thay đổi cấu hình. Danh sách bên dưới là tình trạng thực tế của máy chạy thử."
    elif failures:
        page_title = "Thiết lập cần kiểm tra"
        status_title = "Có ứng dụng cần kiểm tra thêm"
        status_note = "Phần lớn thao tác vẫn dùng được. Có mục chưa hoàn tất; xem chi tiết cuối báo cáo."
    else:
        page_title = "Ubuntu đã sẵn sàng"
        status_title = "Đã hoàn tất cài đặt"
        status_note = "Bạn có thể bắt đầu làm việc. Hãy đăng xuất rồi đăng nhập lại để bộ gõ hoạt động ổn định."
    alert = (
        '<div class="alert">Có ' + str(len(failures)) +
        ' mục chưa hoàn tất. Các ứng dụng đã cài trước đó vẫn được giữ nguyên.</div>'
        if failures else
        '<div class="notice">Đã giữ nguyên ứng dụng và dữ liệu cá nhân hiện có.</div>'
    )
    if dry_run:
        alert = '<div class="notice">Bản chạy thử: không cài ứng dụng và không đăng nhập Zalo.</div>'
    technical = "".join(f"<li>{escape(item)}</li>" for item in warnings + failures)
    if not technical:
        technical = "<li>Không ghi nhận cảnh báo từ bộ cài.</li>"
    html = Template(HTML_TEMPLATE).substitute(
        PAGE_TITLE=escape(page_title),
        STATUS_TITLE=escape(status_title),
        STATUS_NOTE=escape(status_note),
        OS_NAME=escape(os_name),
        GENERATED=escape(datetime.now().strftime("%d/%m/%Y lúc %H:%M")),
        READY=str(ready), TOTAL=str(total), OFFICE_COUNT=str(office_count),
        ALERT=alert, APP_TABLES=tables,
        DETAILS=technical,
        LOG_PATH=escape(str(report_path)),
        BACKUP_PATH=escape(backup if backup else "Không tạo bản sao cấu hình trong lượt này"),
    )
    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(html, encoding="utf-8")
    return output_path


HTML_TEMPLATE = r'''<!doctype html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>NAMHH | Hướng dẫn làm quen Ubuntu & báo cáo cài đặt</title>
  <style>
    :root { color-scheme: dark; --bg:#061021; --surface:#0c1b32; --surface-hi:#112641;
      --line:#284467; --ink:#eaf3ff; --muted:#a6bed7; --blue:#6fb7ff;
      --cyan:#50d9f0; --purple:#bd9cfc; --green:#7ce6ba; --amber:#f0c67c;
      --dark:#071326; --soft:#102641; }
    * { box-sizing:border-box; }
    .icon-sprite { position:absolute;width:0;height:0;overflow:hidden; }
    .icon { width:18px;height:18px;stroke:currentColor;fill:none;stroke-width:2;
      stroke-linecap:round;stroke-linejoin:round;vertical-align:middle;flex:none; }
    .icon-xs {width:13px;height:13px;stroke-width:2.3;}
    .icon-lg {width:23px;height:23px;}
    html { scroll-behavior:smooth; scroll-padding-top:90px; }
    body { margin:0;color:var(--ink);background:radial-gradient(ellipse 650px 350px at 94% 0%,#17315d64,transparent),
      radial-gradient(ellipse 660px 430px at 0% 45%,#142a5360,transparent),var(--bg);
      font-family:Inter,system-ui,-apple-system,"Segoe UI",Arial,sans-serif;line-height:1.6; }
    body::before {content:"";position:fixed;inset:0;pointer-events:none;opacity:.08;
      background-image:linear-gradient(#7ba9e4 1px,transparent 1px),linear-gradient(90deg,#7ba9e4 1px,transparent 1px);
      background-size:48px 48px;mask-image:linear-gradient(180deg,#000,transparent 85%);}
    .wrap {width:min(1180px,calc(100% - 38px));margin:auto;}
    .hero {position:relative;overflow:hidden;background:linear-gradient(115deg,#061124 0%,#0b1c39 66%,#152b53 100%);
      padding:32px 0 47px;border-bottom:1px solid #3778b852;}
    .hero::before {content:"";position:absolute;inset:0;pointer-events:none;opacity:.24;
      background-image:linear-gradient(#428fc52e 1px,transparent 1px),linear-gradient(90deg,#428fc52e 1px,transparent 1px);
      background-size:44px 44px;}
    .hero::after {content:"";position:absolute;width:470px;height:470px;border:1px solid #3b9cce30;
      border-radius:50%;right:-100px;top:-280px;box-shadow:0 0 0 80px #4777e009,0 0 0 160px #7a65e806;
      pointer-events:none;}
    .hero .wrap {position:relative;z-index:1;}
    .brandbar {display:flex;align-items:center;justify-content:space-between;gap:20px;margin-bottom:26px;}
    .brand-ident {display:flex;align-items:center;gap:13px;}
    .brand-mark {display:grid;place-items:center;width:47px;height:47px;border-radius:12px;
      border:1px solid #4bcbeabb;background:linear-gradient(145deg,#0b365a,#0c1839);
      box-shadow:inset 0 0 14px #38c9f02b,0 0 17px #37bceb2c;color:#66e7fa;
      font:900 29px/1 system-ui,sans-serif;letter-spacing:-.09em;}
    .brand {font-size:19px;font-weight:850;letter-spacing:.12em;color:#f1f8ff;line-height:1.3;}
    .brand-sub {display:block;font-size:10px;font-weight:750;letter-spacing:.12em;color:#8fb6dd;}
    .live-badge {display:inline-flex;align-items:center;gap:8px;color:#b9e3f6;background:#102b45;
      border:1px solid #307b9a70;padding:7px 12px;border-radius:99px;font-size:11px;font-weight:750;}
    .live-badge::before {content:"";width:7px;height:7px;border-radius:50%;background:#70e5ba;
      box-shadow:0 0 9px #65dab67a;}
    .eyebrow {display:inline-block;margin:0 0 3px;padding:5px 11px;border:1px solid #3084af75;
      border-radius:7px;color:#85daf4;background:#0a395342;font-size:11px;font-weight:800;letter-spacing:.095em;}
    h1 {margin:13px 0 11px;font-size:clamp(30px,4vw,43px);line-height:1.2;letter-spacing:-.03em;
      text-wrap:balance;max-width:860px;}
    .hero p {color:#c9d8ed;max-width:870px;margin:8px 0 0;font-size:14px;}
    .hero p strong {color:#fff;}
    .meta {display:flex;align-items:center;flex-wrap:wrap;gap:10px 24px;font-size:12px;
      margin-top:24px;color:#aac7df;}
    .hero a {color:#91e3f5;text-underline-offset:3px;}
    .meta .contact {display:inline-flex;align-items:center;gap:7px;}
    .nav-shell {position:sticky;top:0;z-index:10;background:#07162aef;
      backdrop-filter:blur(11px);border-bottom:1px solid #254365;box-shadow:0 9px 24px #02091385;}
    .nav {display:flex;align-items:center;gap:7px;overflow-x:auto;padding:10px 0;}
    .nav a {display:inline-flex;align-items:center;gap:7px;color:#b7cce3;text-decoration:none;
      font-weight:700;font-size:12px;white-space:nowrap;min-height:44px;
      border:1px solid transparent;border-radius:9px;padding:10px 12px;}
    .nav a:hover,.nav a:focus-visible {background:#102a4a;border-color:#3c83b0;outline:2px solid transparent;color:#dffaff;}
    .nav a:first-of-type {background:#0f3854;border-color:#327c9d;color:#93edfc;box-shadow:inset 0 0 10px #3cc9ef14;}
    .nav .nav-brand {margin-right:auto;color:#e8f8ff;letter-spacing:.1em;font-size:11px;font-weight:900;}
    .summary {display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px;margin:25px 0;}
    .stat,.panel {background:linear-gradient(148deg,#10233de3,#0a182eea);border:1px solid var(--line);
      border-radius:15px;box-shadow:inset 0 1px 0 #a8d8ff0e,0 12px 29px #0008163f;}
    .stat {position:relative;overflow:hidden;padding:23px 23px 21px;border-top:2px solid #4db9e2;}
    .stat::after {content:"";position:absolute;left:36%;right:36%;top:0;height:2px;
      background:#72e4f6;box-shadow:0 0 13px 3px #28c8e871;}
    .stat:nth-child(2) {border-top-color:#946bd5;}
    .stat:nth-child(2)::after {background:#c69cff;box-shadow:0 0 13px 3px #b675fa5a;}
    .stat:nth-child(3) {border-top-color:#278eaa;}
    .stat strong {display:block;color:var(--cyan);font-size:32px;letter-spacing:-.04em;line-height:1.25;}
    .stat:nth-child(2) strong {color:#d0a8ff;}
    .stat:nth-child(3) strong {color:#9bd5ff;}
    .stat span {color:#bdd0e6;font-size:12px;}
    .panel {position:relative;padding:29px 30px;margin:19px 0;overflow:hidden;}
    .panel::before {content:"";position:absolute;top:0;left:23px;width:82px;height:1px;
      background:#5bdaf1;box-shadow:0 0 12px 2px #41cbe94d;}
    .panel:nth-of-type(2n)::before {background:#a58ff0;box-shadow:0 0 12px 2px #896fd64a;}
    .section-label {font-size:11px;letter-spacing:.13em;text-transform:uppercase;color:#6ed1f2;
      font-weight:850;margin-bottom:7px;display:block;}
    h2 {font-size:23px;margin:0 0 11px;letter-spacing:-.02em;}
    h3 {font-size:16px;margin:0 0 10px;}
    p {margin:8px 0 13px;} .sub {color:var(--muted);font-size:14px;}
    a {color:#7bd9f4;} a:focus-visible {outline:3px solid #9ee6ff;outline-offset:3px;}
    .notice,.alert {padding:13px 16px;border-radius:10px;background:#10392f;
      border:1px solid #327b70;border-left:4px solid #66ddaf;color:#c3f3df;margin:18px 0;}
    .alert {background:#362b22;border-color:#986e39;border-left-color:#ecc579;color:#ffdea5;}
    .steps {display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:15px;}
    .step {background:#0b203a;border:1px solid #284363;border-radius:13px;padding:19px;min-width:0;}
    .step .number {background:#103958;color:#9ae9f7;display:inline-flex;align-items:center;
      justify-content:center;width:31px;height:31px;border:1px solid #306b89;border-radius:9px;font-weight:850;}
    .step strong {display:block;margin:12px 0 6px;font-size:15px;}
    .step p {font-size:13px;color:var(--muted);margin:0;}
    .mock {margin-top:16px;border:1px solid #355375;border-radius:10px;overflow:hidden;
      background:#07172c;min-height:153px;font-size:12px;box-shadow:0 4px 13px #02091860;}
    .mockbar {background:#18243a;color:#e3f0ff;display:flex;align-items:center;
      justify-content:space-between;padding:10px 11px;border-bottom:1px solid #304764;}
    .focus {color:#eafcff;background:#144d6d;border:1px solid #3bc3de;border-radius:6px;
      padding:4px 7px;display:inline-flex;align-items:center;gap:8px;box-shadow:0 0 13px #3ab6d523;}
    .focus .icon {width:15px;height:15px;}
    .mockmenu {margin:9px 10px 9px auto;background:#13253b;border:1px solid #45607c;
      box-shadow:0 6px 16px #020c1d82;border-radius:9px;width:87%;padding:9px;color:#e5f1fe;}
    .mockline {padding:8px 10px;border-radius:6px;display:flex;align-items:center;gap:9px;}
    .mockline.selected {background:#164d72;color:#a7edfc;font-weight:850;outline:1px solid #4e9bc1;}
    .mockline .icon {width:16px;height:16px;}
    .mockfooter {display:flex;align-items:center;justify-content:space-between;border-top:1px solid #33506c;
      margin-top:6px;padding:10px 6px 2px;color:#bdd1e2;}
    .power-button {display:inline-flex;align-items:center;gap:8px;background:#17516a;color:#c9faff;
      border:2px solid #4dc5dd;border-radius:8px;padding:8px 12px;font-weight:850;}
    .mocknote {padding:24px 14px 10px;text-align:right;color:#92cae4;font-weight:700;font-size:11px;}
    .key {display:inline-block;border:1px solid #3e6685;background:#15324e;box-shadow:0 2px 0 #071b2c;
      border-radius:5px;padding:1px 7px;white-space:nowrap;color:#d4f4ff;font-weight:700;}
    .tip {margin-top:17px;background:#112b43;border:1px solid #284d72;border-left:3px solid #54c8e3;
      border-radius:9px;padding:15px 17px;font-size:14px;color:#d4eafc;}
    .guide-list {margin:13px 0 0;padding-left:23px;}
    .guide-list li {padding-left:7px;margin:11px 0;}
    .guide-list li::marker {color:#72dcf2;font-weight:850;}
    .guide-shot {background:#0d233d;border:1px solid #2e5072;border-radius:13px;padding:17px;margin:17px 0;}
    .guide-shot .caption {color:#a9c4da;font-size:12px;margin-top:9px;}
    .mini-flow {display:grid;grid-template-columns:1fr 1fr;gap:13px;margin-top:12px;}
    .mini-card {background:#102540;border:1px solid #365474;border-radius:11px;padding:15px;}
    .mini-card b {display:flex;align-items:center;gap:8px;margin-bottom:7px;}
    .mini-card p {font-size:12px;color:var(--muted);}
    .mini-card.bad {border-color:#806044;background:#2c281f;}
    .mini-card.good {border-color:#356a6d;background:#102f38;}
    .mini-card.good b {color:#9be9d5;} .mini-card.bad b {color:#f3c895;}
    .keymap {display:flex;flex-wrap:wrap;gap:7px;margin:13px 0;}
    .keymap span {background:#153450;border:1px solid #315a77;padding:5px 8px;border-radius:7px;
      font-size:12px;color:#cee7ff;}
    .click-guide {display:grid;gap:10px;margin-top:20px;}
    .click-step {margin:0;background:#0b203a;border:1px solid #315474;border-radius:12px;overflow:hidden;padding:0;}
    .click-step[open] {border-color:#4481a0;box-shadow:0 0 20px #29b4df11;}
    .click-step > summary {display:flex;align-items:center;gap:12px;list-style:none;min-height:54px;
      color:#e8f6ff;padding:11px 16px;cursor:pointer;}
    .click-step > summary::-webkit-details-marker {display:none;}
    .click-step > summary:hover,.click-step > summary:focus-visible {background:#143451;outline:2px solid #6acbe8;outline-offset:-2px;}
    .click-step .number {display:grid;place-items:center;flex:none;width:31px;height:31px;
      background:#144260;border:1px solid #3a809c;border-radius:9px;color:#adf0ff;font-weight:800;}
    .click-step .step-title {flex:1;font-size:14px;font-weight:750;}
    .click-step .step-arrow {color:#83b9d6;transition:transform .12s ease;}
    .click-step[open] .step-arrow {transform:rotate(180deg);}
    .click-body {border-top:1px solid #2b4d6b;padding:16px;background:#0b1930;}
    .click-body p {font-size:13px;color:#b6d0e7;margin:0 0 12px;}
    .sim-screen {background:#091327;border:1px solid #345778;border-radius:11px;overflow:hidden;max-width:850px;}
    .sim-topbar {display:flex;align-items:center;justify-content:space-between;gap:8px;padding:9px 12px;
      background:#1b2437;color:#eaf0ff;font-size:12px;font-weight:700;}
    .sim-system {display:flex;align-items:center;gap:8px;}
    .sim-system .icon {width:15px;height:15px;}
    .sim-workspace {display:grid;grid-template-columns:170px minmax(0,1fr);min-height:190px;}
    .sim-sidebar {padding:13px 10px;border-right:1px solid #294360;background:#132139;}
    .sim-sidebar div {display:flex;align-items:center;gap:9px;padding:10px;border-radius:7px;color:#b2c6dc;
      font-size:12px;}
    .sim-sidebar .selected {background:#235277;border:1px solid #54a4c2;color:#fff;font-weight:800;}
    .sim-main {padding:18px;min-width:0;}
    .sim-main h4 {font-size:15px;margin:0 0 13px;}
    .sim-field {display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;
      background:#152d49;border:1px solid #345573;border-radius:9px;padding:10px 12px;margin:8px 0;font-size:12px;}
    .sim-action {display:inline-flex;align-items:center;gap:6px;border:1px solid #48b9d7;background:#154866;
      border-radius:7px;padding:7px 10px;color:#c5f6ff;font-weight:800;white-space:nowrap;}
    .sim-action .icon {width:15px;height:15px;}
    .sim-add-toggle,.sim-choice input {position:absolute;opacity:0;width:1px;height:1px;}
    .sim-add-toggle:focus-visible + label {outline:2px solid #9cedfa;outline-offset:2px;}
    .sim-action[for] {cursor:pointer;min-height:44px;}
    .sim-added {display:none;flex-basis:100%;align-items:center;gap:6px;color:#a4f0d0;font-size:12px;}
    .sim-add-toggle:checked ~ .sim-added {display:flex;}
    .sim-choice {display:grid;gap:4px;}
    .sim-choice label {cursor:pointer;display:flex;align-items:center;gap:9px;padding:11px 12px;
      border:1px solid #34516a;border-radius:8px;color:#b9cde1;font-size:13px;min-height:44px;}
    .sim-choice input:checked + label {background:#123e57;border-color:#56bcd6;color:#e8fcff;font-weight:800;}
    .sim-choice input:focus-visible + label {outline:2px solid #9cedfa;outline-offset:2px;}
    .sim-option {display:flex;align-items:center;gap:9px;padding:11px 12px;border:1px solid #34516a;
      border-radius:8px;font-size:13px;margin:8px 0;color:#b9cde1;}
    .sim-option.selected {background:#123e57;border-color:#56bcd6;color:#e8fcff;font-weight:800;}
    .sim-option .icon {width:18px;height:18px;}
    .sim-menu {max-width:340px;margin:10px 10px 12px auto;background:#152944;border:1px solid #50718f;
      border-radius:9px;padding:8px;box-shadow:0 8px 22px #010a18;}
    .sim-menu .sim-option {margin:3px 0;}
    .sim-hint {margin:8px 0 0!important;color:#8fb0cc!important;font-size:11px!important;}
    .sim-preferences {padding:16px;background:#13243c;}
    .sim-preferences .sim-field {margin-bottom:11px;}
    .sim-input-menu {margin:0 0 11px;padding:0;border:0;background:transparent;}
    .sim-input-menu summary {cursor:pointer;display:flex;align-items:center;justify-content:space-between;
      gap:10px;padding:11px 12px;border:1px solid #4b6986;border-radius:9px;min-height:44px;
      color:#e8fcff;list-style:none;}
    .sim-input-menu summary::-webkit-details-marker {display:none;}
    .sim-input-menu summary:focus-visible {outline:2px solid #9cedfa;outline-offset:2px;}
    .sim-input-menu[open] summary {border-color:#60d5e7;background:#123e57;}
    .sim-input-menu .sim-option {margin:3px 0 0;}
    .mode-note {display:flex;align-items:center;gap:8px;margin:15px 0 0;color:#b3d7e6;font-size:12px;}
    .mode-note .icon {color:#79e9b5;}
    .app-grid {display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;}
    .app-grid > .app-group:last-child:nth-child(odd) {grid-column:1/-1;}
    .app-group {border:1px solid #2d4a6b;border-radius:12px;overflow:hidden;background:#0b1b32;}
    .app-group h3 {background:#142d4b;color:#d1eaff;padding:15px 17px;margin:0;border-bottom:1px solid #2c5877;}
    table {border-collapse:collapse;width:100%;}
    td {padding:11px 13px;border-top:1px solid #243950;vertical-align:middle;}
    td strong {font-size:14px;} td small {display:block;color:var(--muted);font-size:12px;margin-top:1px;}
    .status-cell {text-align:right;width:125px;} .pill {display:inline-flex;align-items:center;gap:6px;
      font-size:11px;font-weight:750;border-radius:999px;padding:5px 9px;white-space:nowrap;}
    .ready {background:#123d32;border:1px solid #287963;color:#92f0c1;}
    .optional {background:#1b3049;border:1px solid #38506a;color:#b2c6da;}
    .pairs {display:grid;grid-template-columns:repeat(2,1fr);gap:10px 20px;}
    .pairs div {padding:9px 0;border-bottom:1px solid var(--line);font-size:14px;}
    .pairs b {color:var(--blue);}
    details {margin-top:12px;padding:13px 16px;border:1px solid var(--line);border-radius:10px;background:#0a2037;}
    summary {font-weight:750;cursor:pointer;color:#88ddf5;}
    code {overflow-wrap:anywhere;}
    footer {display:flex;align-items:center;justify-content:center;flex-wrap:wrap;gap:8px 19px;
      color:#8da8c2;font-size:12px;padding:19px 18px 39px;text-align:center;}
    footer a {color:#84daee;text-underline-offset:3px;}
    @media(max-width:760px) { .summary,.steps,.app-grid,.pairs,.mini-flow {grid-template-columns:1fr;}
      .app-grid > .app-group:last-child:nth-child(odd){grid-column:auto;}
      .panel {padding:21px;} .status-cell{width:135px;} .nav .nav-brand{display:none;}
      .hero{padding:22px 0 32px;} .brandbar{margin-bottom:21px;}
      .live-badge{display:none;} .mock{max-width:410px;} .meta{gap:8px;}
      .sim-workspace{grid-template-columns:1fr;}.sim-sidebar{border-right:0;border-bottom:1px solid #294360;}
      .sim-sidebar div{display:inline-flex;}.sim-main{padding:13px;} }
    @media(prefers-reduced-motion:reduce) {html{scroll-behavior:auto;}.click-step .step-arrow{transition:none;}}
    @media print { :root {color-scheme:light;--ink:#14283c;--muted:#46596c;--blue:#24577b;--line:#cad6e0;}
      body{background:white;color:#14283c;}body::before{display:none;}
      .panel,.stat,.step,.app-group,.guide-shot,.mini-card,.tip{background:white!important;color:#14283c;
        border-color:#cbd6df;box-shadow:none;break-inside:avoid;}
      .hero{print-color-adjust:exact;-webkit-print-color-adjust:exact;}.nav-shell{display:none;}
      .stat strong,.section-label,.pairs b{color:#205b82!important;}
      .step p,.sub,td small,.mini-card p,.guide-shot .caption{color:#475b6e;}
      .app-group h3{background:#ebf3f8;color:#23465f;}.pill{border:1px solid #aaa;}
      .ready{color:#195d45;}.optional{color:#4b5f70;} }
  </style>
</head>
<body>
  <!-- Local SVG icon set: consistent strokes, no icon font or external requests. -->
  <svg class="icon-sprite" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <symbol id="i-power" viewBox="0 0 24 24"><path d="M12 2v10"/><path d="M18.36 6.64a9 9 0 1 1-12.73 0"/></symbol>
    <symbol id="i-wifi" viewBox="0 0 24 24"><path d="M2 8.82a15 15 0 0 1 20 0M5 12.86a10 10 0 0 1 14 0M8.5 16.5a5 5 0 0 1 7 0"/><path d="M12 20h.01"/></symbol>
    <symbol id="i-volume" viewBox="0 0 24 24"><path d="M11 5 6 9H3v6h3l5 4V5Z"/><path d="M15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14"/></symbol>
    <symbol id="i-battery" viewBox="0 0 24 24"><rect x="2" y="7" width="18" height="10" rx="2"/><path d="M22 11v2M5 10h10v4H5z"/></symbol>
    <symbol id="i-logout" viewBox="0 0 24 24"><path d="M10 17l5-5-5-5M15 12H3"/><path d="M12 3h6a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3h-6"/></symbol>
    <symbol id="i-restart" viewBox="0 0 24 24"><path d="M3 11a9 9 0 1 1 3 7M3 4v7h7"/></symbol>
    <symbol id="i-keyboard" viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M6 9h.01M10 9h.01M14 9h.01M18 9h.01M6 13h.01M10 13h.01M14 13h.01M18 13h.01M7 16h10"/></symbol>
    <symbol id="i-chat" viewBox="0 0 24 24"><path d="M21 11.5a8.4 8.4 0 0 1-.9 3.8A8.5 8.5 0 0 1 12.5 20a8.4 8.4 0 0 1-3.8-.9L3 21l1.9-5.7a8.4 8.4 0 0 1-.9-3.8A8.5 8.5 0 0 1 12.5 3h.5a8.5 8.5 0 0 1 8 8v.5Z"/></symbol>
    <symbol id="i-apps" viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></symbol>
    <symbol id="i-check" viewBox="0 0 24 24"><path d="m5 12 4 4L19 6"/></symbol>
    <symbol id="i-minus" viewBox="0 0 24 24"><path d="M5 12h14"/></symbol>
    <symbol id="i-mail" viewBox="0 0 24 24"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m2 6 10 7 10-7"/></symbol>
    <symbol id="i-appwindow" viewBox="0 0 24 24"><rect x="2" y="3" width="20" height="18" rx="2"/><path d="M2 9h20M6 6h.01M10 6h.01"/></symbol>
    <symbol id="i-settings" viewBox="0 0 24 24"><path d="M4 7h16M4 17h16M9 4v6M15 14v6"/></symbol>
    <symbol id="i-gear" viewBox="0 0 24 24"><path d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l-1.8 1.8a1.7 1.7 0 0 0-1.9-.3l-1 .6-.4 2.2h-2.6l-.4-2.2-1-.6a1.7 1.7 0 0 0-1.9.3l-1.8-1.8a1.7 1.7 0 0 0 .3-1.9l-.6-1-.2-2.2.8-.7a1.7 1.7 0 0 0 .3-1.9l1.8-1.8a1.7 1.7 0 0 0 1.9.3l1-.6.4-2.2h2.6l.4 2.2 1 .6a1.7 1.7 0 0 0 1.9-.3l1.8 1.8a1.7 1.7 0 0 0-.3 1.9l.6 1-.6 2.2Z"/></symbol>
    <symbol id="i-plus" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></symbol>
    <symbol id="i-chevron" viewBox="0 0 24 24"><path d="m6 9 6 6 6-6"/></symbol>
    <symbol id="i-info" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 10v6M12 7h.01"/></symbol>
  </svg>
  <header class="hero"><div class="wrap">
    <div class="brandbar"><div class="brand-ident"><span class="brand-mark" aria-hidden="true">N</span>
      <div><div class="brand">NAMHH</div><span class="brand-sub">UNIVERSAL LINUX OFFICE KIT</span></div></div>
      <span class="live-badge">BÁO CÁO TRÊN MÁY · OFFLINE READY</span></div>
    <span class="eyebrow">LOCAL FIRST · NAMHH DESKTOP KIT</span>
    <h1>${PAGE_TITLE}</h1>
    <p><strong>${STATUS_TITLE}.</strong> ${STATUS_NOTE}</p>
    <div class="meta"><span>${OS_NAME} · ${GENERATED}</span>
      <span class="contact"><svg class="icon" aria-hidden="true"><use href="#i-mail"/></svg>
        Liên hệ: <a href="mailto:huynhoainam@gmail.com">huynhoainam@gmail.com</a></span></div>
  </div></header>
  <div class="nav-shell"><nav class="wrap nav" aria-label="Các mục hướng dẫn">
    <span class="nav-brand">NAMHH KIT</span>
    <a href="#checklist"><svg class="icon" aria-hidden="true"><use href="#i-check"/></svg>Bắt đầu</a>
    <a href="#logout"><svg class="icon" aria-hidden="true"><use href="#i-power"/></svg>Log Out / Restart</a>
    <a href="#unikey"><svg class="icon" aria-hidden="true"><use href="#i-keyboard"/></svg>Hướng dẫn Unikey</a>
    <a href="#zalo"><svg class="icon" aria-hidden="true"><use href="#i-chat"/></svg>Zalo QR</a>
    <a href="#outlook"><svg class="icon" aria-hidden="true"><use href="#i-mail"/></svg>Outlook Web</a>
    <a href="#apps"><svg class="icon" aria-hidden="true"><use href="#i-apps"/></svg>Ứng dụng</a>
  </nav></div>
  <main class="wrap">
    <div class="summary">
      <div class="stat"><strong>${READY}/${TOTAL}</strong><span>Ứng dụng/tiện ích phát hiện sẵn sàng</span></div>
      <div class="stat"><strong>${OFFICE_COUNT}</strong><span>Bộ Office đang có (WPS ưu tiên)</span></div>
      <div class="stat"><strong>3 bước</strong><span>Đăng xuất, kiểm tra Unikey, mở Zalo</span></div>
    </div>
    ${ALERT}
    <section class="panel" id="checklist">
      <span class="section-label">01 / Bắt đầu · Start here</span>
      <h2>Ba việc nên làm ngay sau khi cài</h2>
      <p class="sub">Thực hiện theo thứ tự sau khi bộ cài hoàn tất.</p>
      <div class="steps">
        <div class="step"><span class="number">1</span><strong>Lưu tài liệu đang mở</strong>
          <p>Nhấn <span class="key">Ctrl</span> + <span class="key">S</span> trong Word/WPS hoặc ứng dụng khác trước khi thoát phiên.</p></div>
        <div class="step"><span class="number">2</span><strong>Đăng xuất rồi vào lại Ubuntu</strong>
          <p>Để bộ gõ tiếng Việt, biểu tượng Zalo và phím tắt nhận cấu hình mới.</p></div>
        <div class="step"><span class="number">3</span><strong>Kiểm tra bộ gõ Unikey</strong>
          <p>Bộ cài ưu tiên Unikey. Kiểm tra nguồn nhập, tùy chỉnh kiểu gõ trong Preferences, rồi thử trong WPS và Zalo.</p></div>
      </div>
    </section>
    <section class="panel" id="logout">
      <span class="section-label">02 / Ubuntu GNOME · Session</span>
      <h2>Đăng xuất (Log Out) hoặc khởi động lại (Restart)</h2>
      <p class="sub">Tên menu tiếng Anh theo Ubuntu GNOME. Hình minh họa vị trí thao tác.</p>
      <div class="steps">
        <div class="step"><span class="number">1</span><strong>Mở Quick Settings</strong>
          <p>Bấm cụm Wi‑Fi / âm lượng / pin ở <b>góc trên bên phải</b> thanh trên cùng (top bar).</p>
          <div class="mock"><div class="mockbar"><span>Activities</span><span class="focus" aria-label="Wi-Fi, âm lượng, pin">
            <svg class="icon" aria-hidden="true"><use href="#i-wifi"/></svg>
            <svg class="icon" aria-hidden="true"><use href="#i-volume"/></svg>
            <svg class="icon" aria-hidden="true"><use href="#i-battery"/></svg></span></div>
          <div class="mocknote">↑ Bấm vào cụm biểu tượng</div></div></div>
        <div class="step"><span class="number">2</span><strong>Bấm nút Power</strong>
          <p>Trong bảng <b>Quick Settings</b>, tìm nút nguồn <b>Power</b> / biểu tượng nguồn ở phía dưới.</p>
          <div class="mock"><div class="mockbar"><span>Quick Settings</span><span>×</span></div>
          <div class="mockmenu"><div class="mockline"><svg class="icon" aria-hidden="true"><use href="#i-wifi"/></svg>Wi‑Fi
            <svg class="icon" aria-hidden="true"><use href="#i-volume"/></svg>Sound</div>
            <div class="mockfooter"><span>Quick Settings</span><span class="power-button">
              <svg class="icon icon-lg" aria-hidden="true"><use href="#i-power"/></svg>Power</span></div></div></div></div>
        <div class="step"><span class="number">3</span><strong>Chọn “Log Out…”</strong>
          <p>Chọn <b>Log Out…</b> rồi xác nhận <b>Log Out</b>. Đăng nhập lại bằng mật khẩu Ubuntu.</p>
          <div class="mock"><div class="mockbar"><span>Power</span><span>×</span></div>
          <div class="mockmenu"><div class="mockline selected"><svg class="icon" aria-hidden="true"><use href="#i-logout"/></svg>Log Out…</div>
            <div class="mockline"><svg class="icon" aria-hidden="true"><use href="#i-restart"/></svg>Restart…</div>
            <div class="mockline"><svg class="icon" aria-hidden="true"><use href="#i-power"/></svg>Power Off…</div></div></div></div>
      </div>
      <div class="tip"><strong>Chọn đúng thao tác:</strong> <b>Log Out…</b> để áp dụng bộ gõ phiên đăng nhập mới; <b>Restart…</b> khi Zalo bị xoay ở màn hình đăng nhập quá lâu. <b>Lock</b> chỉ khóa màn hình, không phải đăng xuất. Hãy lưu tài liệu trước khi làm.</div>
    </section>
    <section class="panel" id="unikey">
      <span class="section-label">03 / Hướng dẫn Unikey · Input Method</span>
      <h2>Unikey — bộ gõ tiếng Việt ưu tiên</h2>
      <p class="sub">Bộ cài đưa <b>Vietnamese (Unikey)</b> lên đầu danh sách và ưu tiên khi đăng nhập Ubuntu GNOME.
        Bạn có thể tùy chỉnh kiểu gõ theo thói quen; với tài liệu hiện đại, nên dùng bảng mã <b>Unicode</b>.</p>
      <div class="notice"><strong>Hướng dẫn có thể bấm để xem từng bước.</strong> Đây là mô phỏng các màn hình GNOME/IBus,
        không tự thay đổi cài đặt máy. Tên và vị trí biểu tượng có thể khác nhẹ giữa các phiên bản Ubuntu.</div>
      <div class="click-guide">
        <details class="click-step" open><summary><span class="number">1</span><span class="step-title">Mở Settings <span aria-hidden="true">→</span> Keyboard</span>
          <svg class="icon step-arrow" aria-hidden="true"><use href="#i-chevron"/></svg></summary>
          <div class="click-body"><p>Nhấn <span class="key">Super</span>, tìm <b>Settings</b> (biểu tượng bánh răng), rồi chọn <b>Keyboard</b>.</p>
            <div class="sim-screen" role="img" aria-label="Minh họa cửa sổ GNOME Settings: chọn Keyboard, nhìn thấy Input Sources và nút dấu cộng">
              <div class="sim-topbar"><span>Settings</span><span class="sim-system"><svg class="icon" aria-hidden="true"><use href="#i-gear"/></svg> Ubuntu</span></div>
              <div class="sim-workspace"><div class="sim-sidebar">
                <div><svg class="icon" aria-hidden="true"><use href="#i-wifi"/></svg>Wi-Fi</div>
                <div class="selected"><svg class="icon" aria-hidden="true"><use href="#i-keyboard"/></svg>Keyboard</div></div>
                <div class="sim-main"><h4>Keyboard</h4>
                  <div class="sim-field"><span><b>Input Sources</b></span><span class="sim-action"><svg class="icon" aria-hidden="true"><use href="#i-plus"/></svg>Add Input Source…</span></div>
                  <div class="sim-field"><span>Vietnamese (Unikey)</span><span class="pill ready"><svg class="icon icon-xs" aria-hidden="true"><use href="#i-check"/></svg>Ưu tiên</span></div>
                </div></div></div></div>
        </details>
        <details class="click-step"><summary><span class="number">2</span><span class="step-title">Nếu thiếu Unikey: nhấn <b>+</b> để thêm bộ gõ</span>
          <svg class="icon step-arrow" aria-hidden="true"><use href="#i-chevron"/></svg></summary>
          <div class="click-body"><p>Trong <b>Input Sources</b>, nhấn <b>+ Add Input Source…</b> → <b>Vietnamese</b> → <b>Vietnamese (Unikey)</b> → <b>Add</b>. Nếu đã có Unikey thì bỏ qua.</p>
            <div class="sim-screen"><div class="sim-topbar"><span>Add an Input Source</span><svg class="icon" aria-hidden="true"><use href="#i-plus"/></svg></div>
              <div class="sim-preferences"><div class="sim-option"><svg class="icon" aria-hidden="true"><use href="#i-keyboard"/></svg>Vietnamese</div>
                <div class="sim-option selected"><svg class="icon" aria-hidden="true"><use href="#i-check"/></svg>Vietnamese (Unikey)</div>
                <div class="sim-field"><span>Chọn nguồn nhập tiếng Việt</span><input class="sim-add-toggle" type="checkbox" id="sim-add-unikey">
                  <label class="sim-action" for="sim-add-unikey"><svg class="icon" aria-hidden="true"><use href="#i-plus"/></svg>Add</label>
                  <span class="sim-added"><svg class="icon icon-xs" aria-hidden="true"><use href="#i-check"/></svg>Đã thêm Unikey trong mô phỏng</span></div>
              </div></div></div>
        </details>
        <details class="click-step"><summary><span class="number">3</span><span class="step-title">Bật Unikey từ thanh trên cùng hoặc Super + Space</span>
          <svg class="icon step-arrow" aria-hidden="true"><use href="#i-chevron"/></svg></summary>
          <div class="click-body"><p>Đăng xuất và đăng nhập lại để áp dụng ưu tiên. Nếu chưa gõ tiếng Việt, nhấn <span class="key">Super</span> + <span class="key">Space</span> hoặc bấm chỉ báo nguồn nhập (<b>en / vi</b>) trên <b>top bar</b> rồi chọn <b>Vietnamese (Unikey)</b>.</p>
            <div class="sim-screen"><div class="sim-topbar"><span>Activities</span><span class="sim-system"><span class="sim-action">vi <svg class="icon" aria-hidden="true"><use href="#i-chevron"/></svg></span>
                <svg class="icon" aria-hidden="true"><use href="#i-wifi"/></svg><svg class="icon" aria-hidden="true"><use href="#i-volume"/></svg></span></div>
              <div class="sim-menu"><div class="sim-choice" role="group" aria-label="Chọn thử nguồn nhập trong mô phỏng">
                <input type="radio" id="sim-ime-en" name="sim-active-input"><label for="sim-ime-en"><svg class="icon" aria-hidden="true"><use href="#i-keyboard"/></svg>English (US)</label>
                <input type="radio" id="sim-ime-vi" name="sim-active-input" checked><label for="sim-ime-vi"><svg class="icon" aria-hidden="true"><use href="#i-check"/></svg>Vietnamese (Unikey)</label>
                </div>
                <div class="sim-option"><svg class="icon" aria-hidden="true"><use href="#i-gear"/></svg>Input Source Settings</div></div>
              </div><p class="sim-hint">Bấm thử English / Unikey để thấy lựa chọn. Đây chỉ là minh họa; trên Ubuntu thật dùng Super + Space.</p>
          </div>
        </details>
        <details class="click-step"><summary><span class="number">4</span><span class="step-title">Tùy chỉnh kiểu gõ Unikey và Unicode</span>
          <svg class="icon step-arrow" aria-hidden="true"><use href="#i-chevron"/></svg></summary>
          <div class="click-body"><p>Khi Unikey đang bật, bấm chỉ báo nguồn nhập → <b>More settings…</b> (hoặc <b>Preferences</b> nếu menu hiện mục này). Trong <b>Settings - ibus-unikey</b>, chọn <b>Input method</b> theo thói quen và <b>Output charset: Unicode</b>.</p>
            <div class="sim-screen"><div class="sim-topbar"><span>Settings - ibus-unikey</span><svg class="icon" aria-hidden="true"><use href="#i-gear"/></svg></div>
              <div class="sim-preferences">
                <details class="sim-input-menu"><summary><b>Input method:</b><span>Telex <svg class="icon icon-xs" aria-hidden="true"><use href="#i-chevron"/></svg></span></summary>
                  <div class="sim-option selected"><svg class="icon" aria-hidden="true"><use href="#i-check"/></svg>Telex (ví dụ đang chọn)</div>
                  <p class="sim-hint">Trên Unikey thật, bấm Input method để xem các kiểu gõ và chọn kiểu bạn quen dùng.</p>
                </details>
                <div class="sim-field"><b>Output charset:</b><span class="pill ready"><svg class="icon icon-xs" aria-hidden="true"><use href="#i-check"/></svg>Unicode</span></div>
                <p class="sim-hint">Bấm thử Input method ở trên để xem minh họa. Thao tác trên trang không thay đổi máy của bạn.</p>
              </div></div></div>
        </details>
      </div>
      <p class="mode-note"><svg class="icon" aria-hidden="true"><use href="#i-info"/></svg>Trên Linux Mint Cinnamon: <b>Fcitx 5 Configuration → Input Method → Unikey → Configure</b>. Nếu chưa thấy Unikey sau khi cài, hãy <a href="#logout">Log Out rồi đăng nhập lại</a>.</p>
      <div class="tip"><strong>Kiểm tra thực tế:</strong> mở <b>Text Editor</b> hoặc <b>WPS Writer</b>, gõ thử theo kiểu đã chọn. Nếu mất bộ gõ sau khi đăng nhập, chạy lại tùy chọn <b>--fix-unikey</b>; tiện ích phục hồi chỉ thêm lại nguồn nhập bị mất và giữ các lựa chọn cá nhân.</div>
    </section>
    <section class="panel" id="zalo">
      <span class="section-label">04 / Đăng nhập Zalo · QR Code</span>
      <h2>Zalo: quét QR rồi hiện “Đang đăng nhập…” quá lâu?</h2>
      <div class="mini-flow" aria-label="Các trạng thái khi đăng nhập Zalo">
        <div class="mini-card good"><b><svg class="icon" aria-hidden="true"><use href="#i-chat"/></svg> 01 · Scan QR Code</b>
          <p>Quét mã mới. Xác nhận trên điện thoại nếu Zalo yêu cầu.</p></div>
        <div class="mini-card bad"><b><svg class="icon" aria-hidden="true"><use href="#i-restart"/></svg> 02 · Signing in…</b>
          <p>Quay quá lâu: đóng Zalo → Restart… → mở lại và quét mã mới.</p></div>
      </div>
      <ol class="guide-list">
        <li>Dùng điện thoại mở Zalo, quét <b>mã QR mới nhất</b> trên ứng dụng Zalo Linux và xác nhận yêu cầu đăng nhập trên điện thoại nếu có.</li>
        <li>Nếu ứng dụng cứ xoay sau vài phút, hãy <b>đóng hẳn Zalo</b>, lưu công việc, chọn <b>Quick Settings → Power → Restart…</b> (xem minh họa phía trên).</li>
        <li>Đăng nhập lại Ubuntu, mở <b>Zalo Linux</b> từ danh sách ứng dụng, quét lại mã QR mới. Không cần xóa dữ liệu chat hoặc cài lại ứng dụng.</li>
        <li>Nếu vẫn không vào được, có thể do kết nối mạng/proxy doanh nghiệp chặn bước xác thực. Hãy nhờ IT kiểm tra; không tự tắt bảo vệ mạng.</li>
      </ol>
      <div class="tip">Flameshot: bấm <span class="key">Ctrl</span> + <span class="key">Shift</span> + <span class="key">S</span> để chọn vùng màn hình. Lần đầu trên Wayland có thể hiện hộp thoại cho phép chia sẻ/chụp màn hình.</div>
    </section>
    <section class="panel" id="outlook">
      <span class="section-label">05 / Microsoft 365 · Mail</span>
      <h2>Outlook công việc trên Ubuntu</h2>
      <p class="sub">Mở <b>Microsoft Outlook (Web)</b> trong danh sách ứng dụng để dùng tài khoản email công ty. Kit không yêu cầu hoặc lưu mật khẩu Microsoft.</p>
      <div class="steps">
        <div class="step"><span class="number">1</span><strong>Mở Outlook Web</strong>
          <p>Nhấn <span class="key">Super</span>, tìm <b>Microsoft Outlook (Web)</b> và đăng nhập trực tiếp trên trang Microsoft 365.</p></div>
        <div class="step"><span class="number">2</span><strong>Cài thành ứng dụng riêng nếu muốn</strong>
          <p>Trong Edge chọn menu <b>… → Apps → Install this site as an app</b>. Trong Chrome tìm <b>Install Outlook</b> khi tùy chọn xuất hiện.</p></div>
        <div class="step"><span class="number">3</span><strong>Firefox vẫn sử dụng được</strong>
          <p>Nếu chỉ có Firefox, Outlook mở trên trình duyệt. Một số tính năng khác bản Outlook Windows; kết nối Internet cần thiết để đồng bộ.</p></div>
      </div>
      <div class="tip"><strong>Lưu ý:</strong> Đây là Outlook Web chính thức, không phải file cài Outlook .deb hay ứng dụng Windows chạy qua Wine.</div>
    </section>
    <section class="panel" id="apps">
      <span class="section-label">06 / Ứng dụng · Installed apps</span>
      <h2>Ứng dụng của bạn và công dụng</h2>
      <p class="sub">Trạng thái được kiểm tra trên máy. “Chưa cài” không đồng nghĩa có lỗi.</p>
      <div class="app-grid">${APP_TABLES}</div>
    </section>
    <section class="panel">
      <span class="section-label">07 / Windows → Ubuntu · Quick reference</span>
      <h2>Đổi từ Windows sang Ubuntu: nhớ nhanh</h2>
      <div class="pairs">
        <div><b>Start menu (Windows)</b> → Activities / phím Super</div>
        <div><b>File Explorer</b> → Files / Tệp</div>
        <div><b>C:\Users\TênBạn</b> → Home / Thư mục cá nhân</div>
        <div><b>Microsoft Word / Excel</b> → WPS Office / LibreOffice</div>
        <div><b>Outlook (Windows)</b> → Microsoft Outlook (Web) · Chrome/Edge/Firefox</div>
        <div><b>Paint</b> → Pinta (nếu kho ứng dụng có gói)</div>
        <div><b>Windows + Shift + S</b> → Ctrl + Alt + S (Flameshot)</div>
        <div><b>Alt + Tab, Ctrl + C/V, Ctrl + S</b> → dùng giống Windows</div>
        <div><b>Windows Network Drive / NAS</b> → Files → Other Locations → Connect to Server → <code>smb://server/share</code></div>
        <div><b>Windows Backup</b> → Backups; tự chọn nơi lưu bản sao trước khi bật sao lưu định kỳ</div>
        <div><b>File preview</b> → Files → chọn tệp → nhấn Space</div>
        <div><b>Disk Cleanup / Storage</b> → Disk Usage Analyzer</div>
      </div>
    </section>
    <section class="panel">
      <span class="section-label">08 / Dành cho IT · Technical details</span>
      <h2>Chi tiết cài đặt</h2>
      <p class="sub">Phần này dành cho IT nếu cần hỗ trợ. Người dùng thông thường không phải thao tác gì với các đường dẫn.</p>
      <details><summary>Xem cảnh báo và thông tin kỹ thuật</summary>
        <ul>${DETAILS}</ul>
        <p><b>Báo cáo dạng văn bản:</b> <code>${LOG_PATH}</code></p>
        <p><b>Bản sao cấu hình trước khi sửa:</b> <code>${BACKUP_PATH}</code></p>
      </details>
    </section>
  </main>
  <footer><strong>NAMHH · UNIVERSAL LINUX OFFICE KIT</strong>
    <span>Liên hệ: <a href="mailto:huynhoainam@gmail.com">huynhoainam@gmail.com</a></span>
    <span>Báo cáo lưu trên máy · Không gửi dữ liệu ra ngoài</span></footer>
</body>
</html>
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--backup", default="")
    args = parser.parse_args()
    result = render(args.report, args.output, args.backup)
    print(f"HTML report ready: {result}")


if __name__ == "__main__":
    main()

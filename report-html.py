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
        ("Unikey tiếng Việt", "Gõ tiếng Việt theo VNI hoặc Telex trong ứng dụng.", ("ibus-daemon", "fcitx5"), ("ibus-unikey", "fcitx5-unikey")),
        ("Flameshot", "Chụp vùng màn hình bằng Ctrl + Alt + S.", ("flameshot",), ("flameshot",)),
        ("Font văn phòng", "Hiển thị chữ tiếng Việt và tài liệu Word đúng hơn.", (), ("fonts-crosextra-carlito", "fonts-liberation2")),
    )),
    ("Liên lạc và Internet", (
        ("Zalo Linux", "Nhắn tin và trao đổi công việc bằng tài khoản Zalo.", ("zalo-linux",), ()),
        ("Google Chrome", "Duyệt web, Gmail, Google Drive và họp trực tuyến.", ("google-chrome", "google-chrome-stable"), ("google-chrome-stable",)),
        ("Microsoft Edge", "Duyệt web và dùng Microsoft 365 trên trình duyệt.", ("microsoft-edge", "microsoft-edge-stable"), ("microsoft-edge-stable",)),
        ("Firefox", "Trình duyệt web có sẵn trên nhiều máy Ubuntu.", ("firefox",), ("firefox",)),
        ("Thunderbird", "Quản lý email như Outlook trên Windows.", ("thunderbird",), ("thunderbird",)),
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
    if name == "Unikey tiếng Việt":
        return pkg_installed("ibus-unikey") or pkg_installed("fcitx5-unikey")
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
    :root { color-scheme: light; --ink:#192d41; --muted:#5c6e7e; --blue:#245b80;
      --line:#dce5eb; --surface:#fff; --bg:#f4f7f9; --green:#216a4f; --amber:#815b24;
      --dark:#0c2133; --soft:#edf4f8; }
    * { box-sizing:border-box; }
    .icon-sprite { position:absolute;width:0;height:0;overflow:hidden; }
    .icon { width:18px;height:18px;stroke:currentColor;fill:none;stroke-width:2;
      stroke-linecap:round;stroke-linejoin:round;vertical-align:middle;flex:none; }
    .icon-xs {width:13px;height:13px;stroke-width:2.3;}
    .icon-lg {width:23px;height:23px;}
    html { scroll-behavior:smooth; scroll-padding-top:90px; }
    body { margin:0; background:var(--bg); color:var(--ink);
      font-family:Inter,system-ui,-apple-system,"Segoe UI",Arial,sans-serif; line-height:1.6; }
    .wrap { width:min(1130px, calc(100% - 38px)); margin:auto; }
    .hero { position:relative; overflow:hidden; background:linear-gradient(115deg,#0a1a2b 0%,#183a53 72%,#205069 100%);
      color:white; padding:44px 0 55px; }
    .hero::before {content:"";position:absolute;inset:0;opacity:.22;pointer-events:none;
      background-image:linear-gradient(#8dc5d722 1px,transparent 1px),
      linear-gradient(90deg,#8dc5d722 1px,transparent 1px);background-size:40px 40px;}
    .hero::after { content:"";position:absolute;width:450px;height:450px;border:1px solid #ffffff1b;
      border-radius:50%;right:-110px;top:-215px;box-shadow:0 0 0 65px #ffffff06,0 0 0 130px #ffffff06;pointer-events:none; }
    .hero .wrap { position:relative;z-index:1; }
    .brand { font-size:12px; font-weight:800; letter-spacing:.16em; color:#b9d8e8; }
    .eyebrow { display:inline-block;margin:18px 0 2px;padding:5px 11px;border:1px solid #7db9c66b;
      border-radius:99px;color:#d9f2f4;background:#5eb3bc1a;font-size:12px;font-weight:700;letter-spacing:.02em; }
    h1 { margin:11px 0 9px; font-size:clamp(29px,4vw,45px); line-height:1.2;letter-spacing:-.025em; }
    .hero p { color:#e2ebf2; max-width:850px; margin:8px 0 0;font-size:15px; }
    .meta { display:flex;align-items:center;flex-wrap:wrap;gap:10px 20px;font-size:12px;
      margin-top:25px;color:#bdd1df; }
    .hero a {color:#fff;text-underline-offset:3px;}
    .meta .contact {display:inline-flex;align-items:center;gap:6px;}
    .nav-shell { position:sticky;top:0;z-index:10;background:#f8fafcfa;backdrop-filter:blur(10px);
      border-bottom:1px solid var(--line); }
    .nav { display:flex;align-items:center;gap:7px;overflow-x:auto;padding:11px 0; }
    .nav a { display:inline-flex;align-items:center;gap:7px;color:#365671;text-decoration:none;
      font-weight:700;font-size:12px;white-space:nowrap;min-height:44px;
      border:1px solid transparent;border-radius:9px;padding:10px 12px; }
    .nav a:hover,.nav a:focus-visible { background:#e5eef4;border-color:#c9dce7;outline:2px solid transparent; }
    .nav .nav-brand { margin-right:auto;color:var(--dark);letter-spacing:.1em; }
    .summary { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:15px; margin:24px 0; }
    .stat,.panel { background:var(--surface); border:1px solid var(--line); border-radius:16px; }
    .stat { padding:21px 23px;border-top:3px solid #80b3c8; }
    .stat strong { font-size:31px; display:block; color:var(--blue);letter-spacing:-.035em;line-height:1.25; }
    .stat span { color:var(--muted); font-size:12px; }
    .panel { padding:29px 30px; margin:19px 0; box-shadow:0 8px 30px #18384d09; }
    .section-label { font-size:11px;letter-spacing:.13em;text-transform:uppercase;color:#447a95;
      font-weight:800;margin-bottom:7px;display:block; }
    h2 { font-size:23px; margin:0 0 11px;letter-spacing:-.02em; }
    h3 { font-size:16px; margin:0 0 10px; }
    p { margin:8px 0 13px; } .sub { color:var(--muted); font-size:14px; }
    a { color:#225c87; } a:focus-visible { outline:3px solid #8dbbd8;outline-offset:3px; }
    .notice,.alert { padding:13px 16px; border-radius:10px; background:#edf6f1;
      border-left:4px solid #63a484; color:#265a43; margin:18px 0; }
    .alert { background:#fff6e9; border-color:#dcab67; color:#795021; }
    .steps { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:15px; }
    .step { background:#f7f9fb; border:1px solid var(--line); border-radius:13px; padding:19px;min-width:0; }
    .step .number { background:#dbeaf3; color:var(--blue); display:inline-flex; align-items:center;
      justify-content:center; width:31px; height:31px; border-radius:9px; font-weight:800; }
    .step strong { display:block; margin:12px 0 6px;font-size:15px; }
    .step p { font-size:13px; color:var(--muted); margin:0; }
    .mock { margin-top:16px; border:1px solid #aebfcd; border-radius:10px; overflow:hidden;
      background:#e9eff4; min-height:153px; font-size:12px;box-shadow:0 4px 10px #273d4b0e; }
    .mockbar { background:#27333f; color:#fff; display:flex;align-items:center;
      justify-content:space-between; padding:10px 11px; }
    .focus { color:#fff; background:#527d99; border:1px solid #b2d0e39c;border-radius:6px;
      padding:4px 7px;display:inline-flex;align-items:center;gap:8px; }
    .focus .icon {width:15px;height:15px;}
    .mockmenu { margin:9px 10px 9px auto; background:#fff; border:1px solid #cad6df;
      box-shadow:0 6px 16px #253d5122; border-radius:9px; width:87%; padding:9px; }
    .mockline { padding:8px 10px; border-radius:6px;display:flex;align-items:center;gap:9px; }
    .mockline.selected { background:#d6e8f3; color:#1a506e; font-weight:800; }
    .mockline .icon {width:16px;height:16px;}
    .mockfooter {display:flex;align-items:center;justify-content:space-between;border-top:1px solid #e0e7eb;
      margin-top:6px;padding:10px 6px 2px;color:#486478;}
    .power-button {display:inline-flex;align-items:center;gap:8px;background:#d6e8f3;color:#154d6e;
      border:2px solid #5e9cbd;border-radius:8px;padding:8px 12px;font-weight:800;}
    .mocknote { padding:24px 14px 10px;text-align:right;color:#315d78;font-weight:700;font-size:11px; }
    .key { display:inline-block; border:1px solid #b9cbd8; background:#f3f6f8; box-shadow:0 2px 0 #d2dce2;
      border-radius:5px; padding:1px 7px; white-space:nowrap; color:#304b60; font-weight:650; }
    .tip { margin-top:17px; background:#edf5f9; border-left:3px solid #83b3cc;
      border-radius:9px; padding:15px 17px; font-size:14px; }
    .guide-list { margin:13px 0 0;padding-left:23px; }
    .guide-list li { padding-left:7px;margin:11px 0; }
    .guide-list li::marker { color:#2e6b91;font-weight:800; }
    .guide-shot { background:#f5f8fa;border:1px solid #d7e4eb;border-radius:13px;padding:17px;margin:17px 0; }
    .guide-shot .caption { color:#476b83;font-size:12px;margin-top:9px; }
    .mini-flow { display:grid;grid-template-columns:1fr 1fr;gap:13px;margin-top:12px; }
    .mini-card { background:white;border:1px solid #d9e4eb;border-radius:11px;padding:15px; }
    .mini-card b {display:flex;align-items:center;gap:8px;margin-bottom:7px;}
    .mini-card p {font-size:12px;color:var(--muted);}
    .mini-card.bad {border-color:#dfcda8;background:#fffbf3;} .mini-card.good {border-color:#b5d6c6;background:#f3faf6;}
    .keymap { display:flex;flex-wrap:wrap;gap:7px;margin:13px 0; }
    .keymap span {background:#edf3f7;padding:5px 8px;border-radius:7px;font-size:12px;color:#35586f;}
    .app-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:14px; }
    .app-group { border:1px solid var(--line); border-radius:12px; overflow:hidden; }
    .app-group h3 { background:#eaf1f6; color:#274c66;padding:15px 17px; margin:0; }
    table { border-collapse:collapse; width:100%; } td { padding:11px 13px; border-top:1px solid #ecf0f3; vertical-align:middle; }
    td strong { font-size:14px; } td small { display:block; color:var(--muted); font-size:12px; margin-top:1px; }
    .status-cell { text-align:right; width:125px; } .pill { display:inline-flex;align-items:center;gap:6px;
      font-size:11px; font-weight:700;border-radius:999px; padding:5px 9px; white-space:nowrap; }
    .ready { background:#e0efe6; color:var(--green); }
    .optional { background:#eff2f5; color:#576a79; }
    .pairs { display:grid; grid-template-columns:repeat(2,1fr); gap:10px 20px; }
    .pairs div { padding:9px 0; border-bottom:1px solid var(--line); font-size:14px; }
    .pairs b { color:var(--blue); }
    details { margin-top:12px; padding:13px 16px; border:1px solid var(--line); border-radius:10px; }
    summary { font-weight:700; cursor:pointer; color:var(--blue); }
    code { overflow-wrap:anywhere; }
    footer { display:flex;align-items:center;justify-content:center;flex-wrap:wrap;gap:8px 19px;
      color:#667c8b;font-size:12px;padding:19px 18px 39px;text-align:center; }
    footer a {color:#325d7c;text-underline-offset:3px;}
    @media(max-width:760px) { .summary,.steps,.app-grid,.pairs,.mini-flow {grid-template-columns:1fr;}
      .panel {padding:21px;} .status-cell{width:135px;} .nav .nav-brand{display:none;}
      .hero{padding:32px 0 37px;} .mock{max-width:410px;} .meta{gap:8px;} }
    @media print { body{background:white;} .panel,.stat{box-shadow:none;break-inside:avoid;}
      .hero{print-color-adjust:exact;} .nav-shell{display:none;} }
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
  </svg>
  <header class="hero"><div class="wrap">
    <div class="brand">NAMHH / UNIVERSAL LINUX OFFICE KIT</div>
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
    <a href="#vni"><svg class="icon" aria-hidden="true"><use href="#i-keyboard"/></svg>Unikey VNI</a>
    <a href="#zalo"><svg class="icon" aria-hidden="true"><use href="#i-chat"/></svg>Zalo QR</a>
    <a href="#apps"><svg class="icon" aria-hidden="true"><use href="#i-apps"/></svg>Ứng dụng</a>
  </nav></div>
  <main class="wrap">
    <div class="summary">
      <div class="stat"><strong>${READY}/${TOTAL}</strong><span>Ứng dụng/tiện ích phát hiện sẵn sàng</span></div>
      <div class="stat"><strong>${OFFICE_COUNT}</strong><span>Bộ Office đang có (WPS ưu tiên)</span></div>
      <div class="stat"><strong>3 bước</strong><span>Đăng xuất, đặt VNI, mở Zalo</span></div>
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
        <div class="step"><span class="number">3</span><strong>Chọn VNI và dùng thử</strong>
          <p>Trong bộ gõ Unikey, chọn VNI + Unicode, thử gõ tiếng Việt trong WPS và Zalo.</p></div>
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
    <section class="panel" id="vni">
      <span class="section-label">03 / Tiếng Việt · Input method</span>
      <h2>Gõ tiếng Việt kiểu VNI như trên Windows</h2>
      <p class="sub">Giữ cách gõ quen thuộc từ UniKey Windows. Hãy sử dụng <b>Unicode</b> cho Word, WPS, trình duyệt và Zalo.</p>
      <ol class="guide-list">
        <li><b>Thêm Unikey:</b> mở <b>Settings → Keyboard → Input Sources → Add Input Source → Vietnamese → Vietnamese (Unikey)</b> nếu chưa xuất hiện trong danh sách.</li>
        <li><b>Chuyển bộ gõ:</b> nhấn <span class="key">Super</span> (phím Windows) + <span class="key">Space</span>, chọn <b>Vietnamese (Unikey)</b>.</li>
        <li><b>Đặt VNI:</b> bấm mục <b>VI / Unikey</b> trên top bar → <b>Preferences / Setup</b> → <b>Input Method: VNI</b> và <b>Character Set: Unicode</b>. Trên Cinnamon, mở <b>Fcitx 5 Configuration → Unikey → Configure</b>.</li>
        <li><b>Kiểm tra:</b> mở <b>Text Editor</b> hoặc <b>WPS Writer</b>, gõ <span class="key">tie6ng1 vie6t5</span> → <b>tiếng việt</b>.</li>
      </ol>
      <div class="guide-shot"><strong>Phím số trong VNI / VNI number keys</strong>
        <div class="keymap"><span>1 · Sắc</span><span>2 · Huyền</span><span>3 · Hỏi</span><span>4 · Ngã</span><span>5 · Nặng</span><span>6 · Â/Ê/Ô</span><span>7 · Ơ/Ư</span><span>8 · Ă</span><span>9 · Đ</span></div>
        <div class="caption">Ví dụ: “a61” → “ấ”, “a81” → “ắ”.</div>
      </div>
      <div class="tip">Nếu chưa thấy Unikey sau khi cài, hãy <a href="#logout">đăng xuất rồi đăng nhập lại</a>. Đừng cài hai bộ gõ chạy đồng thời; bộ cài đã chọn IBus cho Ubuntu GNOME và Fcitx5 cho Cinnamon.</div>
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
      <div class="tip">Flameshot: bấm <span class="key">Ctrl</span> + <span class="key">Alt</span> + <span class="key">S</span> để chọn vùng màn hình. Lần đầu trên Wayland có thể hiện hộp thoại cho phép chia sẻ/chụp màn hình.</div>
    </section>
    <section class="panel" id="apps">
      <span class="section-label">05 / Ứng dụng · Installed apps</span>
      <h2>Ứng dụng của bạn và công dụng</h2>
      <p class="sub">Trạng thái được kiểm tra trên máy. “Chưa cài” không đồng nghĩa có lỗi.</p>
      <div class="app-grid">${APP_TABLES}</div>
    </section>
    <section class="panel">
      <span class="section-label">06 / Windows → Ubuntu · Quick reference</span>
      <h2>Đổi từ Windows sang Ubuntu: nhớ nhanh</h2>
      <div class="pairs">
        <div><b>Start menu (Windows)</b> → Activities / phím Super</div>
        <div><b>File Explorer</b> → Files / Tệp</div>
        <div><b>C:\Users\TênBạn</b> → Home / Thư mục cá nhân</div>
        <div><b>Microsoft Word / Excel</b> → WPS Office / LibreOffice</div>
        <div><b>Windows + Shift + S</b> → Ctrl + Alt + S (Flameshot)</div>
        <div><b>Alt + Tab, Ctrl + C/V, Ctrl + S</b> → dùng giống Windows</div>
      </div>
    </section>
    <section class="panel">
      <span class="section-label">07 / Dành cho IT · Technical details</span>
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

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
            status = "Đã sẵn sàng" if installed else "Chưa cài / tùy chọn"
            rows.append(
                f'<tr><td><strong>{escape(name)}</strong><small>{escape(purpose)}</small></td>'
                f'<td class="status-cell"><span class="pill {cls}">{status}</span></td></tr>'
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
        status_title = "Đã chạy thử bản mô phỏng (dry-run)"
        status_note = "Chưa cài thêm phần mềm hoặc thay đổi cấu hình. Danh sách bên dưới là tình trạng thực tế của máy chạy thử."
    elif failures:
        status_title = "Có ứng dụng cần kiểm tra thêm"
        status_note = "Phần lớn thao tác vẫn dùng được. Có mục chưa hoàn tất; xem chi tiết cuối báo cáo."
    else:
        status_title = "Đã hoàn tất cài đặt"
        status_note = "Bạn có thể bắt đầu làm việc. Hãy đăng xuất rồi đăng nhập lại để bộ gõ hoạt động ổn định."
    alert = (
        '<div class="alert">Có ' + str(len(failures)) +
        ' mục chưa hoàn tất. Các ứng dụng đã cài trước đó vẫn được giữ nguyên.</div>'
        if failures else
        '<div class="notice">Không cần cài lại ứng dụng đã có. Dữ liệu Zalo và tài liệu cá nhân được giữ nguyên.</div>'
    )
    if dry_run:
        alert = '<div class="notice">Bản xem trước trên Ubuntu: không tải hoặc cài WPS/Zalo thật, không kết nối tài khoản Zalo.</div>'
    technical = "".join(f"<li>{escape(item)}</li>" for item in warnings + failures)
    if not technical:
        technical = "<li>Không ghi nhận cảnh báo từ bộ cài.</li>"
    html = Template(HTML_TEMPLATE).substitute(
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
    :root { color-scheme: light; --ink:#223449; --muted:#586b7d; --blue:#365f7b;
      --line:#dbe3e9; --surface:#fff; --bg:#f2f5f7; --green:#27674d; --amber:#815b24; }
    * { box-sizing:border-box; }
    body { margin:0; background:var(--bg); color:var(--ink);
      font-family:Inter,system-ui,-apple-system,"Segoe UI",Arial,sans-serif; line-height:1.55; }
    .wrap { width:min(1090px, calc(100% - 36px)); margin:auto; }
    .hero { background:linear-gradient(120deg,#253d51,#42627a); color:white; padding:35px 0 32px; }
    .brand { font-size:12px; font-weight:750; letter-spacing:.15em; color:#d5e4ed; }
    h1 { margin:10px 0 5px; font-size:clamp(25px,4vw,39px); line-height:1.25; }
    .hero p { color:#e3edf4; max-width:750px; margin:8px 0 0; }
    .meta { font-size:13px; margin-top:18px; color:#d1dfe8; }
    .summary { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:14px; margin:20px 0; }
    .stat,.panel { background:var(--surface); border:1px solid var(--line); border-radius:14px; }
    .stat { padding:19px; } .stat strong { font-size:27px; display:block; color:var(--blue); }
    .stat span { color:var(--muted); font-size:13px; }
    .panel { padding:24px; margin:18px 0; box-shadow:0 2px 10px #233f5210; }
    h2 { font-size:21px; margin:0 0 14px; } h3 { font-size:16px; margin:0 0 10px; }
    p { margin:8px 0 13px; } .sub { color:var(--muted); font-size:14px; }
    .notice,.alert { padding:13px 16px; border-radius:10px; background:#edf6f1;
      border-left:4px solid #63a484; color:#265a43; margin:18px 0; }
    .alert { background:#fff6e9; border-color:#dcab67; color:#795021; }
    .steps { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:13px; }
    .step { background:#f7f9fb; border:1px solid var(--line); border-radius:12px; padding:16px; }
    .step .number { background:#dbe8f0; color:var(--blue); display:inline-flex; align-items:center;
      justify-content:center; width:29px; height:29px; border-radius:50%; font-weight:750; }
    .step strong { display:block; margin:11px 0 5px; }
    .step p { font-size:13px; color:var(--muted); margin:0; }
    .mock { margin-top:13px; border:1px solid #c4d2dc; border-radius:9px; overflow:hidden;
      background:#e8eef3; min-height:107px; font-size:12px; }
    .mockbar { background:#303a47; color:white; display:flex; justify-content:space-between; padding:7px 10px; }
    .focus { color:#fff; background:#587b96; border-radius:5px; padding:2px 7px; }
    .mockmenu { margin:7px 12px 8px auto; background:white; border:1px solid #cad6df;
      box-shadow:0 2px 7px #253d5120; border-radius:7px; width:84%; padding:8px; }
    .mockline { padding:5px 8px; border-radius:5px; } .mockline.selected { background:#d9e8f1; color:#284b67; font-weight:700; }
    .key { display:inline-block; border:1px solid #b9cbd8; background:#f3f6f8; box-shadow:0 2px 0 #d2dce2;
      border-radius:5px; padding:1px 7px; white-space:nowrap; color:#304b60; font-weight:650; }
    .tip { margin-top:14px; background:#eef4f8; border-radius:9px; padding:12px 14px; font-size:14px; }
    .app-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:14px; }
    .app-group { border:1px solid var(--line); border-radius:12px; overflow:hidden; }
    .app-group h3 { background:#edf2f6; padding:13px 15px; margin:0; }
    table { border-collapse:collapse; width:100%; } td { padding:11px 13px; border-top:1px solid #ecf0f3; vertical-align:middle; }
    td strong { font-size:14px; } td small { display:block; color:var(--muted); font-size:12px; margin-top:1px; }
    .status-cell { text-align:right; width:145px; } .pill { font-size:11px; font-weight:650;
      border-radius:999px; padding:5px 9px; white-space:nowrap; }
    .ready { background:#e0efe6; color:var(--green); }
    .optional { background:#eff2f5; color:#576a79; }
    .pairs { display:grid; grid-template-columns:repeat(2,1fr); gap:10px 20px; }
    .pairs div { padding:9px 0; border-bottom:1px solid var(--line); font-size:14px; }
    .pairs b { color:var(--blue); }
    details { margin-top:12px; padding:13px 16px; border:1px solid var(--line); border-radius:10px; }
    summary { font-weight:700; cursor:pointer; color:var(--blue); }
    code { overflow-wrap:anywhere; } footer { text-align:center; color:#667c8b; font-size:12px; padding:12px 0 36px; }
    @media(max-width:720px) { .summary,.steps,.app-grid,.pairs {grid-template-columns:1fr;} .panel {padding:18px;} .status-cell{width:135px;} }
    @media print { body{background:white;} .panel,.stat{box-shadow:none;break-inside:avoid;} .hero{print-color-adjust:exact;} }
  </style>
</head>
<body>
  <header class="hero"><div class="wrap">
    <div class="brand">NAMHH / UNIVERSAL LINUX OFFICE KIT</div>
    <h1>Chào mừng bạn đến với Ubuntu!</h1>
    <p>${STATUS_TITLE}. ${STATUS_NOTE}</p>
    <div class="meta">${OS_NAME} · Xuất báo cáo ${GENERATED} · Design: huynhoainam@gmail.com</div>
  </div></header>
  <main class="wrap">
    <div class="summary">
      <div class="stat"><strong>${READY}/${TOTAL}</strong><span>Ứng dụng/tiện ích phát hiện sẵn sàng</span></div>
      <div class="stat"><strong>${OFFICE_COUNT}</strong><span>Bộ Office đang có (WPS ưu tiên)</span></div>
      <div class="stat"><strong>3 bước</strong><span>Đăng xuất, đặt VNI, mở Zalo</span></div>
    </div>
    ${ALERT}
    <section class="panel">
      <h2>Việc nên làm ngay sau khi cài</h2>
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
      <h2>Minh họa cách đăng xuất (Log Out) trên Ubuntu</h2>
      <p class="sub">Đây là sơ đồ minh họa giao diện GNOME; vị trí/biểu tượng có thể hơi khác theo phiên bản Ubuntu.</p>
      <div class="steps">
        <div class="step"><span class="number">1</span><strong>Bấm góc trên bên phải</strong>
          <p>Tìm khu vực Wi‑Fi, âm lượng, pin ở thanh trên cùng.</p>
          <div class="mock"><div class="mockbar"><span>Activities</span><span class="focus">Wi‑Fi · Sound · Power</span></div>
          <div style="text-align:right;padding:32px 13px 8px;color:#47647a">↑ Bấm cụm biểu tượng này</div></div></div>
        <div class="step"><span class="number">2</span><strong>Mở mục nguồn</strong>
          <p>Trong bảng hiện ra, chọn <b>Power Off / Log Out</b> (Nguồn / Đăng xuất).</p>
          <div class="mock"><div class="mockbar"><span>Quick Settings</span><span>×</span></div>
          <div class="mockmenu"><div class="mockline">Wi‑Fi &nbsp; Âm lượng</div><div class="mockline selected">Power / Nguồn →</div></div></div></div>
        <div class="step"><span class="number">3</span><strong>Chọn Log Out / Đăng xuất</strong>
          <p>Xác nhận nếu hệ thống hỏi, sau đó đăng nhập lại bằng mật khẩu Ubuntu.</p>
          <div class="mock"><div class="mockbar"><span>Power</span><span>×</span></div>
          <div class="mockmenu"><div class="mockline selected">↪ &nbsp; Log Out… / Đăng xuất</div><div class="mockline">⟲ &nbsp; Restart… / Khởi động lại</div></div></div></div>
      </div>
      <div class="tip"><strong>Lưu ý:</strong> Đăng xuất sẽ đóng các ứng dụng đang mở. <b>Khóa màn hình (Lock)</b> không thay thế việc đăng xuất. Nếu Zalo quay đăng nhập quá lâu, chọn <b>Restart / Khởi động lại</b> ở bước 3.</div>
    </section>
    <section class="panel" id="vni">
      <h2>Gõ tiếng Việt kiểu VNI như trên Windows</h2>
      <ol>
        <li>Mở <b>Settings / Cài đặt → Keyboard / Bàn phím → Input Sources / Nguồn nhập</b>. Chọn hoặc thêm <b>Vietnamese (Unikey)</b>.</li>
        <li>Nhấn <span class="key">Super</span> (phím Windows) + <span class="key">Space</span> để chuyển sang Unikey.</li>
        <li>Bấm biểu tượng <b>VI / Unikey</b> trên thanh trên cùng → tùy chọn <b>Preferences / Cấu hình</b> → chọn <b>Input method: VNI</b> và <b>Character set: Unicode</b>. Đối với Linux Mint/Cinnamon, mở <b>Fcitx 5 Configuration → Unikey → Configure → VNI</b>.</li>
        <li>Mở Text Editor/WPS, thử <span class="key">tie6ng1 vie6t5</span> → <b>tiếng việt</b>. Phím <b>1</b> là sắc, <b>2</b> huyền, <b>3</b> hỏi, <b>4</b> ngã, <b>5</b> nặng, <b>6</b> â/ê/ô, <b>7</b> ơ/ư, <b>8</b> ă, <b>9</b> đ.</li>
      </ol>
      <div class="tip">Nếu chưa thấy Unikey sau khi cài, hãy <a href="#logout">đăng xuất rồi đăng nhập lại</a>. Đừng cài hai bộ gõ chạy đồng thời; bộ cài đã chọn IBus cho Ubuntu GNOME và Fcitx5 cho Cinnamon.</div>
    </section>
    <section class="panel" id="zalo">
      <h2>Zalo: quét QR rồi hiện “Đang đăng nhập…” quá lâu?</h2>
      <ol>
        <li>Dùng điện thoại mở Zalo, quét <b>mã QR mới nhất</b> trên ứng dụng Zalo Linux và xác nhận yêu cầu đăng nhập trên điện thoại nếu có.</li>
        <li>Nếu ứng dụng cứ xoay sau vài phút, hãy <b>đóng hẳn Zalo</b>, lưu công việc, chọn <b>Restart / Khởi động lại</b> trong menu nguồn của Ubuntu (xem minh họa phía trên).</li>
        <li>Đăng nhập lại Ubuntu, mở <b>Zalo Linux</b> từ danh sách ứng dụng, quét lại mã QR mới. Không cần xóa dữ liệu chat hoặc cài lại ứng dụng.</li>
        <li>Nếu vẫn không vào được, có thể do kết nối mạng/proxy doanh nghiệp chặn bước xác thực. Hãy nhờ IT kiểm tra; không tự tắt bảo vệ mạng.</li>
      </ol>
      <div class="tip">Flameshot: bấm <span class="key">Ctrl</span> + <span class="key">Alt</span> + <span class="key">S</span> để chọn vùng màn hình. Lần đầu trên Wayland có thể hiện hộp thoại cho phép chia sẻ/chụp màn hình.</div>
    </section>
    <section class="panel">
      <h2>Ứng dụng của bạn và công dụng</h2>
      <p class="sub">Dựa trên ứng dụng thực tế phát hiện ở thời điểm tạo báo cáo. “Chưa cài / tùy chọn” không nhất thiết là lỗi; bạn không cần mọi ứng dụng trong danh sách.</p>
      <div class="app-grid">${APP_TABLES}</div>
    </section>
    <section class="panel">
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
      <h2>Chi tiết cài đặt</h2>
      <p class="sub">Phần này dành cho IT nếu cần hỗ trợ. Người dùng thông thường không phải thao tác gì với các đường dẫn.</p>
      <details><summary>Xem cảnh báo và thông tin kỹ thuật</summary>
        <ul>${DETAILS}</ul>
        <p><b>Báo cáo dạng văn bản:</b> <code>${LOG_PATH}</code></p>
        <p><b>Bản sao cấu hình trước khi sửa:</b> <code>${BACKUP_PATH}</code></p>
      </details>
    </section>
  </main>
  <footer>NAMHH · Thiết kế bởi huynhoainam@gmail.com · Báo cáo offline, không gửi dữ liệu lên Internet</footer>
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

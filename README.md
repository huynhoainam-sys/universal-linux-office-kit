# Universal Linux Office Kit

Một bộ bootstrap **1 click** cho Ubuntu và Linux Mint mới cài. Mục tiêu là đưa máy về trạng thái dùng được cho văn phòng, học tập và làm việc hằng ngày, nhưng vẫn giữ quyền kiểm soát: không chạy lệnh mơ hồ từ Internet, không xóa ứng dụng sẵn có, không tự thêm kho bên thứ ba.

## Chạy nhanh

```bash
git clone https://github.com/huynhoainam-sys/universal-linux-office-kit.git
cd universal-linux-office-kit
chmod +x setup.sh
./setup.sh
```

Hoặc tải một file launcher rồi xem trước:

```bash
curl -fsSL https://raw.githubusercontent.com/huynhoainam-sys/universal-linux-office-kit/main/setup.sh -o setup.sh && chmod +x setup.sh && ./setup.sh --profile full
```

Lệnh đầy đủ, tự bỏ qua hỏi xác nhận:

```bash
curl -fsSL https://raw.githubusercontent.com/huynhoainam-sys/universal-linux-office-kit/main/setup.sh -o setup.sh && chmod +x setup.sh && ./setup.sh --profile full --yes
```

Các profile:

- `minimal`: sửa APT/dpkg, cập nhật hệ thống, công cụ nén, mạng, font và in ấn.
- `office`: minimal + LibreOffice, PDF, scan, media, browser integration.
- `full`: office + development, remote desktop, Flatpak, Chrome, Edge, VS Code, Docker và Zoom từ nguồn chính thức.

Tùy chọn an toàn: `--dry-run`, `--profile`, `--no-reboot`, `--skip-flatpak`, `--skip-third-party`, `--report PATH`, `--yes`.

## App được cài và công dụng

### Nhóm nền tảng — mọi profile

| App/gói | Công dụng |
|---|---|
| `curl`, `wget`, `git` | Tải dữ liệu, quản lý mã nguồn và cài đặt từ Internet |
| `unzip`, `zip`, `p7zip-full`, `rsync` | Giải nén, nén và sao chép dữ liệu |
| `jq`, `bash-completion`, `htop`, `ncdu` | Công cụ terminal, xem tiến trình và dung lượng đĩa |
| `network-manager`, `dnsutils` | Quản lý mạng và chẩn đoán DNS |
| `ufw` | Tường lửa cơ bản; script bật mặc định |
| `ca-certificates`, `gpg` | HTTPS và xác minh chữ ký kho phần mềm |

### Văn phòng — profile `office` và `full`

| App/gói | Công dụng |
|---|---|
| LibreOffice Writer/Calc/Impress | Thay Word/Excel/PowerPoint cho tài liệu, bảng tính và trình chiếu |
| `libreoffice-l10n-vi`, `libreoffice-help-vi` | Giao diện và trợ giúp tiếng Việt |
| Hunspell/Hyphen/MyThes tiếng Việt | Kiểm tra chính tả, ngắt dòng và từ điển |
| Evince, Poppler | Đọc, trích xuất và xử lý PDF |
| Simple Scan, CUPS, System Config Printer | Scan và cài máy in |
| VLC, FFmpeg | Phát và chuyển đổi âm thanh/video |
| GIMP, ImageMagick | Chỉnh sửa và xử lý ảnh |
| Noto, Liberation fonts | Font Unicode/CJK và tương thích tài liệu |

### Làm việc chuyên sâu — profile `full`

| App | Công dụng | Nguồn |
|---|---|---|
| Google Chrome | Trình duyệt, họp web, dịch vụ Google | `.deb` chính thức; chỉ x86_64 |
| Microsoft Edge | Trình duyệt, Microsoft 365 web, Teams web | Kho Microsoft chính thức |
| Visual Studio Code | Lập trình, chỉnh sửa code, terminal và extension | Kho Microsoft chính thức |
| Docker Engine + Compose | Container, môi trường dev và triển khai dịch vụ | Kho Docker trên Ubuntu; gói distro trên Mint |
| Zoom | Họp trực tuyến | `.deb` chính thức; chỉ x86_64 |
| WPS Office | Writer, Spreadsheet, Presentation và PDF; gần giao diện Microsoft Office | `.deb` chính thức từ WPS; chỉ x86_64 |
| Remmina + RDP/VNC | Điều khiển máy Windows/Linux từ xa | Kho Ubuntu/Mint |
| OpenSSH client | Kết nối server và copy file qua SSH | Kho Ubuntu/Mint |
| Python, pip, venv, build-essential | Lập trình, automation và biên dịch package | Kho Ubuntu/Mint |
| Flatpak + Flathub | Cài thêm ứng dụng desktop sandbox | Flatpak/Flathub |

### Các app chưa tự cài

- Microsoft Office desktop: không có bản Linux native được Microsoft hỗ trợ; dùng LibreOffice hoặc Microsoft 365 web.
- Zalo native: không có package Linux chính thức ổn định; không giả nhận là đã cài.
- AnyDesk, VirtualBox, Discord, Slack, OBS, Kdenlive: có thể bổ sung thành module riêng sau khi chốt danh sách và chính sách nguồn của máy.

Sau khi chạy, xem `setup-report.txt` để biết app nào PASS, app nào WARN/FAIL. App tùy chọn không có trên kiến trúc hoặc distro sẽ được ghi rõ, không làm giả trạng thái thành công.

## Thiết kế

- Chạy được trên Ubuntu LTS và Linux Mint dựa trên Ubuntu.
- Một launcher duy nhất, nhưng mỗi nhóm chức năng là một module có thể bật/tắt.
- Idempotent: chạy lại không cài lặp và không ghi đè cấu hình người dùng.
- Có bước repair cho trạng thái cài mới lỗi: `dpkg --configure -a`, `apt-get -f install`, khóa APT stale và cập nhật chỉ khi đã xác nhận.
- App bên thứ ba được lấy từ kho/URL chính thức của Google, Microsoft, Docker và Zoom; có thể bỏ qua bằng `--skip-third-party`.
- Mỗi lệnh được ghi vào log; cuối lượt tạo report PASS/WARN/FAIL.

## Giới hạn có chủ ý

Microsoft Office desktop không có bản Linux native được Microsoft hỗ trợ. Kit cài LibreOffice mặc định; WPS/Office qua Wine/VM và Zalo native không được tự cài vì không có kênh Linux chính thức ổn định để bảo đảm thành công.

File checksum được tham khảo trong thiết kế: `universal-linux-office-kit-v7.3-pro-max-report-printer-optional.sha256` ghi hash `9c7ebdf1af1131eacbf9bd764016e52ce1f4d2c9891bd02274fe7ff185204a28` cho ZIP trỏ tới `/mnt/data/...`. ZIP không có trong máy hiện tại nên chưa thể xác minh hash thực tế.

## Kiểm tra

Trên Linux chạy:

```bash
./tests/test_static.sh
./setup.sh --dry-run --profile full --no-reboot
```

Runtime installer cần Ubuntu/Mint thật hoặc VM; không tuyên bố test cài package chỉ từ Windows.

## Tham khảo

- `tprasadtp/ubuntu-post-install`: cấu hình YAML và profile phong phú.
- `franckferman/ubuntu-post-install`: module, retry, dry-run và nhóm extras.
- `rothgar/ansible-workstation`, `jdauphant/ansible-ubuntu-desktop`: idempotency và vai trò tách biệt.
- `marcinbojko/linux_mint`: các khác biệt riêng của Mint.
- `canonical/ubuntu-desktop-provision`: quy trình provisioning chính thức của Ubuntu.

Kit này lấy ý tưởng, không nhúng mã hay tải payload của các repo trên.

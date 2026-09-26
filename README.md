# Universal Linux Office Kit

Một bộ bootstrap **1 click** cho Ubuntu và Linux Mint mới cài. Mục tiêu là đưa máy về trạng thái dùng được cho văn phòng, học tập và làm việc hằng ngày, nhưng vẫn giữ quyền kiểm soát: không chạy lệnh mơ hồ từ Internet, không xóa ứng dụng sẵn có, không tự thêm kho bên thứ ba.

## Chạy nhanh

```bash
git clone https://github.com/huynhoainam-sys/universal-linux-office-kit.git
cd universal-linux-office-kit
chmod +x setup.sh
./setup.sh
```

Chạy bằng tài khoản desktop thường (không dùng `sudo ./setup.sh`); script tự gọi sudo cho những bước cài gói. Điều này giữ phím tắt, font và launcher trong đúng tài khoản người dùng.

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
- `office`: minimal + LibreOffice, PDF, scan, media, browser integration và GenOffice trên máy tương thích.
- `full`: office + development, remote desktop, Flatpak, Chrome, Edge, VS Code, Docker, Zoom và Zalo Linux bản full.

Tùy chọn: `--dry-run`, `--profile`, `--no-reboot`, `--skip-flatpak`, `--skip-third-party`, `--canon-ufrii-archive PATH`, `--report PATH`, `--yes`.

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
| GenOffice | Bộ soạn thảo AI cho DOCX/XLSX/PPTX/PDF; tải `.deb` từ release chính thức trên Ubuntu/Mint amd64 với glibc 2.34+. Bỏ qua nếu đã cài hoặc dùng `--skip-third-party`. |
| `libreoffice-l10n-vi`, `libreoffice-help-vi` | Giao diện và trợ giúp tiếng Việt |
| Hunspell/Hyphen/MyThes tiếng Việt | Kiểm tra chính tả, ngắt dòng và từ điển |
| Evince, Poppler | Đọc, trích xuất và xử lý PDF |
| Simple Scan, CUPS, System Config Printer | Scan và cài máy in |
| IBus Unikey / Fcitx5 Unikey | Bộ gõ tiếng Việt: Cinnamon dùng Fcitx5; desktop khác dùng IBus. Sau cài cần thêm Unikey trong Input Sources/Input Method và đăng nhập lại. |
| Canon UFR II/UFRII LT | Driver in Canon tùy chọn; tải đúng gói `.tar.gz` chính thức của model rồi truyền `--canon-ufrii-archive PATH`. Script cài các gói Debian đúng kiến trúc; thêm máy in sau trong cấu hình máy in. |
| VLC, FFmpeg | Phát và chuyển đổi âm thanh/video |
| GIMP, ImageMagick | Chỉnh sửa và xử lý ảnh |
| Flameshot | Chụp vùng màn hình; trên GNOME tự gán `Ctrl+Shift+S` chạy `flameshot gui` sau khi cài. Desktop khác cần đặt phím tắt trong Keyboard Shortcuts. |
| Noto, Liberation fonts | Font Unicode/CJK và tương thích tài liệu |
| Carlito, Caladea và font aliases | Thay thế gần kích thước Calibri/Cambria; ánh xạ các font Office phổ biến trong tài khoản người dùng |
| Thunderbird, PDF Arranger | Email desktop và sắp xếp trang PDF |
| SMB/CIFS, OpenVPN | Truy cập file share và kết nối VPN khi có cấu hình |

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
| Inxi, GParted, GNOME Disks, Nmap, ethtool, iperf3, smartmontools | Chẩn đoán máy và mạng | Kho Ubuntu/Mint |
| Flatpak + Flathub | Cài thêm ứng dụng desktop sandbox | Flatpak/Flathub |
| Zalo Linux (full) | Nhắn tin qua AppImage cộng đồng, tạo launcher và icon trong tài khoản đang chạy | Installer của `huynhoainam-sys/zalo-linux-chat-kit`; AppImage từ `VN-Linux-Family/zalo-for-linux` |

Zalo được tải từ đúng URL `https://raw.githubusercontent.com/huynhoainam-sys/zalo-linux-chat-kit/main/install-zalo-linux.sh`: ưu tiên `curl -fsSL`, nếu lỗi hoặc chưa có curl thì dùng `wget -qO-`. Kit lưu vào file tạm, kiểm tra tải thành công rồi chạy với `ZALO_VARIANT=full`.

### Các app chưa tự cài

- Microsoft Office desktop: không có bản Linux native được Microsoft hỗ trợ; dùng LibreOffice hoặc Microsoft 365 web.
- AnyDesk, VirtualBox, Discord, Slack, OBS, Kdenlive: có thể bổ sung thành module riêng sau khi chốt danh sách và chính sách nguồn của máy.

Sau khi chạy, xem `setup-report.txt` để biết app nào PASS, app nào WARN/FAIL. App tùy chọn không có trên kiến trúc hoặc distro sẽ được ghi rõ, không làm giả trạng thái thành công.
Chạy `bash doctor.sh` để kiểm tra lại trạng thái ứng dụng, bộ gõ, CUPS và Canon bất cứ lúc nào; báo cáo được lưu trong `doctor-report.txt`.
Nếu bộ gõ mất sau cập nhật hoặc đổi desktop, chạy `./setup.sh --fix-unikey` bằng tài khoản đang đăng nhập, sau đó đăng xuất và đăng nhập lại. Với Fcitx5, script giữ profile cũ, thêm engine Unikey nếu thiếu và chọn Fcitx5 qua `im-config`; với GNOME/IBus, script thêm Unikey vào Input Sources khi xác định được engine. Không tạo watchdog chạy nền hoặc ghi đè toàn bộ cấu hình người dùng.

### Cài Canon UFR II

Tra model máy in trên [Canon Việt Nam](https://vn.canon/en/support), tải gói **UFR II/UFRII LT Printer Driver for Linux** dành cho model của bạn (ví dụ bản V6.40), rồi chạy:

```bash
./setup.sh --profile office --canon-ufrii-archive "$HOME/Downloads/linux-UFRII-drv-v640-m17n-06.tar.gz"
```

Gói UFR II chỉ cài khi cung cấp archive; tránh áp nhầm driver cho máy Canon dùng CAPT hoặc driver khác. Script không tự thêm máy in vì cần địa chỉ IP/USB và model cụ thể.

### Chống cài trùng

APT tự giữ các gói đã cài. GenOffice, Chrome, WPS và Zoom bỏ qua tải `.deb` nếu đã có ứng dụng; bộ gõ giữ nguyên IBus/Fcitx5 Unikey đang dùng. Zalo hiện có nhưng chưa được kit xác nhận là bản full sẽ được cập nhật đúng một lần; các lần chạy sau bỏ qua. Canon UFR II bỏ qua khi driver tương ứng đã cài. Kit không gọi lại các script rời trong bộ cũ, không tạo thêm launcher Zalo Web/PWA hay cài Bottles/AnyDesk mặc định.

## Thiết kế

- Chạy được trên Ubuntu LTS và Linux Mint dựa trên Ubuntu.
- Một launcher duy nhất, nhưng mỗi nhóm chức năng là một module có thể bật/tắt.
- Idempotent: chạy lại không cài lặp và không ghi đè cấu hình người dùng.
- Có bước repair cho trạng thái cài mới lỗi: `dpkg --configure -a`, `apt-get -f install`, khóa APT stale và cập nhật chỉ khi đã xác nhận.
- App bên thứ ba được lấy từ kho/URL chính thức của GenOffice, Google, Microsoft, Docker và Zoom; có thể bỏ qua bằng `--skip-third-party`.
- Mỗi lệnh được ghi vào log; cuối lượt tạo report PASS/WARN/FAIL.

## Giới hạn có chủ ý

Microsoft Office desktop không có bản Linux native được Microsoft hỗ trợ. Kit cài LibreOffice mặc định. Zalo Linux trong profile `full` là bản AppImage cộng đồng, không phải ứng dụng Linux chính thức của Zalo. Có thể bỏ qua cùng các app bên thứ ba bằng `--skip-third-party`. Installer Zalo tải mã từ nhánh `main` lúc chạy, nên nội dung có thể thay đổi theo thời gian; kiểm tra nguồn trước khi triển khai hàng loạt.

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

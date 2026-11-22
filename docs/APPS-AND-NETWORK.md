# NAMHH Office Kit · Kiểm kê ứng dụng và tải qua proxy

Đây là danh sách nhóm app thực tế trong `setup.sh` (không phải danh sách quảng cáo). Bộ cài bỏ qua ứng dụng đã có; ứng dụng tùy chọn lỗi không chặn Zalo, Flameshot hay Unikey. Kiểm tra máy cụ thể bằng `bash doctor.sh` và `setup-report.html`.

## 1. Các profile

| Profile | Nhóm ứng dụng / tính năng | Đường cung cấp |
|---|---|---|
| `minimal` | curl, wget, git, zip/7z, rsync, jq, htop, ncdu, DNS, NetworkManager, UFW (chỉ cài, **không tự bật**), SMB, OpenVPN | Kho APT đang cấu hình |
| `office` | Nhóm minimal; WPS ưu tiên (tối đa 2 bộ Office), LibreOffice hoặc GenOffice; IBus Unikey GNOME / Fcitx5 Unikey Cinnamon; Flameshot; PDF, scan, CUPS, Thunderbird, font tiếng Việt, VLC/FFmpeg | APT, WPS .deb, GenOffice release có SHA-256 |
| `desktop` (mặc định) | Nhóm office; **Zalo Linux**, **Outlook Microsoft 365 (Web)**, sao lưu Backups, chia sẻ ổ Windows/NAS, NTFS/exFAT, Remmina, trình giải nén, Files preview, Disk Usage, Disks, Pinta (nếu có), máy tính GNOME | APT + Zalo AppImage; Outlook không tải binary |
| `full` | Nhóm desktop; Chrome, Edge, VS Code, Zoom, Docker, Flatpak, công cụ phát triển, network/diagnostics | Trang hãng HTTPS, kho APT có chữ ký, Flathub |

Tính năng `--windows-like` (tùy chọn): bổ sung nút **minimize / maximize / close** trên thanh tiêu đề cửa sổ GNOME. Có bản sao cấu hình trước khi sửa. Không chạy trên Cinnamon; không tự bật firewall, Remote Desktop, VPN, tự tạo bản sao lưu hay thay giao diện người dùng khi chưa chọn.

## 2. Hai kênh tải và đường dự phòng

| Thành phần | Kênh chính | Kênh dự phòng | Xác minh và giới hạn |
|---|---|---|---|
| Gói Ubuntu, Flameshot, Unikey, LibreOffice, CUPS | APT / mirror máy đang dùng | Sau lỗi nhóm: thử từng gói; khi `apt update` bị chặn, ưu tiên cache | Không tự đổi nguồn APT công ty, không bỏ xác minh chữ ký APT |
| WPS Office | `curl` từ gói .deb chính thức đã ghim | `wget` cùng HTTPS; mirror HTTPS do IT cấu hình `ULOK_WPS_MIRROR_URL` | **Bắt buộc** khớp SHA-256 pin; không cài file khác phiên bản |
| Zalo Linux | GitHub API / release có digest | Release pin theo phiên bản; proxy URL / AppImage offline do người dùng cung cấp | Mọi file mirror phải khớp SHA-256 + header ELF; giữ app cũ nếu tải lỗi |
| GenOffice | GitHub release mới nhất có SHA-256 | Release chính thức đã ghim khi API bị 403 | Không cài nếu thiếu SHA-256 hợp lệ hoặc checksum sai |
| Chrome, Zoom (profile full) | `curl` qua HTTPS tên miền hãng | `wget` qua cùng nguồn HTTPS | Không dùng mirror không xác minh; hai công cụ không vượt được chặn domain tầng mạng |
| Edge / VS Code / Docker | Kho APT chính thức của hãng, signed repository | Cache/mirror APT sẵn có theo cấu hình máy | Không tự tạo mirror hoặc bỏ xác minh chữ ký |
| Outlook Web | `https://outlook.office.com/mail/` | Edge/Chrome → Firefox → trình duyệt hệ thống | Không tải `.deb`, không lưu token/mật khẩu và không tự đăng nhập |

`curl` và `wget` là **hai công cụ/luồng tải dự phòng**, không phải hai đường Internet độc lập. Nếu doanh nghiệp chủ động chặn một domain, cần dùng nguồn được IT cho phép hoặc tệp offline đã xác minh. Bộ cài không tự tắt proxy hay thiết lập đường vòng trái chính sách.

### Ví dụ WPS mirror nội bộ

IT chuẩn bị bản `.deb` **giống hệt** file WPS đã ghim trong `setup.sh` (cùng checksum) trên một máy chủ HTTPS tin cậy:

```bash
ULOK_WPS_MIRROR_URL='https://office-mirror.example.invalid/wps-office_11.1.0.11723.XA_amd64.deb' \
  bash setup.sh --profile desktop --yes
```

URL trong ví dụ là địa chỉ mẫu, không phải mirror đang hoạt động. Không dùng địa chỉ này khi cài thật.

## 3. Outlook Ubuntu

- Microsoft xác nhận Outlook on the web hoạt động trên Linux trong Firefox hoặc Chrome, có thể có một số giới hạn tính năng. [Trình duyệt hỗ trợ](https://support.microsoft.com/en-us/outlook/supported-browsers-for-outlook-on-the-web-and-outlook-com).
- Có thể cài Outlook Web thành PWA bằng Edge/Chrome trong trình duyệt. [Hướng dẫn Outlook PWA chính thức](https://support.microsoft.com/en-us/outlook/use-the-web-version-of-outlook-like-a-desktop-app).
- `ulok-outlook-web` chỉ tạo launcher để mở website Microsoft; account do trình duyệt/người dùng quản lý. `bash setup.sh --fix-outlook --yes` sửa riêng shortcut, không cài lại hệ điều hành.

## 4. Kiểm thử lỗi độc lập

`bash tests/test_static.sh` có các tình huống giả lập:

1. `curl` lỗi proxy / HTTP 403 → `wget` tải được và checksum đúng.
2. Cả hai công cụ cùng bị chặn từ nguồn chính → HTTPS mirror cấu hình trước, **chỉ nếu checksum pin đúng**.
3. File sai SHA-256 từ tất cả nguồn → từ chối cài, không gọi APT install.
4. Một gói trong nhóm APT lỗi → hai gói khác tiếp tục cài; nếu mạng offline chỉ thử gói có sẵn trong cache.
5. Unikey mất hoặc GNOME GSettings khởi động trễ → thử phục hồi, không đổi kiểu gõ đang dùng.
6. Flameshot GNOME Wayland / shortcut cũ / shortcut cá nhân → không ghi đè tùy chỉnh không thuộc Office Kit.
7. Outlook launcher tạo, chạy, tái chạy không trùng; launcher cá nhân được giữ nguyên.
8. Ứng dụng phụ lỗi và một app thiết yếu lỗi → vẫn chạy những app khác, ghi rõ WARN/FAIL.

QA GitHub Actions dùng Ubuntu 22.04 và 24.04. Đây là kiểm tra syntax, **dry-run** và mô phỏng; còn phải nghiệm thu máy desktop thật cho Wayland portal, Canon/driver, tài khoản Outlook và đăng nhập Zalo.

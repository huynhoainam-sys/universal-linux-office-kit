# Universal Linux Office Kit — NAMHH

Bộ cài đơn giản cho người **chuyển từ Windows sang Ubuntu / Linux Mint**. Cài các ứng dụng cần dùng, tránh cài trùng và tự mở trang hướng dẫn tiếng Việt sau khi hoàn tất.

## Cài nhanh: chỉ cần 1 lệnh

Mở **Terminal** bằng `Ctrl + Alt + T`, dán nguyên dòng sau và nhấn **Enter**. Nếu Ubuntu hỏi mật khẩu, nhập mật khẩu đăng nhập máy (khi gõ sẽ không hiện dấu `*`, đây là bình thường).

```bash
bash -c 'set -Eeuo pipefail; command -v git >/dev/null || { sudo apt-get update && sudo apt-get install -y git; }; repo="$HOME/universal-linux-office-kit"; if [[ -d "$repo/.git" ]]; then git -C "$repo" pull --ff-only || echo "[WARN] GitHub bị chặn; dùng bản repo đã có"; else git clone --depth 1 https://github.com/huynhoainam-sys/universal-linux-office-kit.git "$repo"; fi; bash -n "$repo/setup.sh"; bash "$repo/setup.sh" --profile desktop --yes'
```

Script tự kiểm tra và bỏ qua phần đã có. Không cần tải Zalo riêng hay thêm phần mềm để hiện giao diện Terminal.

Terminal hiển thị nhận diện **NAMHH · huynhoainam@gmail.com**, từng bước có số thứ tự, % và trạng thái **Hoàn tất / Lưu ý / Cần kiểm tra**. Các dòng kỹ thuật APT/installer được ghi vào `setup.log`, chỉ hiện trong Terminal khi chọn `--verbose`. Cuối lượt tự mở báo cáo HTML có minh họa **Quick Settings → Power → Log Out… / Restart…** của Ubuntu GNOME.

Giao diện đồng bộ **NAMHH / AI Control Center**: Terminal nền navy đậm, chữ xanh lam/cyan và nhấn tím dịu; báo cáo HTML như một dashboard công nghệ với thẻ trạng thái, viền sáng nhẹ và icon SVG chuẩn. Hoàn toàn **offline**, không tải font/ảnh, CDN hoặc JavaScript; mở nhanh với Firefox hay trình duyệt mặc định Ubuntu. Mọi số liệu báo cáo lấy từ kiểm tra máy, không phải thông số trang trí. [Xem quy tắc thiết kế và thuật ngữ](docs/DESIGN-RULES.md).

| Tự chuẩn bị | Dùng để làm gì? |
|---|---|
| **WPS Office** ưu tiên, thêm LibreOffice hoặc GenOffice khi cần | Soạn Word, Excel, PowerPoint, PDF; tối đa **2 bộ Office được bổ sung** |
| **Unikey** (IBus trên Ubuntu GNOME) | Gõ tiếng Việt, tự chọn kiểu gõ trong Preferences |
| **Flameshot — Ctrl + Shift + S** | Chụp một vùng màn hình |
| **Zalo Linux** | Chat bằng ứng dụng desktop; giữ dữ liệu cũ và hỗ trợ nguồn tải thay thế có kiểm tra SHA-256 |
| **Microsoft Outlook (Web)** | Mở email Microsoft 365 bằng Edge/Chrome hoặc Firefox; có thể cài PWA từ trình duyệt |
| **Bộ tiện ích dùng hằng ngày** | Giải nén, xem trước tệp, sao lưu tài liệu, mở ổ NTFS/exFAT, chia sẻ Windows/NAS, xem dung lượng ổ đĩa, Remote Desktop |
| **Báo cáo HTML** | Tự mở trên trình duyệt; giải thích từng ứng dụng bằng tiếng Việt, có hình minh họa |

Các tiện ích nền tảng ưu tiên gói Ubuntu chính thức, **đã cài thì bỏ qua**; các gói hãng/Zalo được xử lý riêng có kiểm tra nguồn tải. Không tự bật Remote Desktop, không thay đổi firewall/VPN, không tự chọn ổ backup hay xóa phần mềm có sẵn. Các gói đồ họa nặng, Docker, môi trường lập trình và nhiều trình duyệt chỉ nằm trong `--profile full`.

**Để giống Windows hơn:** nếu muốn có đủ nút **thu nhỏ / phóng to / đóng** trên GNOME, thêm `--windows-like` khi cài profile `desktop`. Đây là tùy chọn chủ động, không thay đổi bố cục cửa sổ mặc định của người đã quen Ubuntu. Kit cũng bổ sung thư mục người dùng, công cụ giải nén, máy tính, xem nhanh tệp và Pinta (Paint tương tự Windows) khi kho APT cung cấp gói phù hợp.

## Khi cài xong, làm 3 việc

1. **Lưu công việc**, bấm góc trên bên phải màn hình → nút nguồn **⏻** → **Log Out / Đăng xuất** → đăng nhập lại. Đây là bước giúp bộ gõ áp dụng cấu hình mới.
2. **Kiểm tra Unikey:** bộ cài đưa **Vietnamese (Unikey)** lên đầu danh sách và ưu tiên sau khi đăng nhập lại Ubuntu GNOME. Nếu chưa bật, nhấn **Super (phím Windows) + Space** để chọn. Bấm chỉ báo ngôn ngữ trên thanh trên cùng → **More settings… / Preferences** để tùy chỉnh **kiểu gõ**; bảng mã nên để **Unicode**.
3. **Mở Zalo, quét QR** và xác nhận trên điện thoại. Nếu cứ quay **“Đang đăng nhập…”** sau vài phút, lưu công việc → **Restart / Khởi động lại máy** → mở Zalo và quét mã mới. Không xóa dữ liệu chat.

Trình duyệt sẽ **tự mở `setup-report.html`** sau khi cài. Trong đó có hướng dẫn đăng xuất/khởi động lại, **mô phỏng bấm từng bước bật Unikey và mở phần tùy chỉnh kiểu gõ** bằng biểu tượng GNOME/IBus, danh sách ứng dụng thực tế và công dụng. Bấm vào các bước để mở màn hình minh họa; lựa chọn trong trang chỉ để tập thao tác, không đổi máy. Có thể mở lại bằng cách nhấp tệp `setup-report.html` trong thư mục `universal-linux-office-kit` ở **Home**.

**UniKey tự phục hồi:** Trên Ubuntu GNOME, kit ưu tiên Unikey trong **Input Sources** và **mru-sources** (thứ tự nguồn nhập sử dụng gần đây) mà không xóa các bàn phím khác. Không ép kiểu gõ cá nhân đã chọn; `namhh-unikey-guard` chỉ thêm lại mục bị mất, có thử lại khi dịch vụ cấu hình GNOME chưa sẵn sàng, không đổi thiết lập cá nhân khi Unikey vẫn còn. Nếu đang mất UniKey, mở Terminal chạy `bash "$HOME/universal-linux-office-kit/setup.sh" --fix-unikey --yes`, rồi **Log Out** và vào lại. Không tự tắt IBus, không chạy hai framework cùng lúc.

> **Lưu ý:** Nếu máy đã có 2–3 bộ Office khác nhau, kit không tự gỡ phần mềm/dữ liệu. Nếu mạng cơ quan chặn GitHub hoặc nguồn tải, bộ cài ghi cảnh báo; bạn có thể nhờ IT kiểm tra. Trên GNOME Wayland, Flameshot đôi khi cần cho phép quyền chụp màn hình lần đầu.

**Xem ảnh thử trên Ubuntu 24.04:** vào [GitHub Actions — Ubuntu desktop kit checks](https://github.com/huynhoainam-sys/universal-linux-office-kit/actions/workflows/tests.yml), mở lượt chạy mới nhất → **Artifacts** → tải `namhh-ubuntu-24.04-preview`. Tệp ZIP có 3 ảnh Terminal tiến trình và ảnh báo cáo HTML. Đây là bản chạy **dry-run trên Ubuntu thật**, không phải bằng chứng WPS/Zalo đã đăng nhập trên máy người dùng.

**QA:** bài test tự động chạy trên Ubuntu 22.04/24.04, mô phỏng lỗi proxy APT, một gói bị chặn nhưng gói khác vẫn cài, tải file bằng hai kênh `curl`/`wget`, file sai checksum, thiếu ứng dụng phụ, lỗi thành phần thiết yếu, UniKey bị mất sau đăng nhập, GNOME GSettings khởi động chậm, Flameshot Wayland, Zalo đã cài, Outlook Web và thiết lập Windows-like. Lỗi phụ chỉ ghi cảnh báo; ba ứng dụng thiết yếu tiếp tục độc lập. Không thể bảo đảm Zalo đăng nhập thành công nếu kết nối/proxy doanh nghiệp chặn bước xác thực.

---

<details>
<summary><strong>Tài liệu dành cho IT · cài nâng cao, cập nhật, sao lưu và xử lý sự cố</strong></summary>

Các mục bên dưới dành cho người cần kiểm tra kỹ thuật hoặc chọn profile cài khác. Người dùng bình thường chỉ cần làm theo **một lệnh** ở trên.

**Cập nhật Zalo riêng** (không cài toàn bộ Office Kit):

```bash
bash "$HOME/universal-linux-office-kit/setup.sh" --update-zalo --yes
```

**Chẩn đoán:** `bash "$HOME/universal-linux-office-kit/doctor.sh"` và `bash "$HOME/universal-linux-office-kit/vendor/zalo/zalo-doctor.sh"`.

**Zalo quét QR xong cứ xoay “Đang đăng nhập…”:** đóng hoàn toàn Zalo rồi chạy lệnh cập nhật bộ cài và phục hồi phiên đăng nhập (sao lưu nguyên trạng `ZaloData` trước khi thử lại):

```bash
git -C "$HOME/universal-linux-office-kit" pull --ff-only && bash "$HOME/universal-linux-office-kit/setup.sh" --fix-zalo-login --yes
```

Lệnh `--fix-zalo-login` cập nhật Zalo từ bản phát hành upstream có xác minh checksum; nếu cập nhật thất bại, script **không đụng đến dữ liệu đăng nhập**. Sau khi cập nhật thành công, nó chuyển `~/.config/ZaloData` cũ sang thư mục `ZaloData.login-backup-*` cùng phân vùng, không xóa hoặc ghi đè và sẽ in cách khôi phục. Mở Zalo, xác nhận trên điện thoại rồi quét QR lại. Nếu vẫn xoay, kiểm tra Console (`Ctrl+Shift+I`) và thử mạng khác được IT cho phép; đây cũng có thể là lỗi kết nối/xác thực. Tham khảo [lỗi upstream #13](https://github.com/VN-Linux-Family/zalo-for-linux/issues/13).

---

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/huynhoainam-sys/universal-linux-office-kit.git "$HOME/universal-linux-office-kit"
cd "$HOME/universal-linux-office-kit"
chmod +x setup.sh
./setup.sh
```

Chạy bằng tài khoản desktop thường (không dùng `sudo ./setup.sh`); script tự gọi sudo cho những bước cài gói. Điều này giữ phím tắt, font và launcher trong đúng tài khoản người dùng.

Nếu đã clone từ trước, cập nhật và chạy lại:

```bash
git -C "$HOME/universal-linux-office-kit" pull --ff-only
bash -n "$HOME/universal-linux-office-kit/setup.sh" && bash "$HOME/universal-linux-office-kit/setup.sh" --profile full
```

Lệnh cài lần đầu không cần tải trực tiếp từ `raw.githubusercontent.com`. Để luôn dùng đường dẫn cố định như hướng dẫn cập nhật ở trên, clone vào `$HOME/universal-linux-office-kit`.

Chạy tự động bỏ qua xác nhận **sau khi kiểm tra mã nguồn**:

```bash
cd "$HOME/universal-linux-office-kit"
bash -n setup.sh && bash setup.sh --profile full --yes
```

Các profile:

- `minimal`: sửa APT/dpkg, thư viện nền, công cụ mạng.
- `office`: minimal + WPS Office (ưu tiên), tối đa một bộ Office khác (mặc định LibreOffice), PDF, scan, Flameshot và bộ gõ tiếng Việt.
- `desktop` (**mặc định**): office + **Zalo, Outlook Web** + các tiện ích cần cho người chuyển từ Windows; không tự cài Docker, Chrome, Edge hay bộ công cụ lập trình.
- `full`: desktop + development, Flatpak, Chrome, Edge, VS Code, Docker, Zoom. Muốn thử Zalo bản `full` legacy: `--zalo-variant full` (phụ thuộc upstream còn phát hành bản này).

Tùy chọn: `--repair-desktop` (bao gồm Office, Outlook Web), `--fix-office`, `--fix-outlook`, `--windows-like`, `--office-secondary auto|libreoffice|genoffice`, `--fix-unikey`, `--fix-flameshot`, `--fix-zalo`, `--fix-zalo-login`, `--update-zalo`, `--zalo-variant chat|full`, `--dry-run`, `--profile`, `--no-reboot`, `--skip-flatpak`, `--skip-third-party`, `--canon-ufrii-archive PATH`, `--report PATH`, `--yes`.

## App được cài và công dụng

### Nhóm nền tảng — mọi profile

| App/gói | Công dụng |
|---|---|
| `curl`, `wget`, `git` | Tải dữ liệu, quản lý mã nguồn và cài đặt từ Internet |
| `unzip`, `zip`, `p7zip-full`, `rsync` | Giải nén, nén và sao chép dữ liệu |
| `jq`, `bash-completion`, `htop`, `ncdu` | Công cụ terminal, xem tiến trình và dung lượng đĩa |
| `network-manager`, `dnsutils` | Quản lý mạng và chẩn đoán DNS |
| `ufw` | Tường lửa cơ bản; không tự bật để tránh gián đoạn VPN/remote. Chỉ bật với `--enable-ufw` |
| `ca-certificates`, `gpg` | HTTPS và xác minh chữ ký kho phần mềm |

### Văn phòng — profile `office` và `full`

| App/gói | Công dụng |
|---|---|
| **WPS Office (ưu tiên số 1)** | Writer, Spreadsheet, Presentation, PDF, giao diện quen thuộc; `.deb` WPS trên x86_64, chỉ tải nếu chưa có |
| LibreOffice Writer/Calc/Impress (mặc định bộ thứ hai) | Word/Excel/PowerPoint; chỉ cài khi chưa có đủ hai bộ, kèm `libreoffice-l10n-vi` và `libreoffice-help-vi` |
| GenOffice (tùy chọn bộ thứ hai) | Giữ nguyên nếu đã cài; muốn cài mới thay LibreOffice dùng `--office-secondary genoffice --profile office`. Khi API lỗi 403, dùng fallback có SHA-256. Hỗ trợ amd64/glibc 2.34+. |
| Hunspell/Hyphen/MyThes tiếng Việt | Kiểm tra chính tả, ngắt dòng và từ điển |
| Evince, Poppler | Đọc, trích xuất và xử lý PDF |
| Simple Scan, CUPS, System Config Printer | Scan và cài máy in |
| IBus Unikey / Fcitx5 Unikey | Bộ gõ tiếng Việt: Cinnamon dùng Fcitx5; Ubuntu GNOME dùng IBus. Kit đưa Unikey vào vị trí ưu tiên; đăng xuất/đăng nhập lại, rồi tùy chỉnh kiểu gõ. |
| Canon UFR II/UFRII LT | Driver in Canon tùy chọn; tải đúng gói `.tar.gz` chính thức của model rồi truyền `--canon-ufrii-archive PATH`. Script cài các gói Debian đúng kiến trúc; thêm máy in sau trong cấu hình máy in. |
| VLC, FFmpeg | Phát và chuyển đổi âm thanh/video |
| GIMP, ImageMagick | Chỉnh sửa và xử lý ảnh |
| Flameshot | Chụp vùng màn hình; trên GNOME tự gán `Ctrl+Shift+S` chạy `flameshot gui` sau khi cài. Desktop khác cần đặt phím tắt trong Keyboard Shortcuts. |
| Noto, Liberation fonts | Font Unicode/CJK và tương thích tài liệu |
| Carlito, Caladea và font aliases | Thay thế gần kích thước Calibri/Cambria; ánh xạ các font Office phổ biến trong tài khoản người dùng |
| Thunderbird, PDF Arranger | Email desktop độc lập và sắp xếp trang PDF |
| SMB/CIFS, OpenVPN | Truy cập file share và kết nối VPN khi có cấu hình |

### Làm việc chuyên sâu — profile `full`

| App | Công dụng | Nguồn |
|---|---|---|
| Google Chrome | Trình duyệt, họp web, dịch vụ Google | `.deb` chính thức; chỉ x86_64 |
| Microsoft Edge | Trình duyệt, Microsoft 365 web, Teams web | Kho Microsoft chính thức |
| Visual Studio Code | Lập trình, chỉnh sửa code, terminal và extension | Kho Microsoft chính thức |
| Docker Engine + Compose | Container, môi trường dev và triển khai dịch vụ | Kho Docker trên Ubuntu; gói distro trên Mint |
| Zoom | Họp trực tuyến | `.deb` chính thức; chỉ x86_64 |
| Remmina + RDP/VNC | Điều khiển máy Windows/Linux từ xa | Kho Ubuntu/Mint |
| OpenSSH client | Kết nối server và copy file qua SSH | Kho Ubuntu/Mint |
| Python, pip, venv, build-essential | Lập trình, automation và biên dịch package | Kho Ubuntu/Mint |
| Inxi, GParted, GNOME Disks, Nmap, ethtool, iperf3, smartmontools | Chẩn đoán máy và mạng | Kho Ubuntu/Mint |
| Flatpak + Flathub | Cài thêm ứng dụng desktop sandbox | Flatpak/Flathub |
| Zalo Linux (chat, `full` tùy chọn) | Nhắn tin, gọi thoại/video (nếu hệ thống hỗ trợ) qua AppImage cộng đồng; tạo launcher/icon | Installer đã đóng gói trong Office Kit; AppImage từ `VN-Linux-Family/zalo-for-linux` hoặc mirror kiểm tra SHA-256 |

Zalo installer nằm sẵn tại `vendor/zalo/` (đồng bộ từ repository `huynhoainam-sys/zalo-linux-chat-kit`), không cần clone repo thứ hai. Các thư viện (`curl`, `ca-certificates`, `libfuse2`, `libopus0`, `pulseaudio-utils`, clipboard...) chỉ được cài nếu thiếu. Khi GitHub bị chặn, bộ cài thử release ghim SHA-256 và mirror đã kiểm tra nội dung; nếu tất cả nguồn đều lỗi, giữ bản Zalo cũ và không xóa dữ liệu chat.

**Hai kênh tải file khi proxy chặn:** các file `.deb` trực tiếp được thử qua `curl`, nếu thất bại thử `wget` trên HTTPS. Với WPS phiên bản ghim SHA-256, IT có thể chỉ định nguồn phụ bằng `ULOK_WPS_MIRROR_URL=https://may-chu-tin-cay/ten-goi.deb`; cả hai nguồn đều phải khớp cùng mã băm. Nếu domain bị chặn ở tầng mạng, hai công cụ cùng URL cũng có thể thất bại; bộ cài không tự vô hiệu proxy/VPN hoặc dùng nguồn không xác thực. APT vẫn sử dụng mirror được cấu hình trên máy; khi lệnh cài nhóm thất bại, script thử từng gói để lỗi một ứng dụng không chặn phần khác. Xem [kiểm kê ứng dụng và chính sách tải](docs/APPS-AND-NETWORK.md).

**Outlook cho Ubuntu:** Microsoft không cung cấp Outlook desktop Linux tương đương bản Windows. Office Kit tạo biểu tượng **Microsoft Outlook (Web)** dẫn tới `https://outlook.office.com/mail/` và tự chọn Edge/Chrome (cửa sổ app) nếu có, sau đó Firefox hoặc trình duyệt mặc định. Muốn PWA thực sự, mở Outlook bằng Edge và chọn **Apps → Install this site as an app**, hoặc dùng **Install Outlook** trong Chrome khi có tùy chọn. Kit không lưu mật khẩu/email công ty. Có thể sửa riêng launcher bằng `bash setup.sh --fix-outlook --yes`.

### Các app chưa tự cài

- Microsoft Office desktop: không có bản Linux native được Microsoft hỗ trợ; dùng LibreOffice hoặc Microsoft 365 web.
- AnyDesk, VirtualBox, Discord, Slack, OBS, Kdenlive: có thể bổ sung thành module riêng sau khi chốt danh sách và chính sách nguồn của máy.

Sau khi chạy, xem `setup-report.txt` để biết app nào PASS, app nào WARN/FAIL. App tùy chọn không có trên kiến trúc hoặc distro sẽ được ghi rõ, không làm giả trạng thái thành công.
Chạy `bash doctor.sh` để kiểm tra lại trạng thái ứng dụng, bộ gõ, CUPS và Canon bất cứ lúc nào; báo cáo được lưu trong `doctor-report.txt`.
Nếu bộ gõ mất sau cập nhật hoặc đổi desktop, chạy `./setup.sh --fix-unikey` bằng tài khoản đang đăng nhập, sau đó đăng xuất và đăng nhập lại. Với Fcitx5, script giữ profile cũ, thêm engine Unikey nếu thiếu và chọn Fcitx5 qua `im-config`; với GNOME/IBus, script thêm Unikey vào Input Sources khi xác định được engine. Không tạo watchdog chạy nền hoặc ghi đè toàn bộ cấu hình người dùng.

### Sửa riêng bộ gõ tiếng Việt và Flameshot trên máy đã setup

Mở Terminal **trong đúng phiên Ubuntu desktop**, dùng tài khoản đang đăng nhập (không dùng `sudo bash setup.sh`). Không cần chạy lại profile `full` hoặc cài lại các phần mềm văn phòng:

```bash
cd "$HOME/universal-linux-office-kit"
git pull --ff-only
bash -n setup.sh
bash setup.sh --fix-unikey --fix-flameshot
bash doctor.sh
```

- **Tiếng Việt:** trên Ubuntu GNOME chọn IBus Unikey, kể cả khi phiên bản kit cũ đã cài Fcitx5; trên Linux Mint/Cinnamon dùng Fcitx5. Nếu chưa có bộ gõ đúng, script cài thêm qua APT. GNOME thêm và chọn Unikey trong Input Sources; Fcitx5 giữ các mục có sẵn và đổi bộ gõ mặc định thành Unikey (có sao lưu profile trước khi sửa). Có thể đổi qua tiếng Anh bằng **Super+Space** (GNOME), hoặc phím chuyển bộ gõ của Fcitx5. Sau sửa cần **đăng xuất → đăng nhập** để `im-config` có hiệu lực.
- **Flameshot:** cài gói nếu thiếu; trên GNOME Wayland bổ sung `xdg-desktop-portal`, backend GNOME và Qt Wayland. Tạo launcher cá nhân `~/.local/bin/ulok-flameshot`, tự chạy khi đăng nhập và gán **Ctrl+Shift+S** trong GNOME. Chỉ cập nhật các tệp kit quản lý; không sửa file `.desktop` của hệ thống và không xóa phím tắt cá nhân khác.

Nếu APT không cài được Flameshot (ví dụ máy đang dùng mirror nội bộ không truy cập được), lệnh `--fix-flameshot` nay trả về lỗi và ghi nguyên nhân vào `setup.log`/`setup-report.txt`, không coi việc chỉ tạo shortcut là cài thành công. Kiểm tra thủ công bằng `sudo apt-get install -y flameshot` và gửi dòng lỗi APT để xác định đúng mirror/phụ thuộc.

Để tự thử chụp ngay sau khi đăng nhập lại:

```bash
"$HOME/.local/bin/ulok-flameshot"
```

Nếu GNOME hỏi quyền **Share/Chia sẻ màn hình**, chọn cho phép. Trường hợp vẫn hiện `Unable to capture screen`, kiểm tra `echo "$XDG_SESSION_TYPE"` và `bash doctor.sh`. Flameshot trên một số bản GNOME/Wayland có lỗi quyền chụp màn hình từ upstream, nên việc cài đủ gói không bảo đảm hoạt động trên mọi bản Ubuntu. Có thể thử **Ubuntu on Xorg** từ biểu tượng bánh răng ở màn hình đăng nhập nếu tùy chọn này được cài sẵn; không tự đổi session hay quyền bảo mật. Xem [hướng dẫn Wayland chính thức của Flameshot](https://flameshot.org/docs/guide/wayland-help/).

### Cài Canon UFR II

Tra model máy in trên [Canon Việt Nam](https://vn.canon/en/support), tải gói **UFR II/UFRII LT Printer Driver for Linux** dành cho model của bạn (ví dụ bản V6.40), rồi chạy:

```bash
./setup.sh --profile office --canon-ufrii-archive "$HOME/Downloads/linux-UFRII-drv-v640-m17n-06.tar.gz"
```

Gói UFR II chỉ cài khi cung cấp archive; tránh áp nhầm driver cho máy Canon dùng CAPT hoặc driver khác. Script không tự thêm máy in vì cần địa chỉ IP/USB và model cụ thể.

#### Thiết lập khổ giấy và in nhanh

Sau khi cài driver, mở **Cài đặt → Máy in → Thêm máy in**, chọn máy Canon qua USB hoặc địa chỉ IP, rồi chọn đúng model/driver **Canon UFR II**. Đặt giấy trong khay máy và khổ giấy trong phần **Tùy chọn máy in** cùng một loại (thường là A4). Không đổi khổ của mọi máy in trong lúc chạy bộ cài vì mỗi máy có thể dùng giấy khác nhau.

Nếu muốn đặt A4 mặc định **chỉ cho tài khoản đang dùng**, kiểm tra tên máy in rồi chạy:

```bash
lpstat -e                       # liệt kê tên hàng đợi máy in
lpoptions -p TEN_MAY_IN -l     # xem các khổ giấy máy hỗ trợ
lpoptions -p TEN_MAY_IN -o media=A4
lpoptions -p TEN_MAY_IN        # kiểm tra lại tùy chọn
```

Thay `TEN_MAY_IN` bằng tên chính xác từ `lpstat -e`. Nếu máy không hỗ trợ A4, chọn khổ xuất hiện trong danh sách `lpoptions -l`. Để in một tệp PDF với khổ A4 mà không đổi mặc định: `lp -d TEN_MAY_IN -o media=A4 ten-file.pdf`. Trong LibreOffice/GenOffice, kiểm tra **khổ trang của tài liệu** và **khổ giấy trong hộp thoại In** đều là A4 trước khi bấm In; nếu máy hỏi chọn khay, chọn khay đang chứa giấy A4. Có thể in trang thử từ giao diện Máy in để kiểm tra trước khi in tài liệu thật.

Nếu in PDF lúc A4 lúc A5, dùng `bash print-paper.sh TEN_MAY_IN file.pdf`. Script đọc khổ từng trang rồi gửi lệnh in với `media=A4` hoặc `media=A5`; không đổi khổ mặc định. Chạy thêm `--dry-run` để xem trước. File gồm lẫn A4/A5 hoặc khổ khác sẽ dừng và báo rõ để tránh in sai giấy. Với DOCX/XLSX, mở bằng ứng dụng văn phòng và chọn đúng khổ trong hộp thoại In.

### Chống cài trùng

APT tự giữ các gói đã cài. Bộ cài kiểm tra WPS/LibreOffice/GenOffice trước, chỉ bổ sung cho đủ tối đa **2 bộ**; WPS luôn được ưu tiên khi còn chỗ. Nếu máy đã có 2 bộ khác WPS hoặc đã có 3 bộ, script **không tự gỡ** dữ liệu/ứng dụng, chỉ ghi cảnh báo. Chrome và Zoom bỏ qua tải `.deb` nếu đã có; bộ gõ giữ cấu hình cá nhân còn dùng được. Zalo bỏ qua tải lại khi có AppImage, launcher và marker đúng biến thể; dùng `--update-zalo` để cập nhật chủ động. Canon UFR II bỏ qua khi driver tương ứng đã cài. Kit không gọi lại các script rời trong bộ cũ, không tạo thêm launcher Zalo Web/PWA hay cài Bottles/AnyDesk mặc định.

## Thiết kế

- Chạy được trên Ubuntu LTS và Linux Mint dựa trên Ubuntu.
- Một launcher duy nhất, nhưng mỗi nhóm chức năng là một module có thể bật/tắt.
- Idempotent: chạy lại không cài lặp và không ghi đè cấu hình người dùng.
- Có bước repair cho trạng thái cài mới lỗi: `dpkg --configure -a`, `apt-get -f install`, khóa APT stale và cập nhật chỉ khi đã xác nhận.
- App bên thứ ba được lấy từ kho/URL chính thức của GenOffice, Google, Microsoft, Docker và Zoom; có thể bỏ qua bằng `--skip-third-party`.
- Mỗi lệnh được ghi vào log; cuối lượt tạo report PASS/WARN/FAIL.

## Giới hạn có chủ ý

Microsoft Office desktop không có bản Linux native được Microsoft hỗ trợ. Kit ưu tiên WPS Office nếu máy x86_64 và mạng truy cập được nguồn WPS, LibreOffice là bộ bổ sung mặc định. Zalo Linux trong profile `full` là bản AppImage cộng đồng, không phải ứng dụng Linux chính thức của Zalo. Có thể bỏ qua cùng các app bên thứ ba bằng `--skip-third-party`. Installer Zalo đi kèm bản Office Kit hiện tại, không tải mã script mới vào lúc chạy; chỉ tải AppImage từ upstream/mirror và kiểm tra SHA-256 khi upstream có digest. Các nguồn bị proxy doanh nghiệp chặn vẫn cần được IT cho phép.

File checksum được tham khảo trong thiết kế: `universal-linux-office-kit-v7.3-pro-max-report-printer-optional.sha256` ghi hash `9c7ebdf1af1131eacbf9bd764016e52ce1f4d2c9891bd02274fe7ff185204a28` cho ZIP trỏ tới `/mnt/data/...`. ZIP không có trong máy hiện tại nên chưa thể xác minh hash thực tế.

## Xử lý lỗi GitHub API / Raw HTTP 403

- `raw.githubusercontent.com` báo 403: tiếp tục dùng `git clone`, không dùng `curl | bash`.
- `api.github.com` báo 403: GenOffice tự fallback gói chính thức v0.11.727, kiểm SHA-256; Zalo dùng fallback trong repository Zalo.
- `github.com/.../releases/download/` cũng báo 403: không cài gói chưa xác minh. Thử mạng khác hoặc liên hệ quản trị mạng; kết quả ghi WARN/FAIL trong `setup-report.txt`.
- Lỗi `setup.sh: dòng 78: name: biến chưa liên kết`: đã sửa bằng cách khai báo `target` sau khi gán `name`.
- Cảnh báo Flatpak `XDG_DATA_DIRS`: đăng xuất/đăng nhập phiên desktop khi cần hiện ứng dụng Flatpak; không liên quan lỗi HTTP 403.

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

</details>

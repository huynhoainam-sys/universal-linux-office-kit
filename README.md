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

Các profile:

- `minimal`: sửa APT/dpkg, cập nhật hệ thống, công cụ nén, mạng, font và in ấn.
- `office`: minimal + LibreOffice, PDF, scan, media, browser integration.
- `full`: office + development, backup, remote desktop, Flatpak cơ bản.

Tùy chọn an toàn: `--dry-run`, `--profile`, `--no-reboot`, `--skip-flatpak`, `--report PATH`, `--yes`.

## Thiết kế

- Chạy được trên Ubuntu LTS và Linux Mint dựa trên Ubuntu.
- Một launcher duy nhất, nhưng mỗi nhóm chức năng là một module có thể bật/tắt.
- Idempotent: chạy lại không cài lặp và không ghi đè cấu hình người dùng.
- Có bước repair cho trạng thái cài mới lỗi: `dpkg --configure -a`, `apt-get -f install`, khóa APT stale và cập nhật chỉ khi đã xác nhận.
- Chỉ dùng package hệ điều hành/Flatpak mặc định. App bên thứ ba phải được người dùng thêm vào profile riêng và pin checksum.
- Mỗi lệnh được ghi vào log; cuối lượt tạo report PASS/WARN/FAIL.

## Giới hạn có chủ ý

Microsoft Office desktop không có bản Linux native được Microsoft hỗ trợ. Kit cài LibreOffice mặc định; việc cài Office qua Wine/VM là module ngoài, không chạy ngầm và không được giả nhận là Office native.

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

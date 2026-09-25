# Phân tích và quyết định thiết kế

## Các repo đã tham khảo

| Nguồn | Điểm đáng giữ | Rủi ro cần sửa |
|---|---|---|
| `tprasadtp/ubuntu-post-install` | Có cấu hình/profile, hỗ trợ Ubuntu/Debian/Mint | Cách chạy phụ thuộc file cấu hình ngoài; người mới dễ chạy nhầm |
| `franckferman/ubuntu-post-install` | Module rõ, retry, dry-run, extras và hardening | Có nhiều tùy chọn bên thứ ba; cần policy chặt hơn cho máy mới cài |
| `rothgar/ansible-workstation` | Idempotency và playbook có cấu trúc | Ansible làm tăng ma sát cho “1 click” trên máy chưa có Python/Ansible |
| `jdauphant/ansible-ubuntu-desktop` | Bootstrap từ máy sạch | Kiểu `wget ... | sh` không phù hợp khi cần review và kiểm toán |
| `marcinbojko/linux_mint` | Tách biến theo phiên bản Mint, vai trò riêng | Phụ thuộc SSH/Ansible và nhiều repo tải `.deb` ngoài |
| `canonical/ubuntu-desktop-provision` | Tham chiếu provisioning chính thức của Ubuntu | Thiên về OEM provisioning, không phải tool hậu cài cho người dùng |

## Bản tối ưu hóa

1. Launcher Bash thuần để chạy được trước khi Ansible/Python tồn tại.
2. Profile một tham số thay vì hàng chục lệnh rời.
3. `dpkg` repair trước `apt update`, vì trạng thái cài mới thường hỏng ở đây.
4. Package từ APT mặc định; Flatpak là tùy chọn. Không thêm PPA, repo hãng hoặc tải binary không pin hash trong mặc định.
5. Không xóa package, không sửa dotfiles, không đổi desktop theme, không tự reboot.
6. Log và report tách riêng; trạng thái thiếu bằng chứng là WARN chứ không giả thành PASS.
7. Dễ nâng cấp về Ansible/GUI sau này: các module hiện là ranh giới rõ, nên có thể chuyển từng module sang role mà không đổi UX.

## Lộ trình phiên bản

- v1: Ubuntu/Mint + APT + profile + report.
- v1.1: test matrix trên Ubuntu 22.04/24.04 và Mint 21/22 bằng VM.
- v1.2: file config local cho package bổ sung và checksum bắt buộc cho `.deb` bên ngoài.
- v2: Ansible backend tùy chọn cho nhiều máy, vẫn giữ `setup.sh` làm bootstrap.
- v2.x: GUI mỏng gọi cùng CLI; không có logic cài đặt riêng trong GUI.

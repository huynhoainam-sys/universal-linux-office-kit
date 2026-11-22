# NAMHH Office Kit · Quy tắc thiết kế

Áp dụng cho **Terminal Ubuntu**, báo cáo `setup-report.html` và tài liệu hướng dẫn. Định hướng: **công nghệ như giao diện AI thực chiến / NA AI**, gọn, rõ, chạy offline và dễ dùng cho người mới chuyển từ Windows.

## 1. Nhận diện

- Tên hiển thị: **NAMHH / UNIVERSAL LINUX OFFICE KIT**.
- Người thiết kế và liên hệ: **NAMHH · huynhoainam@gmail.com**. Trong HTML, email phải là liên kết `mailto:`.
- Không thêm tên công ty, sản phẩm hoặc logo bên thứ ba như một đối tác nếu chưa có quyền sử dụng.
- Lấy cảm hứng từ giao diện AI dashboard người dùng chọn: nền navy sâu, đường lưới mờ, thẻ trạng thái xanh cyan và một điểm nhấn tím. Không sao chép logo, hình ảnh, số liệu hay tên thương hiệu NA AI vào bộ cài.
- Cyan và xanh lam cho thao tác/chỉ số thực, tím cho nhận diện/phân tách, xanh lá cho trạng thái thành công, vàng cho cảnh báo, đỏ cho lỗi. Viền phát sáng chỉ là lớp nhấn rất mỏng, không nhấp nháy hoặc dùng nền gradient cầu vồng.
- Terminal có banner NAMHH, mã bước `[01/12 · 8%]`, phản hồi theo bước và tổng kết. Không in lệnh APT dài; nội dung kỹ thuật được lưu trong `setup.log` và xem qua `--verbose`.
- `dry-run` chỉ hiện **ĐÃ MÔ PHỎNG**, không in hoàn tất cài đặt thật.

## 2. Hệ màu và bố cục

| Chức năng | Màu | Quy tắc |
|---|---|---|
| Terminal & HTML nền navy | `#061021` | Đồng nhất giữa màn hình lệnh và báo cáo, không thuần đen |
| HTML hero / nền công nghệ | `#061124 → #152b53` | Lưới CSS 44px rất mờ, không ảnh nền |
| Thẻ nội dung | `#0c1b32` | Viền `#284467`, ánh sáng viền mức thấp |
| Text chính | `#eaf3ff` | Trắng xanh dễ đọc, tiếng Việt Unicode |
| Text phụ | `#a6bed7` | Nội dung hướng dẫn vẫn nổi trên nền tối |
| Accent / link | `#50d9f0` | Tiêu đề mục, điều hướng và liên kết |
| Accent phụ | `#bd9cfc` | Chỉ dùng tiết chế ở brand và thẻ Office |
| PASS | `#7ce6ba` | Chỉ khi xác minh đã có / đã hoàn tất |
| Cảnh báo | `#f0c67c` | Diễn giải cách xử lý, không gây hoang mang |

- 8px spacing cơ sở, bo góc 9–16px, viền mảnh, shadow nhẹ; card đầu trang sáng hơn vừa đủ để nhận diện trạng thái.
- Không sử dụng biểu đồ, chỉ số agents, thông số kết nối hay nút giả từ ảnh tham khảo: các số trong HTML phải lấy từ kết quả kiểm tra ứng dụng thực tế.
- Phân cấp: tiêu đề lớn → trạng thái hệ thống → ba việc cần làm → hướng dẫn thao tác → danh sách ứng dụng → kỹ thuật.
- Mobile: các thẻ chuyển một cột, mục bấm có kích thước tối thiểu 44px.

## 3. Icon chuẩn, thống nhất

- Dùng **inline SVG**, `viewBox="0 0 24 24"`, viền `currentColor`, nét 2px, đầu nét tròn. Không tải icon font, ảnh hoặc JavaScript từ Internet.
- Nút nguồn dùng ký hiệu power chuẩn dạng nét đứng + vòng hở; không dùng emoji dễ hiện thành ô vuông.
- Bộ biểu tượng: Power, Wi-Fi, Volume, Battery, Log Out, Restart, Keyboard, Chat, Apps, Check, Minus, Mail.
- Icon chỉ mang tính trang trí đặt `aria-hidden="true"`; chữ đi cùng vẫn là tên thao tác rõ ràng.
- Không dùng một biểu tượng để chỉ hai hành động khác nhau.

## 4. Ngôn ngữ và UX

- Nội dung chính bằng tiếng Việt, **giữ nguyên tên menu tiếng Anh** chính xác để người dùng tìm thấy trên Ubuntu:
  `Quick Settings`, `Power`, `Log Out…`, `Restart…`, `Settings`, `Keyboard`, `Input Sources`, `Vietnamese (Unikey)`.
- Mỗi bước bắt đầu bằng động từ, tối đa một thao tác chính. Chỉ dùng cụm từ kỹ thuật khi cần thiết.
- Hướng dẫn log out: góc phải top bar → Quick Settings → Power → Log Out…; lưu tài liệu trước.
- Hướng dẫn **Unikey** (không có phần hướng dẫn VNI riêng): chọn Settings → Keyboard → Input Sources → Add Input Source; bấm chỉ báo nguồn nhập hoặc Super+Space; mở More settings… / Preferences để tự chọn kiểu gõ và Output charset Unicode.
- Mô phỏng bấm từng bước dùng `<details>` và radio HTML thuần, icon SVG cùng hình dáng/ý nghĩa với GNOME/IBus. Chú thích rõ chỉ là minh họa, không điều khiển máy thật; các bước có thể dùng bằng bàn phím và không cần JavaScript.
- Zalo quét QR xong quay lâu: đóng hẳn Zalo, lưu công việc, Restart…, mở lại và quét mã mới; giữ nguyên dữ liệu đăng nhập.
- Không viết “đã cài thành công” trong báo cáo `dry-run`; thay bằng “bản chạy thử, không cài ứng dụng”.
- Khi 2–3 bộ Office đã tồn tại, chỉ cảnh báo; không tự gỡ ứng dụng hay dữ liệu.
- Ở `--profile desktop`, cài ba thành phần thiết yếu **Unikey → Flameshot → Zalo** trước Office và tiện ích phụ. Thiếu gói phụ không được chặn các thành phần thiết yếu.
- Bộ gõ GNOME: IBus Unikey được ưu tiên ở đầu `sources` và `mru-sources`. GSettings `current` đã lỗi thời và không còn tác dụng trên GNOME mới; không dùng để khẳng định UniKey đã được kích hoạt. Không ép kiểu gõ hoặc ghi đè lựa chọn cá nhân.
- Session guard chỉ khôi phục nguồn Unikey khi mất và ưu tiên lúc khôi phục; khi nguồn vẫn còn thì tuyệt đối không đổi thứ tự, lựa chọn hay phương pháp gõ. Không kill/restart daemon IBus giữa phiên Wayland.

## 5. Tốc độ và offline

- `setup-report.html` là **một file tự chứa**: HTML + CSS + SVG, không JS, CDN, web font, tracker hay yêu cầu Internet. CSS gradient/lưới tĩnh, không canvas, animation hay tải ảnh.
- Ưu tiên trình duyệt mặc định của Ubuntu qua `xdg-open`; Firefox là phương án dự phòng nếu `xdg-open` lỗi hoặc thiếu.
- Báo cáo mở tự động trên phiên đồ họa sau khi cài thật, không tự mở khi `--dry-run` hoặc dùng `--no-open-report`.
- Không auto-logout hoặc reboot: chỉ hướng dẫn để người dùng chủ động lưu công việc.

## 6. QA bắt buộc trước khi cập nhật GitHub

1. `bash tests/test_static.sh` và Python HTML tests đều PASS.
2. GitHub Actions Ubuntu **22.04 và 24.04** chạy `--profile desktop --dry-run`; không cài package thật hoặc dùng tài khoản Zalo.
3. Mock các tình huống: FPT/proxy chặn APT, tải WPS lỗi, gói phụ lỗi, mất Unikey trong GNOME, GSettings chưa sẵn sàng, giữ kiểu gõ cá nhân, Flameshot Wayland, Zalo đã cài, tối đa hai bộ Office.
4. Chụp ảnh Terminal XTerm **nền đen thật**, rõ ba trạng thái: đầu, tiến trình, hoàn tất.
5. Render HTML bằng Chromium, thử Firefox headless nếu có, kiểm tra icon Power/Logout/Restart, tiếng Việt và trạng thái thực tế.
6. Chỉ công bố ảnh chạy thật kèm nhãn `dry-run`; không dùng ảnh mô phỏng làm bằng chứng cài đặt thành công.

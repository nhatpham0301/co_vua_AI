# Chính sách Quyền riêng tư — Chess AI

> **Phiên bản**: 1.0  
> **Ngày hiệu lực**: 16 tháng 05 năm 2026  
> **Nhà phát triển**: Azentra  
> **Liên hệ**: trochoigiaitri11@gmail.com 

---

## 1. Giới thiệu

Chính sách Quyền riêng tư này mô tả cách ứng dụng **Chess AI** ("chúng tôi", "ứng dụng") thu thập, sử dụng và bảo vệ thông tin của bạn khi bạn sử dụng dịch vụ.

Bằng cách cài đặt hoặc sử dụng Chess AI, bạn đồng ý với các điều khoản trong chính sách này. Nếu bạn không đồng ý, vui lòng không sử dụng ứng dụng.

---

## 2. Thông tin chúng tôi thu thập

### 2.1 Thông tin tài khoản (khi đăng ký)

Khi bạn tạo tài khoản để chơi online, chúng tôi thu thập:

| Trường dữ liệu           | Mục đích                                   |
| ------------------------ | ------------------------------------------ |
| Tên đăng nhập (username) | Hiển thị trong ván đấu và bảng xếp hạng    |
| Địa chỉ email            | Xác thực tài khoản, khôi phục mật khẩu     |
| Mật khẩu (đã băm)        | Bảo mật đăng nhập — **không lưu dạng thô** |
| Điểm ELO                 | Hệ thống xếp hạng và ghép trận             |
| Ảnh đại diện (URL)       | Hiển thị hồ sơ người chơi (tùy chọn)       |

> Bạn có thể sử dụng ứng dụng ở chế độ khách (chưa đăng nhập) để chơi cờ với AI cục bộ mà không cần cung cấp bất kỳ thông tin nào.

### 2.2 Dữ liệu trò chơi

Khi chơi online, chúng tôi thu thập:

- Lịch sử các nước đi trong mỗi ván đấu
- Kết quả ván đấu (thắng / thua / hoà)
- Thay đổi điểm ELO sau mỗi ván
- Thời gian chơi và chế độ thời gian (rapid, blitz, ...)
- ID ván đấu và ID đối thủ

### 2.3 Dữ liệu kỹ thuật & thiết bị

Chúng tôi có thể thu thập tự động:

- Loại thiết bị, hệ điều hành và phiên bản
- Phiên bản ứng dụng
- Nhật ký lỗi ứng dụng (crash logs)
- Địa chỉ IP (dùng cho kết nối server, không lưu lâu dài)

### 2.4 Dữ liệu lưu cục bộ (SharedPreferences)

Ứng dụng lưu **trên thiết bị của bạn** (không gửi về server):

- Cài đặt giao diện (chủ đề, bộ quân cờ)
- Cài đặt âm thanh
- Cài đặt ngôn ngữ
- Token xác thực (access token, refresh token) — dùng để duy trì phiên đăng nhập

---

## 3. Quảng cáo (Google AdMob)

Ứng dụng sử dụng **Google AdMob** để hiển thị quảng cáo (banner và interstitial). Google AdMob có thể thu thập:

- Mã định danh quảng cáo (Advertising ID) của thiết bị
- Dữ liệu hành vi sử dụng ứng dụng để phân phối quảng cáo phù hợp

Để biết thêm chi tiết về cách Google sử dụng dữ liệu, xem:  
→ [Chính sách quyền riêng tư của Google](https://policies.google.com/privacy)  
→ [Cách Google sử dụng dữ liệu khi bạn dùng app của đối tác](https://policies.google.com/technologies/partner-sites)

Bạn có thể tắt quảng cáo cá nhân hóa trong **Cài đặt thiết bị > Google > Quảng cáo**.

---

## 4. Cách chúng tôi sử dụng thông tin

| Mục đích                      | Dữ liệu liên quan                |
| ----------------------------- | -------------------------------- |
| Xác thực và bảo mật tài khoản | Email, mật khẩu, token           |
| Ghép trận đấu online          | ELO, username                    |
| Hiển thị hồ sơ người chơi     | Username, ELO, ảnh đại diện      |
| Theo dõi kết quả và thống kê  | Lịch sử ván đấu, điểm ELO        |
| Cải thiện chất lượng ứng dụng | Nhật ký lỗi, thông tin thiết bị  |
| Hiển thị quảng cáo            | Dữ liệu AdMob (xử lý bởi Google) |

Chúng tôi **không** bán thông tin cá nhân của bạn cho bên thứ ba.

---

## 5. Lưu trữ và bảo mật dữ liệu

- Dữ liệu tài khoản được lưu trên máy chủ tại `giaitri.cloud` với giao thức HTTPS.
- Mật khẩu được băm trước khi lưu trữ — chúng tôi không có khả năng đọc mật khẩu của bạn.
- Token xác thực được lưu cục bộ trên thiết bị (SharedPreferences) và được gia hạn tự động.
- Chúng tôi áp dụng các biện pháp bảo mật hợp lý (mã hoá truyền tải, JWT có thời hạn ngắn) để bảo vệ dữ liệu của bạn.

> **Lưu ý bảo mật**: Token xác thực hiện được lưu trong SharedPreferences tiêu chuẩn. Trên các thiết bị đã root/jailbreak, dữ liệu này có thể bị truy cập bởi ứng dụng khác. Khuyến nghị không sử dụng ứng dụng trên thiết bị đã root.

---

## 6. Chia sẻ thông tin

Chúng tôi **không chia sẻ** thông tin cá nhân của bạn với bên thứ ba ngoại trừ:

1. **Google AdMob** — để hiển thị quảng cáo (xem Mục 3)
2. **Yêu cầu pháp lý** — khi cơ quan có thẩm quyền yêu cầu theo quy định pháp luật
3. **Bảo vệ quyền lợi** — khi cần thiết để ngăn chặn gian lận hoặc vi phạm điều khoản dịch vụ

---

## 7. Quyền của bạn

Bạn có các quyền sau đối với dữ liệu cá nhân của mình:

- **Truy cập**: Xem thông tin tài khoản của bạn trong ứng dụng
- **Chỉnh sửa**: Cập nhật username, ảnh đại diện trong hồ sơ
- **Xoá tài khoản**: Gửi yêu cầu đến `trochoigiaitri11@gmail.com` để xoá toàn bộ dữ liệu
- **Rút đồng ý**: Ngừng sử dụng ứng dụng và gỡ cài đặt bất kỳ lúc nào

Để thực hiện bất kỳ quyền nào ở trên, liên hệ: **trochoigiaitri11@gmail.com**

---

## 8. Trẻ em

Ứng dụng **không dành cho trẻ em dưới 13 tuổi** (hoặc 16 tuổi tại một số quốc gia thuộc EU theo GDPR). Chúng tôi không cố ý thu thập thông tin cá nhân từ trẻ em. Nếu bạn phát hiện con em mình đã cung cấp thông tin cho chúng tôi, vui lòng liên hệ để yêu cầu xoá.

---

## 9. Chế độ khách (không đăng nhập)

Khi sử dụng ứng dụng mà không đăng nhập:

- Không có thông tin cá nhân nào được thu thập hoặc gửi lên server
- Tất cả dữ liệu chỉ tồn tại trên thiết bị (cài đặt, ván cờ đã lưu)
- Tính năng chơi online **không khả dụng**

---

## 10. Thay đổi chính sách

Chúng tôi có thể cập nhật Chính sách Quyền riêng tư này theo thời gian. Khi có thay đổi quan trọng:

- Chúng tôi sẽ cập nhật "Ngày hiệu lực" ở đầu tài liệu
- Thông báo có thể được hiển thị trong ứng dụng
- Tiếp tục sử dụng ứng dụng sau ngày hiệu lực đồng nghĩa với việc bạn chấp thuận chính sách mới

---

## 11. Liên hệ

Nếu bạn có câu hỏi về Chính sách Quyền riêng tư này:

- **Email**: trochoigiaitri11@gmail.com
- **Website**: https://giaitri.cloud

---

## Phụ lục A — Khai báo Data Safety (Google Play)

Bảng sau dùng để khai báo trong mục **Data Safety** trên Google Play Console:

| Loại dữ liệu        | Thu thập?     | Mục đích             | Bắt buộc?              |
| ------------------- | ------------- | -------------------- | ---------------------- |
| Tên / Username      | ✅ Có         | Chức năng ứng dụng   | Không (chỉ khi online) |
| Địa chỉ email       | ✅ Có         | Quản lý tài khoản    | Không (chỉ khi online) |
| ID người dùng       | ✅ Có         | Chức năng ứng dụng   | Không (chỉ khi online) |
| Hoạt động trong app | ✅ Có         | Phân tích, cải thiện | Không                  |
| Crash logs          | ✅ Có         | Sửa lỗi              | Không                  |
| Thông tin thiết bị  | ✅ Có         | Sửa lỗi              | Không                  |
| Dữ liệu quảng cáo   | ✅ Có (AdMob) | Quảng cáo            | Không                  |
| Vị trí chính xác    | ❌ Không      | —                    | —                      |
| Danh bạ             | ❌ Không      | —                    | —                      |
| Camera / Microphone | ❌ Không      | —                    | —                      |

**Truyền dữ liệu có mã hoá**: ✅ Có (HTTPS / WSS)  
**Yêu cầu xoá dữ liệu**: ✅ Có (qua email)

---

## Phụ lục B — App Privacy (Apple App Store)

Khai báo trong mục **App Privacy** trên App Store Connect:

| Loại dữ liệu            | Sử dụng                  | Liên kết với danh tính? |
| ----------------------- | ------------------------ | ----------------------- |
| Email                   | Quản lý tài khoản        | ✅ Có                   |
| Username                | Chức năng app            | ✅ Có                   |
| Game history            | Chức năng app, Phân tích | ✅ Có                   |
| Device ID (Advertising) | Quảng cáo (AdMob)        | ❌ Không                |
| Crash data              | Sửa lỗi                  | ❌ Không                |
| Vị trí                  | Không thu thập           | —                       |

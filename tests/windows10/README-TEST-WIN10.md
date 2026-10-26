# Kiểm thử PNG to JPG 2.0.1 trên Windows 10

Đây là bản Development để kiểm thử, không phải bộ cài Store. Không cần Visual
Studio, Python, Windows SDK hoặc chứng chỉ. Máy cần Windows 10 x64 từ build
19041 (2004) trở lên; ưu tiên 22H2/build 19045.

## Chuẩn bị

1. Chép ZIP sang máy Windows 10 và giải nén toàn bộ vào một thư mục riêng.
   Giữ nguyên vị trí thư mục cho đến khi dọn bản thử xong.
2. Nếu có bản v1, gỡ bằng trình Uninstall của bản v1 và khởi động lại Explorer
   để không nhầm lệnh cũ với lệnh đang thử. Bộ này không tự xóa registration v1.
   Không dùng tài khoản đã cài bản Store hoặc bản Dev khác.
3. Bản thử chưa có chữ ký Store nên cần bật **Developer Mode**: Settings → Update
   & Security → For developers → Developer mode. Ghi nhớ trạng thái ban đầu để
   tắt lại sau kiểm thử nếu trước đó đang tắt. Không cài chứng chỉ và không sửa
   Registry bằng tay. Nếu máy bị tổ chức quản lý và không cho bật, dừng tại đây.
4. Mở **Windows PowerShell 64-bit bình thường**, không Run as administrator.
   Chuyển vào thư mục đã giải nén, ví dụ:

   ```powershell
   Set-Location "$env:USERPROFILE\Downloads\WinPebble-PNG-to-JPG-Test"
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Begin-Test.ps1
   ```

Script kiểm tra OS, hash, manifest, đăng ký đúng bản Dev và chạy phép thử COM.
Không đổi thiết lập hệ thống, không tin cậy chứng chỉ, không thay bản Store.
Nếu lỗi, giữ nguyên thông báo và chạy lệnh dọn ở cuối tài liệu.

## Thử bằng File Explorer

1. Mở thư mục `samples-...` được script in ra.
2. Chọn cả ba PNG, nhấp chuột phải, chọn **Convert PNG to JPG**. Phải chỉ có
   một lệnh này và tạo đủ ba JPG cạnh các PNG.
3. Chọn riêng `sample.png`, chạy lệnh thêm một lần. Phải có `sample (2).jpg`.
4. Chọn riêng một JPG: không được thấy lệnh chuyển PNG. Kiểm tra ảnh gốc vẫn
   còn; JPG kích thước 320 × 180; ảnh alpha có nền trắng.
5. Chụp ảnh menu lúc chọn PNG và ảnh các tệp kết quả. Dùng đúng dữ liệu thử,
   không đưa tệp cá nhân vào ảnh gửi về.
6. Khi tất cả bước menu đạt, chạy trong cùng cửa sổ PowerShell:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Finish-Test.ps1 -MenuVerified
   ```

Script kiểm tra đầu ra và gỡ đúng package Dev của bộ này. Gửi lại
`WIN10-RESULT.json` cùng ảnh chụp. Giữ bộ ZIP gốc để đối chiếu.
Sau khi gỡ, kiểm tra lệnh thử đã biến mất khỏi menu PNG; khởi động lại Windows
Explorer nếu còn cache và báo lại nếu lệnh vẫn còn.

## Nếu menu không xuất hiện hoặc muốn dừng

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Finish-Test.ps1 -CleanupOnly
```

Không xóa/di chuyển bộ thử trước khi dọn. Không cần xóa ảnh đầu ra; chúng được
giữ lại. Sau khi dọn, khởi động lại Windows Explorer trong Task Manager nếu menu
còn bị cache. Tắt lại Developer Mode nếu ban đầu bạn bật nó chỉ để kiểm thử.
Muốn thử lại: dọn lần cũ trước rồi giải nén một bản ZIP mới vào thư mục khác.

## Phạm vi kết quả

Đạt bộ thử này xác minh bản Dev trên OS/build ghi trong report, gồm COM,
Explorer do người thử xác nhận và đầu ra thực tế. Chưa thay thế WACK, kiểm thử
cài/cập nhật/gỡ MSIX có chữ ký hay nâng cấp bản Store 2.0.0 → 2.0.1. Không dùng
ZIP này hoặc bản Dev để nộp Store. Chưa merge hoặc phát hành bản cập nhật.

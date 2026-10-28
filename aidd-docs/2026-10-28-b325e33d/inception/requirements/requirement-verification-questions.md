# Requirement Verification Questions

Please review and provide your answers directly after each `[Answer]:` tag below.

---

## Question 1: Cơ chế inject version cho ứng dụng Electron (web-clone, v.v.)
Khi build standalone cho ứng dụng Electron (macOS DMG, Windows EXE, Linux AppImage), Fastlane cần áp dụng version như thế nào vào project?

A) Tự động cập nhật trực tiếp trường `"version"` trong `package.json` của app trong workspace trước khi build, đồng thời truyền thêm cờ build `-c.extraMetadata.version=#{version_name}` cho electron-builder để đảm bảo cả runtime lẫn installer đều đồng bộ 100%. (Khuyến nghị)
B) Chỉ cập nhật trực tiếp trường `"version"` trong `package.json` của workspace.
C) Chỉ truyền cờ `-c.extraMetadata.version=#{version_name}` qua tham số lệnh electron-builder, không ghi đè vào file `package.json`.
X) Other (write a description after the [Answer]: tag)

[Answer]: A

---

## Question 2: Xử lý version hardcode trong mã nguồn ứng dụng (`web-clone/src/main/menu.ts`)
Hiện tại `web-clone/src/main/menu.ts` đang fix cứng `version: '1.0.0'` và `applicationVersion: '1.0.0'` trong About panel. Chúng ta nên xử lý như thế nào?

A) Refactor `menu.ts` để đọc động từ `app.getVersion()` của Electron runtime (`version: app.getVersion()`, `applicationVersion: app.getVersion()`), giúp hộp thoại About tự động hiển thị chính xác mọi phiên bản build mà không bao giờ bị lệch. (Khuyến nghị)
B) Chỉ sửa chuỗi hardcode thành `1.0.1` trong `menu.ts` và giữ nguyên code cũ.
C) Giữ nguyên, không can thiệp vào mã nguồn TypeScript của app `web-clone`.
X) Other (write a description after the [Answer]: tag)

[Answer]: A

---

## Question 3: Hành vi của Workflow `build-standalone-fastlane.yml` khi tham số `version` để trống
Khi người dùng chạy GitHub Actions mà để trống ô `version` (default: `""`), workflow và Fastlane nên xử lý ra sao?

A) Fastlane tự động đọc giá trị `"version"` đã cấu hình trong `apps.json` (ví dụ: `web-clone` là `1.0.1`), đồng bộ vào `package.json` và build phiên bản đó. Nếu người dùng nhập tham số `version` tùy biến trên workflow thì ưu tiên lấy tham số người dùng nhập. (Khuyến nghị)
B) Bắt buộc người dùng phải luôn nhập `version` trên workflow (đặt `required: true`), nếu để trống sẽ báo lỗi.
C) Nếu để trống `version`, giữ nguyên version có sẵn trong file `package.json` của app mà không đọc `apps.json`.
X) Other (write a description after the [Answer]: tag)

[Answer]: A

---

## Question 4: Phạm vi đồng bộ phiên bản cho các ứng dụng Flutter Standalone
Hiện tại các ứng dụng Flutter standalone đã được Fastlane truyền tham số `--build-name=#{version_name}` và `--build-number=#{build_number}` khi biên dịch (`flutter build macos/windows/linux`). Bạn có muốn bổ sung thêm cơ chế đồng bộ trực tiếp vào `pubspec.yaml` không?

A) Giữ nguyên cơ chế native `--build-name` và `--build-number` của Flutter (vì Flutter CLI tự động override version tại thời điểm build mà không làm bẩn git repo của app Flutter). Chỉ tập trung đồng bộ cấu hình file cho ứng dụng Electron. (Khuyến nghị)
B) Đồng bộ cả vào file `pubspec.yaml` của Flutter apps trước khi build.
X) Other (write a description after the [Answer]: tag)

[Answer]: A

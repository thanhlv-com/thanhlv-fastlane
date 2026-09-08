---
name: fastlane-add-app
description: >-
  Inspects a mobile/desktop application codebase located strictly inside the `.workspace_code/`
  directory (e.g., `.workspace_code/<app-name>`), extracts project metadata (app_name, git_url,
  branch, platforms, bundle_id, package_name, version, obfuscate, description), and adds the configuration
  to fastlane/apps.json with validation. Use when the user wants to add, configure, or register a new app
  from `.workspace_code` into Fastlane apps.json.
---

# Fastlane Add App Skill (Workspace Code Only)

A structured guide and workflow for inspecting an existing or newly added mobile/multiplatform project **strictly located inside `.workspace_code/`** and registering its configuration into `fastlane/apps.json`.

> [!IMPORTANT]
> **Phạm vi áp dụng nghiêm ngặt:**
> Chỉ chấp nhận và xử lý các dự án nằm trong thư mục `.workspace_code/` (ví dụ: `.workspace_code/app-QuestFlow`).
> Không nhận hoặc xử lý các dự án nằm ngoài thư mục `.workspace_code`. Nếu dự án chưa nằm trong `.workspace_code`, cần yêu cầu đưa dự án vào `.workspace_code` trước khi thực hiện.

---

## 1. apps.json Schema & Field Specifications

Mỗi ứng dụng được định nghĩa trong `fastlane/apps.json` với cấu trúc sau:

```json
{
  "<app_key>": {
    "app_name": "Tên Hiển Thị Store / Brand Title",
    "git_url": "git@github.com:<org>/<repo>.git",
    "branch": "main",
    "platforms": [
      "ios",
      "macos",
      "aos"
    ],
    "bundle_id": "com.thanhlv.<app>",
    "package_name": "com.thanhlv.<app>",
    "version": "1.0.0",
    "obfuscate": true,
    "description": "Mô tả ngắn / Subtitle"
  }
}
```

### Chi tiết các trường
| Trường | Kiểu dữ liệu | Bắt buộc | Quy tắc & Nguồn trích xuất |
|---|---|---|---|
| `app_key` | `String` | **Có** | Khớp chính xác với tên thư mục trong `.workspace_code/` (ví dụ: `app-QuestFlow`). |
| `app_name` | `String` | **Có** | Tên chuẩn Store/ASO (ví dụ: `QuestFlow: RPG Gamified Focus`, `FrameSnap: Video to Photo`). |
| `git_url` | `String` | **Có** | URL Git SSH remote (`git remote get-url origin`). |
| `branch` | `String` | **Có** | Nhánh phát hành chính (`git branch --show-current`, mặc định `main`). |
| `platforms` | `Array` | **Có** | Danh sách nền tảng hỗ trợ: `"ios"`, `"macos"`, `"aos"`. Chỉ liệt kê nền tảng có mã nguồn tương ứng trong app. |
| `bundle_id` | `String` | **Có** | Bundle ID trên iOS/macOS (`PRODUCT_BUNDLE_IDENTIFIER`). |
| `package_name` | `String` | **Có** | Package name trên Android (`applicationId` / `namespace`). |
| `version` | `String` | **Có** | Phiên bản Semantic Version (`pubspec.yaml` `version: X.Y.Z`). Bỏ phần build number. |
| `obfuscate` | `Boolean` | **Có** | Luôn đặt `true` theo tiêu chuẩn bảo vệ mã nguồn. |
| `description` | `String` | Khuyến nghị | Subtitle hoặc mô tả ngắn gọn (trích từ ASO doc hoặc README). |
| `apple_id` | `String` | Tuỳ chọn | Numeric ID trên App Store Connect (chỉ điền khi app đã tạo trên Store). |

---

## 2. Quy trình trích xuất & Cập nhật từng bước

### Bước 1: Xác thực vị trí trong `.workspace_code`
- Kiểm tra đường dẫn dự án: Bắt buộc phải là `<repo_root>/.workspace_code/<app_key>`.
- Nếu dự án nằm ngoài `.workspace_code`, từ chối và thông báo người dùng chuyển hoặc clone dự án vào `.workspace_code/`.

### Bước 2: Trích xuất Git Remote & Branch
Chạy bên trong thư mục `.workspace_code/<app_key>`:
```bash
git remote get-url origin
git branch --show-current
```

### Bước 3: Xác định các nền tảng hỗ trợ (`platforms`)
Kiểm tra các thư mục nền tảng:
- Có `ios/` $\rightarrow$ thêm `"ios"`
- Có `macos/` $\rightarrow$ thêm `"macos"`
- Có `android/` $\rightarrow$ thêm `"aos"`

Đối chiếu thêm với `Makefile` (`build-macos`, `build-ios`, `build-aos`) hoặc `pubspec.yaml`.

### Bước 4: Trích xuất Bundle ID & Package Name
- **Android (`package_name`)**:
  - `android/app/build.gradle.kts` hoặc `android/app/build.gradle` $\rightarrow$ tìm `applicationId` hoặc `namespace`.
  - Nếu không có: tìm `package` trong `android/app/src/main/AndroidManifest.xml`.
- **iOS & macOS (`bundle_id`)**:
  - `ios/Runner.xcodeproj/project.pbxproj` $\rightarrow$ tìm `PRODUCT_BUNDLE_IDENTIFIER` (loại trừ `RunnerTests`).
  - `macos/Runner/Configs/AppInfo.xcconfig` $\rightarrow$ tìm `PRODUCT_BUNDLE_IDENTIFIER`.

### Bước 5: Trích xuất Version
- Flutter: `pubspec.yaml` dòng `version: X.Y.Z+N` $\rightarrow$ lấy `X.Y.Z`.
- Android thuần: `build.gradle` $\rightarrow$ `versionName`.
- iOS thuần: `project.pbxproj` $\rightarrow$ `MARKETING_VERSION`.

### Bước 6: Trích xuất Tên hiển thị (`app_name`) & Mô tả (`description`)
Kiểm tra theo thứ tự ưu tiên:
1. Tài liệu phát hành ASO: `docs/store_release_and_aso_guide.md` hoặc `docs/*.md` (tìm App Title & Subtitle).
2. iOS `Info.plist` (`CFBundleDisplayName` hoặc `CFBundleName`).
3. Android `AndroidManifest.xml` (`android:label`).
4. `pubspec.yaml` / `README.md`.

### Bước 7: Cập nhật file `fastlane/apps.json`
- Thêm object mới vào trước dấu đóng `}` cuối cùng của `fastlane/apps.json`.
- Định dạng JSON chuẩn với thụt dòng 2 space.
- **Lưu ý quan trọng**: Không tự ý chỉnh sửa `.github/workflows/*` trừ khi người dùng yêu cầu rõ ràng.

### Bước 8: Kiểm tra tính hợp lệ
Chạy lệnh kiểm thử cú pháp:
```bash
make check-apps
```
Đảm bảo kết quả hiển thị `Hợp lệ` và app mới xuất hiện trong danh sách.

---

## 3. Công cụ tự động hỗ trợ (Helper Tool)

Có thể sử dụng script tự động quét và in ra cấu hình chuẩn:
```bash
python3 .agents/skills/fastlane-add-app/scripts/detect_app_config.py <tên_app_hoặc_đường_dẫn_trong_.workspace_code>
```
Script sẽ tự động kiểm tra điều kiện thư mục nằm trong `.workspace_code/` và trích xuất đầy đủ thông tin.

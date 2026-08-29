fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### push_api_key

```sh
[bundle exec] fastlane push_api_key
```

Mã hoá và push App Store Connect API Key lên MATCH_GIT_URL

### clean_local_certs

```sh
[bundle exec] fastlane clean_local_certs
```

Dọn dẹp các Certificate & Provisioning Profile cũ/hết hạn trên máy local

### clean_local_profiles

```sh
[bundle exec] fastlane clean_local_profiles
```

Dọn dẹp các Provisioning Profile cũ/hết hạn trên máy local

### prepare_workspace

```sh
[bundle exec] fastlane prepare_workspace
```

Chuẩn bị hoặc cập nhật mã nguồn trong .workspace cho 1 app

### init_metadata

```sh
[bundle exec] fastlane init_metadata
```

Khởi tạo thư mục và các file Metadata template mẫu cho 1 app

### push_metadata

```sh
[bundle exec] fastlane push_metadata
```

Cập nhật (Push/Upload) Metadata từ local lên App Store / Store

### upload_metadata

```sh
[bundle exec] fastlane upload_metadata
```

Cập nhật Metadata lên App Store Connect (alias: push_metadata)

### pull_metadata

```sh
[bundle exec] fastlane pull_metadata
```

Tải (Pull/Download) Metadata từ App Store / Store về máy local để chỉnh sửa

### download_metadata

```sh
[bundle exec] fastlane download_metadata
```

Tải Metadata từ App Store Connect về máy local (alias: pull_metadata)

----


## iOS

### ios register_app

```sh
[bundle exec] fastlane ios register_app
```

Đăng ký App Identifier & tạo App mới trên App Store Connect cho iOS

### ios clean_certs

```sh
[bundle exec] fastlane ios clean_certs
```

Dọn dẹp Certificate & Provisioning Profile cũ/hết hạn trên máy local

### ios sync_certs

```sh
[bundle exec] fastlane ios sync_certs
```

Đồng bộ Certificate & Provisioning Profile (Match) cho iOS (1 app hoặc tất cả apps)

### ios build

```sh
[bundle exec] fastlane ios build
```

Build Flutter IPA cho 1 app (không upload)

### ios build_ios

```sh
[bundle exec] fastlane ios build_ios
```

Build Flutter IPA cho 1 app (alias: build_ios)

### ios deploy

```sh
[bundle exec] fastlane ios deploy
```

Build Flutter IPA và Upload lên TestFlight hoặc App Store

### ios push_metadata

```sh
[bundle exec] fastlane ios push_metadata
```

Cập nhật (Push/Upload) Metadata lên App Store Connect cho iOS

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Cập nhật Metadata lên App Store Connect cho iOS (alias: push_metadata)

### ios pull_metadata

```sh
[bundle exec] fastlane ios pull_metadata
```

Tải (Pull/Download) Metadata và Screenshots từ App Store Connect về local cho iOS để chỉnh sửa

### ios download_metadata

```sh
[bundle exec] fastlane ios download_metadata
```

Tải Metadata và Screenshots từ App Store Connect về local cho iOS (alias: pull_metadata)

### ios init_metadata

```sh
[bundle exec] fastlane ios init_metadata
```

Khởi tạo thư mục và các file Metadata template mẫu cho iOS app

----


## Mac

### mac register_app

```sh
[bundle exec] fastlane mac register_app
```

Đăng ký macOS App Identifier & tạo App mới trên App Store Connect

### mac clean_certs

```sh
[bundle exec] fastlane mac clean_certs
```

Dọn dẹp Certificate & Provisioning Profile cũ/hết hạn trên máy local

### mac sync_certs

```sh
[bundle exec] fastlane mac sync_certs
```

Đồng bộ Certificate & Provisioning Profile (Match) cho macOS (1 app hoặc tất cả apps)

### mac build

```sh
[bundle exec] fastlane mac build
```

Build Flutter macOS Package (.pkg) cho 1 app (không upload)

### mac build_macos

```sh
[bundle exec] fastlane mac build_macos
```

Build Flutter macOS Package (.pkg) cho 1 app (alias: build_macos)

### mac deploy

```sh
[bundle exec] fastlane mac deploy
```

Build Flutter macOS Package và Upload lên TestFlight hoặc Mac App Store

### mac push_metadata

```sh
[bundle exec] fastlane mac push_metadata
```

Cập nhật (Push/Upload) Metadata lên Mac App Store cho macOS

### mac upload_metadata

```sh
[bundle exec] fastlane mac upload_metadata
```

Cập nhật Metadata lên Mac App Store cho macOS (alias: push_metadata)

### mac pull_metadata

```sh
[bundle exec] fastlane mac pull_metadata
```

Tải (Pull/Download) Metadata và Screenshots từ Mac App Store về local cho macOS để chỉnh sửa

### mac download_metadata

```sh
[bundle exec] fastlane mac download_metadata
```

Tải Metadata và Screenshots từ Mac App Store về local cho macOS (alias: pull_metadata)

### mac init_metadata

```sh
[bundle exec] fastlane mac init_metadata
```

Khởi tạo thư mục và các file Metadata template mẫu cho macOS app

----


## aos

### aos build

```sh
[bundle exec] fastlane aos build
```

Build Android APK hoặc App Bundle (.aab) trong .workspace

### aos build_aos

```sh
[bundle exec] fastlane aos build_aos
```

Build Android APK hoặc App Bundle (alias: build_aos)

### aos deploy

```sh
[bundle exec] fastlane aos deploy
```

Build Android App Bundle (.aab) và Deploy lên Google Play Console

### aos push_metadata

```sh
[bundle exec] fastlane aos push_metadata
```

Cập nhật (Push/Upload) Metadata & Changelogs lên Google Play Console

### aos upload_metadata

```sh
[bundle exec] fastlane aos upload_metadata
```

Cập nhật Metadata lên Google Play Console (alias: push_metadata)

### aos pull_metadata

```sh
[bundle exec] fastlane aos pull_metadata
```

Tải (Pull/Download) Metadata và Screenshots từ Google Play Store về local

### aos download_metadata

```sh
[bundle exec] fastlane aos download_metadata
```

Tải Metadata và Screenshots từ Google Play Store về local (alias: pull_metadata)

### aos init_metadata

```sh
[bundle exec] fastlane aos init_metadata
```

Khởi tạo thư mục và các file Metadata template mẫu cho Android (AOS)

----


## Android

### android build

```sh
[bundle exec] fastlane android build
```

Build Android APK hoặc App Bundle (.aab) trong .workspace

### android build_android

```sh
[bundle exec] fastlane android build_android
```

Build Android APK hoặc App Bundle (alias: build_android)

### android deploy

```sh
[bundle exec] fastlane android deploy
```

Build Android App Bundle (.aab) và Deploy lên Google Play Console

### android push_metadata

```sh
[bundle exec] fastlane android push_metadata
```

Cập nhật (Push/Upload) Metadata & Changelogs lên Google Play Console

### android upload_metadata

```sh
[bundle exec] fastlane android upload_metadata
```

Cập nhật Metadata lên Google Play Console (alias: push_metadata)

### android pull_metadata

```sh
[bundle exec] fastlane android pull_metadata
```

Tải (Pull/Download) Metadata và Screenshots từ Google Play Store về local

### android download_metadata

```sh
[bundle exec] fastlane android download_metadata
```

Tải Metadata và Screenshots từ Google Play Store về local (alias: pull_metadata)

### android init_metadata

```sh
[bundle exec] fastlane android init_metadata
```

Khởi tạo thư mục và các file Metadata template mẫu cho Android

----


## windows

### windows init_metadata

```sh
[bundle exec] fastlane windows init_metadata
```

Khởi tạo thư mục và các file Metadata template mẫu cho Windows app

### windows upload_metadata

```sh
[bundle exec] fastlane windows upload_metadata
```

Kiểm tra và chuẩn bị Metadata Windows cho phát hành

### windows build

```sh
[bundle exec] fastlane windows build
```

Build Flutter Windows Release Executable (.exe / .zip)

----


## linux

### linux init_metadata

```sh
[bundle exec] fastlane linux init_metadata
```

Khởi tạo thư mục và các file Metadata template mẫu cho Linux app

### linux upload_metadata

```sh
[bundle exec] fastlane linux upload_metadata
```

Kiểm tra và chuẩn bị Metadata Linux cho phát hành (AppStream / Metainfo)

### linux build

```sh
[bundle exec] fastlane linux build
```

Build Flutter Linux Release Executable / Bundle

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

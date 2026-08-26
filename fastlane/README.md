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

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

# Component Inventory

## Application Packages / Managed Targets
- `web-clone` - Electron multi-session desktop browser (macOS, Windows, Linux).
- `CloudOps` - Multi-platform CloudOps Hub (iOS, macOS, Android).
- `session_browser_app` - Multi-session browser app (iOS, macOS, Android).
- `app_github_pro` - Git client for GitHub (iOS, macOS, Android).
- `app_Lam_Toan_Tre_Con` - Math visual adventure (iOS, Android).
- `app-snapvid` - Video to Photo extractor (iOS, Android).
- `app-QuestFlow` - RPG gamified task app (iOS, macOS, Android).
- `app_Comparison_Table_App` - Decision matrix application (iOS, macOS, Android).
- `app-dem-tien-vn` - VND cash counter (iOS, macOS, Android).
- `app-dem-tien-jp` - JPY currency calculator (iOS, macOS, Android).
- `AR-Drawing` - AR camera sketch app (iOS, Android).
- `app-dem-tien-usd` - USD cash counter (iOS, macOS, Android).
- `app-dem-tien-china` - RMB cash counter (iOS, macOS, Android).
- `app-dem-tien-eur` - EUR cash counter (iOS, macOS, Android).
- `app-go-mo-niem-phat` - Temple wooden fish mindfulness (iOS, macOS, Android).
- `app-remove-app` - Android fast uninstaller (Android).

## Infrastructure & Workflow Components
- `build-standalone-fastlane.yml` - Standalone desktop builds for macOS, Windows, Linux.
- `deploy-macos-fastlane.yml` - Mac App Store & TestFlight delivery.
- `deploy-ios-fastlane.yml` - iOS TestFlight & App Store delivery.
- `deploy-aos-fastlane.yml` - Google Play Store deployment.
- `register-apple-fastlane.yml` - Automated Apple Developer Portal bundle identifier creation.
- `sync-certs-fastlane.yml` - Match keystore certificate synchronization.

## Shared Packages & Helpers
- `fastlane/lanes/standalone.rb` - Standalone packaging logic.
- `fastlane/helpers/app_config_helper.rb` - Metadata and version parsing.
- `fastlane/helpers/git_workspace_helper.rb` - Workspace and subshell execution.
- `fastlane/helpers/cert_helper.rb` - Code signing identities and Match keychain integration.
- `fastlane/helpers/apple_registration_helper.rb` - App Store Connect / Developer Portal registration.
- `fastlane/helpers/metadata_helper.rb` - Store metadata and screenshot processing.
- `fastlane/helpers/google_key_helper.rb` - Google Play Console service account credentials.

## Total Count
- **Total Managed Applications**: 16
- **Desktop Standalone Platforms**: 3 (macOS, Windows, Linux)
- **CI/CD Workflows**: 8
- **Core Fastlane Helper Modules**: 7

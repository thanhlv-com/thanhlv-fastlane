# Technology Stack

## Programming Languages
- **Ruby**: ~> 3.3 (Fastlane automation engine, helper scripts)
- **Bash / Shell**: macOS / Linux orchestration scripts and workflow steps
- **TypeScript / JavaScript**: Node.js 22, Electron 39, Vite 7 (Target application `web-clone`)
- **Dart**: Flutter SDK 3.x (Target Flutter applications)

## Frameworks & Toolchains
- **Fastlane**: 2.222.0+ (Lane management, Match, App Store Connect Spaceship integration)
- **Electron**: ^39.2.6 (Desktop cross-platform runtime for `web-clone`)
- **Electron-Builder**: ^26.0.12 (Native packaging for DMG, EXE, AppImage, and code signing integration)
- **Vite & Electron-Vite**: ^5.0.0 (TypeScript compilation and web frontend bundling)
- **React**: ^19.2.1 (Frontend UI layer for `web-clone`)

## Build & Signing Tools
- **xcrun notarytool**: Apple Notary Service API submission tool for Gatekeeper approval
- **xcrun stapler**: Attaches notarization tickets to DMG and app bundles
- **security (macOS)**: Keychain search list, cert identity inspection, and PKCS#12 import
- **openssl**: Certificate and private key conversion and verification

## CI/CD Infrastructure
- **GitHub Actions**: Runners: `macos-latest`, `windows-latest`, `ubuntu-latest`
- **GitHub App Authentication**: `actions/create-github-app-token@v1` for private repo access
- **Telegram Bot API**: Real-time webhook notifications for build results

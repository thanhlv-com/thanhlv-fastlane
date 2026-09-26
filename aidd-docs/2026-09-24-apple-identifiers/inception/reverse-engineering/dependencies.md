# Dependencies

## Gem Dependencies (`Gemfile`)
- `fastlane` (~> 2.222 or latest)
- `cocoapods`
- Fastlane Core libraries: `fastlane_core`, `spaceship`, `produce`, `credentials_manager`

## System Dependencies
- macOS with Xcode Command Line Tools
- `security` CLI (macOS Keychain utility)
- `openssl` (for AES-256 decryption of API Keys)
- `git` (with SSH/HTTPS access to GitHub repositories)
- App Store Connect API Key (`AuthKey_<KEY_ID>.p8`) with Admin or App Manager access

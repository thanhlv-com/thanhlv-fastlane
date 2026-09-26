# Units of Work (UOW) Specification

## UOW-01: Core Apple Registration Helper
- **File**: `fastlane/helpers/apple_registration_helper.rb`
- **Scope**:
  - Implement query to check existing Bundle IDs on Apple Developer Portal via `Spaceship::ConnectAPI.get_bundle_ids`.
  - Implement creation of missing Bundle IDs via `Spaceship::ConnectAPI.post_bundle_id`.
  - Implement query to check existing App on App Store Connect via `Spaceship::ConnectAPI.get_apps`.
  - Implement creation of missing App via Fastlane `produce(skip_devcenter: true)`.
  - Implement batch iterator and formatted summary table.
- **Verification**: Syntax check `ruby -c fastlane/helpers/apple_registration_helper.rb`.

---

## UOW-02: Fastlane Lanes Integration
- **Files**: `fastlane/Fastfile`, `fastlane/lanes/ios.rb`, `fastlane/lanes/macos.rb`
- **Scope**:
  - Import `helpers/apple_registration_helper.rb` in `Fastfile`.
  - Update `ios :register_app` to delegate to `verify_and_register_apple_app` and support `app:all`.
  - Update `mac :register_app` to delegate to `verify_and_register_apple_app` and support `app:all`.
  - Add root `lane :register_apps` to support batch processing across iOS & macOS.
- **Verification**: `fastlane --help` / lane listing verification.

---

## UOW-03: Makefile Targets & Interactive CLI Menu
- **Files**: `Makefile`, `scripts/interactive_menu.rb`
- **Scope**:
  - Update `register-app-ios` and `register-app-mac` targets to handle default `APP=all`.
  - Add target `register-apps` supporting `APP` and `PLATFORM`.
  - Add interactive menu entry under Option 6 (Certificates & API Keys) in `scripts/interactive_menu.rb` to guide user through platform & app selection.
- **Verification**: Run `ruby -c scripts/interactive_menu.rb` and test menu navigation.

---

## UOW-04: End-to-End Validation & Documentation
- **Files**: `fastlane/README.md`, `Makefile` (help comments)
- **Scope**:
  - Document new commands, options, and behaviors in `fastlane/README.md`.
  - Verify error handling and graceful fallback with simulated missing / existing scenarios.
- **Verification**: Validate all documentation and syntax across changed files.

# Requirements Document

## 1. Overview
The purpose of this feature is to add automated Apple Identifiers (App IDs, Bundle IDs, and Capabilities) registration capabilities to `thanhlv-fastlane`. This feature enables developers to register identifiers on the Apple Developer Portal efficiently, safely, and idempotently without unnecessary manual operations or unwanted App Store Connect app creation.

## 2. Functional Requirements

### FR-01: Pure App Identifier Registration (Apple Developer Portal)
- The system shall register the primary bundle identifier on the Apple Developer Portal using Fastlane `produce` with `skip_itc: true` (or Spaceship Connect API).
- The system shall authenticate via App Store Connect API Key (`.p8`) retrieved using `get_api_key`.
- The system shall support customizable display names derived from `app_name` in `apps.json` or overridden via options.

### FR-02: Multi-Platform Support (iOS & macOS)
- The system shall support registering iOS identifiers with platform specification `ios`.
- The system shall support registering macOS identifiers with platform specification `mac` / `osx`.
- The system shall validate platform compatibility against `platforms` defined in `fastlane/apps.json`.

### FR-03: Single-App and Batch Processing
- The system shall allow registering an identifier for a specific app key (`app:<app_key>`).
- The system shall allow batch registration across all apps (`app:all`) supporting Apple platforms (`ios`, `macos`).
- In batch mode, errors on a single app shall be recorded and reported, allowing remaining apps to continue processing.

### FR-04: Capabilities and Entitlements Configuration
- The system shall allow enabling Apple services/capabilities on the registered identifier (e.g., Push Notifications, Associated Domains, In-App Purchase, Sign in with Apple, App Groups).
- Capabilities configuration shall be read from `fastlane/apps.json` if specified, or via lane options.

### FR-05: Idempotency & Error Handling
- If a bundle identifier already exists on the developer portal, the system shall treat it as a non-fatal warning/success and continue execution.
- Clear, colorized log messages shall be output informing the developer of the exact status of each identifier.

### FR-06: CLI & Makefile Integration
- Provide dedicated Fastlane lanes:
  - `fastlane ios register_identifier app:<key>`
  - `fastlane mac register_identifier app:<key>`
  - `fastlane register_identifiers [app:<key>|all] [platform:ios|macos|all]`
- Provide Makefile targets:
  - `make register-identifier-ios APP=<key>`
  - `make register-identifier-mac APP=<key>`
  - `make register-identifiers [APP=<key>] [PLATFORM=all|ios|macos]`
- Integrate into `scripts/interactive_menu.rb` to allow interactive selection and execution.

## 3. Non-Functional Requirements
- **Security**: Must use existing App Store Connect API Key infrastructure (`AuthKey_*.p8`) without exposing keys or credentials.
- **Maintainability**: Follow existing helper patterns (`helpers/app_config_helper.rb`, `helpers/api_key_helper.rb`).
- **Usability**: Provide informative logging and clear user prompts in interactive CLI.

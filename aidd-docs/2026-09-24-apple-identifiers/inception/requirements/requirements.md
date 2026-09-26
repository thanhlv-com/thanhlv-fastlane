# Requirements Document

## 1. Overview
The purpose of this feature is to add automated verification and registration of **Apple Identifiers** on the **Apple Developer Portal** (`https://developer.apple.com/account/resources/identifiers/list`) and **Applications** on **App Store Connect** (`https://appstoreconnect.apple.com/apps`) into `thanhlv-fastlane`.

The feature ensures full idempotency: for any given application (or batch of applications), it checks whether the identifier or app already exists; if present, it reports the existing status and skips duplicate creation; if missing, it registers the identifier and/or creates the app record.

---

## 2. Functional Requirements

### FR-01: Apple Developer Portal Identifier Verification & Registration
- **Location**: Apple Developer Portal (`https://developer.apple.com/account/resources/identifiers/list`).
- The system shall check whether the target Bundle ID / App Identifier is already registered.
- If the identifier already exists:
  - The system shall log an informational message (e.g. `[EXISTS] Identifier com.example.app already exists on Developer Portal`) and skip creation.
- If the identifier does NOT exist:
  - The system shall automatically register the new App ID using the App Store Connect API (`Spaceship::ConnectAPI.post_bundle_id`).
- The system shall support authentication via App Store Connect API Key (`AuthKey_*.p8`) loaded via `get_api_key`.

### FR-02: App Store Connect Application Verification & Creation
- **Location**: App Store Connect Apps (`https://appstoreconnect.apple.com/apps`).
- The system shall check whether an application with the matching Bundle ID exists in App Store Connect.
- If the application already exists:
  - The system shall log an informational message (e.g. `[EXISTS] App com.example.app (ID: 123456789) already exists on App Store Connect`) and skip app creation.
- If the application does NOT exist:
  - The system shall create the application record on App Store Connect using Fastlane `produce` or `Spaceship::ConnectAPI`, utilizing `app_name` from `apps.json` and default primary language `English`.
- If an app name collision occurs on App Store Connect (e.g., name already taken globally), the system shall capture the warning/error gracefully and provide actionable remediation guidance without halting batch executions.

### FR-03: Multi-Platform Support (iOS & macOS)
- The system shall support both **iOS** (`ios`) and **macOS** (`macos` / `osx`).
- When registering for iOS, platform shall be specified as `IOS`.
- When registering for macOS, platform shall be specified as `MAC_OS`.
- The system shall validate platform compatibility against the `platforms` array configured in `fastlane/apps.json`.

### FR-04: Single App and Batch Processing Modes
- **Single App Mode**:
  - Accepts `app:<app_key>` or `APP=<app_key>` to target a single application.
- **Batch Mode**:
  - Accepts `app:all` or `APP=all` (or omission in top-level lanes) to automatically process all apps defined in `fastlane/apps.json` that support Apple platforms (`ios` or `macos`).
  - At the end of batch execution, the system shall print a formatted summary report table displaying:
    - App Key
    - Platform (`ios` / `macos`)
    - Bundle ID
    - Developer Portal Status (`EXISTS`, `CREATED`, or `FAILED`)
    - App Store Connect Status (`EXISTS`, `CREATED`, or `FAILED`)

### FR-05: Idempotency & Fault Tolerance
- Re-running the command multiple times shall be safe and produce identical end results without creating duplicate entries or throwing errors.
- In batch mode, if one application encounters an error (e.g. invalid permissions or global name conflict), the system shall record the failure, log the error, and continue processing the remaining applications.

### FR-06: Secondary Identifiers (App Groups & Extensions)
- If an app entry in `fastlane/apps.json` defines secondary identifiers (such as `extensions` or `app_groups`), the system shall also check and register those secondary identifiers on the Developer Portal if not already present.

### FR-07: Integration Across All Project Entrypoints
- **Fastlane Lanes**:
  - `fastlane ios register_app [app:<key>|all]`
  - `fastlane mac register_app [app:<key>|all]`
  - Root lane: `fastlane register_apps [app:<key>|all] [platform:ios|macos|all]` (or `fastlane register_identifiers`)
- **Makefile Targets**:
  - `make register-app-ios [APP=<key>]` (defaults to all or prompts if not specified)
  - `make register-app-mac [APP=<key>]`
  - `make register-app-all` / `make register-apps [APP=all] [PLATFORM=all|ios|macos]`
- **Interactive CLI Menu (`scripts/interactive_menu.rb`)**:
  - Add an interactive option under Option 6 (Certificates & Apple Management) or a dedicated sub-menu:
    - `🍎 Kiểm tra & Đăng ký Apple Identifiers & App Store Connect App`
    - Prompts the user to select Target Platform (`iOS`, `macOS`, or `All Apple Platforms`) and Target App (`Specific App` or `Tất cả các apps`).

---

## 3. Non-Functional Requirements

### NFR-01: Security & Credential Isolation
- Must strictly use existing App Store Connect API Key infrastructure (`.p8`) via `get_api_key`.
- Never write API secrets or unencrypted keys to disk or repository commits.

### NFR-02: Performance & Network Efficiency
- Minimize redundant API roundtrips by querying bundle IDs and apps with batch/filter parameters where possible.
- Provide responsive execution with real-time feedback during batch operations.

### NFR-03: Usability & Terminal User Experience
- Provide clear, color-coded console logs (`UI.message`, `UI.success`, `UI.important`, `UI.error`).
- Use step indicators: `[1/2] Checking Developer Portal Identifier...`, `[2/2] Checking App Store Connect App...`.
- Final summary table displaying results across all processed apps.

### NFR-04: Maintainability & Code Consistency
- Encapsulate the core verification and registration logic in a dedicated helper function (e.g. `verify_and_register_apple_app` in `fastlane/helpers/cert_helper.rb` or `fastlane/helpers/app_config_helper.rb`).
- Re-use helper logic across both iOS and macOS lanes to adhere to DRY (Don't Repeat Yourself).

# User Stories & Acceptance Criteria

---

## US-01: Idempotent Single-App Verification and Registration
**As a** Mobile Developer or DevOps Engineer,  
**I want to** run a command to check and register the Bundle ID on Apple Developer Portal and the App on App Store Connect for a specific app,  
**So that** the application is provisioned and ready for code signing and TestFlight deployment without manual portal actions.

### Acceptance Criteria:
- **Scenario 1: Neither Identifier nor App exists**
  - **Given** an app `demo_app` defined in `fastlane/apps.json` with Bundle ID `com.thanhlv.demo`
  - **And** `com.thanhlv.demo` is not present on Developer Portal or App Store Connect
  - **When** I run `fastlane ios register_app app:demo_app` (or `make register-app-ios APP=demo_app`)
  - **Then** the Bundle ID is registered on Developer Portal with status `[CREATED]`
  - **And** the App record is created on App Store Connect with status `[CREATED]`

- **Scenario 2: Identifier exists, App does not exist**
  - **Given** `com.thanhlv.demo` is already registered on Developer Portal
  - **And** `com.thanhlv.demo` is not yet on App Store Connect
  - **When** I run `fastlane ios register_app app:demo_app`
  - **Then** Developer Portal check outputs `[EXISTS]` and skips registration
  - **And** the App is created on App Store Connect with status `[CREATED]`

- **Scenario 3: Both Identifier and App already exist**
  - **Given** both `com.thanhlv.demo` and its App Store Connect record exist
  - **When** I run `fastlane ios register_app app:demo_app`
  - **Then** the command outputs `[EXISTS]` for both
  - **And** completes with exit code 0 without errors

---

## US-02: Batch Verification and Registration across All Apple Apps
**As a** DevOps Engineer,  
**I want to** verify and register all Apple-supported apps in one single command (`APP=all`),  
**So that** I can onboard or sync multiple applications simultaneously.

### Acceptance Criteria:
- **Scenario 1: Full batch execution**
  - **Given** `fastlane/apps.json` contains multiple apps targeting `ios` or `macos`
  - **When** I run `fastlane register_apps app:all platform:all` (or `make register-apps`)
  - **Then** the system filters all apps supporting Apple platforms
  - **And** processes each app sequentially across iOS and macOS
  - **And** prints a formatted summary table listing App Key, Platform, Bundle ID, Portal Status, and ASC Status

- **Scenario 2: Partial failure tolerance**
  - **Given** one app in the batch has a globally conflicted name on App Store Connect
  - **When** the batch runs
  - **Then** that app logs `[FAILED]` with descriptive guidance
  - **And** the batch continues to process the remaining apps
  - **And** the final summary table clearly indicates the failed app alongside the successful ones

---

## US-03: Interactive CLI Wizard for Apple Registration
**As a** Developer using the terminal,  
**I want to** navigate via `scripts/interactive_menu.rb` to register Apple Identifiers & Apps,  
**So that** I don't have to remember command syntax or app keys.

### Acceptance Criteria:
- **Scenario 1: Interactive execution**
  - **When** I launch `./menu.sh` (or `ruby scripts/interactive_menu.rb`)
  - **And** select Option 6 (Certificates & Apple Management)
  - **Then** I see an option for `🍎 Kiểm tra & Đăng ký Apple Identifiers & App Store Connect App`
  - **And** selecting it allows choosing platform (`iOS`, `macOS`, `All`) and app (`All` or specific app)
  - **And** it triggers the corresponding registration workflow

---

## US-04: Multi-Platform (iOS & macOS) Support
**As a** Developer releasing desktop and mobile apps,  
**I want to** specify `ios` or `macos` when registering identifiers,  
**So that** macOS-specific bundle IDs (and platform codes `MAC_OS` / `osx`) and iOS bundle IDs (`IOS` / `ios`) are accurately configured.

### Acceptance Criteria:
- **Scenario 1: macOS registration**
  - **Given** an app supporting `macos`
  - **When** I run `fastlane mac register_app app:<app_key>` (or `make register-app-mac APP=<app_key>`)
  - **Then** the platform used on Developer Portal is `MAC_OS` and on App Store Connect is `osx`

# Fastlane Lanes & CLI Interface Documentation

## Existing Apple Registration Lanes

### 1. `fastlane ios register_app`
- **Purpose**: Registers an Apple App Identifier on Apple Developer Portal and creates the corresponding App record in App Store Connect.
- **Parameters**:
  - `app` (Required): Application key matching `fastlane/apps.json`.
  - `bundle_id` (Optional): Overrides bundle identifier.
- **Action**: Uses Fastlane's `produce` action with `skip_itc: false`.

### 2. `fastlane mac register_app`
- **Purpose**: Registers a macOS App Identifier on Apple Developer Portal and creates the corresponding macOS App record in App Store Connect.
- **Parameters**:
  - `app` (Required): Application key matching `fastlane/apps.json`.
  - `bundle_id` (Optional): Overrides bundle identifier.
- **Action**: Uses Fastlane's `produce` action with `platform: "osx"` and `skip_itc: false`.

## Existing Makefile Targets for App Registration
- `make register-app-ios APP=<app_key>`: Executes `fastlane ios register_app app:$(APP)`.
- `make register-app-mac APP=<app_key>`: Executes `fastlane mac register_app app:$(APP)`.

## Identified Limitations & Feature Deficiencies
1. **No Pure Identifier Registration**: Cannot register an Identifier (App ID) on Apple Developer Portal without attempting to create an ITC app record. If an app record already exists or ITC creation is not desired, `produce` with `skip_itc: false` can fail or prompt unnecessarily.
2. **No Batch Identifier Registration**: Developers cannot run a single command to ensure all iOS and macOS identifiers for all registered apps exist on Apple Developer Portal.
3. **No Capabilities / Services Configuration**: No support for automatically enabling required capabilities (Push Notifications, Associated Domains, In-App Purchase, Sign in with Apple, App Groups) when registering identifiers.
4. **Missing from Interactive Menu CLI**: `scripts/interactive_menu.rb` contains no option to register Apple apps or identifiers.
5. **Missing Cross-Platform Root Lane**: No root `lane :register_identifiers` in `Fastfile` to handle multi-platform registration across all apps or a single app.

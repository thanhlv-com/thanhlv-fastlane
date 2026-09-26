# Requirement Verification Questions

Please review the following verification questions and confirmation. The answers have been aligned with your latest specification to check and create Identifiers on the Apple Developer Portal if missing, and check and create the App on App Store Connect if missing.

---

## Question 1: Scope of Apple Identifier & App Registration
How should the feature behave regarding Apple Developer Portal and App Store Connect?

A) **Pure App Identifier Only**: Registers the Bundle ID / App ID strictly on the Apple Developer Portal with `skip_itc: true` (does not create the App record on App Store Connect).
B) **Dual Check & Registration (Developer Portal + App Store Connect) (Recommended)**: Explicitly checks if the Bundle ID / Identifier exists at `https://developer.apple.com/account/resources/identifiers/list` and creates it if missing; additionally checks if the application exists at `https://appstoreconnect.apple.com/apps` and creates it if missing.
C) **App Store Connect App Creation Only**: Assumes Bundle ID already exists and only registers the app on App Store Connect.
X) Other (write your explanation after the [Answer]: tag)

[Answer]: B

---

## Question 2: Target Platforms and Batch Processing
Which platforms and execution modes should be supported?

A) **iOS + macOS with Single App & Batch ('all') Support (Recommended)**: Supports both iOS and macOS platforms. Allows running for a single specific app (`APP=<app_key>`) OR batch registering all Apple-supported apps (`APP=all` / `fastlane register_app app:all`) in one run.
B) **Single App Only (iOS + macOS)**: Supports iOS and macOS, but only allows registering one app at a time (`APP=<app_key>`).
C) **iOS Only**: Supports only iOS applications.
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A

---

## Question 3: User Interface & Integration Touchpoints
Where should this new check & registration feature be exposed across the repository?

A) **Comprehensive Integration across All Layers (Recommended)**:
   1. Fastlane lanes: Enhanced `fastlane ios register_app`, `fastlane mac register_app`, and root lane `fastlane register_apps [app:<key>|all] [platform:ios|macos|all]`.
   2. Makefile targets: `make register-app-ios [APP=<key>]`, `make register-app-mac [APP=<key>]`, `make register-app-all` / `make register-apps`.
   3. Interactive CLI Menu: Add interactive option under Certificates/Apple Management in `scripts/interactive_menu.rb`.
   4. Helper Logic: Dedicated helper methods in `fastlane/helpers/app_config_helper.rb` or `fastlane/helpers/cert_helper.rb` for verification and registration.
B) **Fastlane Lanes + Makefile Only**: Expose via Fastlane and Makefile targets without modifying `scripts/interactive_menu.rb`.
C) **Fastlane Lanes Only**: Expose only as Fastlane lanes.
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A

---

## Question 4: Idempotency & Conflict Handling
How should the verification and registration logic handle items that already exist on Apple Developer Portal or App Store Connect?

A) **Idempotent / Graceful Handling (Recommended)**:
   - If the Bundle ID / Identifier is already registered at `developer.apple.com/account/resources/identifiers/list`, display a clear `[EXISTS]` status and skip re-creation without error.
   - If the App is already created at `appstoreconnect.apple.com/apps`, display a clear `[EXISTS]` status and skip re-creation without error.
   - If missing in either or both, create only what is missing.
   - In batch mode (`APP=all`), continue processing all remaining apps even if one app encounters an error (e.g. app name conflict on App Store Connect).
B) **Strict Failure**: If an identifier or app already exists, throw an error and halt execution immediately.
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A

---

## Question 5: Additional Identifiers (Extensions & App Groups)
Should the feature support checking and registering secondary identifiers (e.g. Notification Service Extensions, Widget Extensions, App Groups)?

A) **Yes, support Primary App ID + Optional Extensions/App Groups (Recommended)**: If an app in `apps.json` defines `extensions` (e.g., `com.example.app.OneSignalNotificationServiceExtension`) or `app_groups` (e.g., `group.com.example.app`), automatically check and register those identifiers as well on Developer Portal.
B) **Primary App ID Only**: Only check and register the main application bundle ID (`bundle_id`).
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A

---

## Question 6: Verification & Creation Strategy
How should the system verify and create resources on Apple Developer Portal and App Store Connect?

A) **Two-Step Verification with Spaceship ConnectAPI + Fastlane Produce (Recommended)**:
   - Step 1: Connect via App Store Connect API Key (`.p8`). Query `Spaceship::ConnectAPI.get_bundle_ids` to verify the Bundle ID on Developer Portal (`developer.apple.com/account/resources/identifiers/list`). If missing, create it using `Spaceship::ConnectAPI.post_bundle_id`.
   - Step 2: Query `Spaceship::ConnectAPI.get_apps` to verify if the app exists on App Store Connect (`appstoreconnect.apple.com/apps`). If missing, create it using Fastlane `produce(skip_devcenter: true)`.
   - Display clear step-by-step terminal outputs (`[1/2] Checking Developer Portal...`, `[2/2] Checking App Store Connect...`).
B) **Standard Fastlane Produce with Rescue**: Directly call `produce` with `skip_itc: false`, relying on its internal check mechanisms and catching existing errors.
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A

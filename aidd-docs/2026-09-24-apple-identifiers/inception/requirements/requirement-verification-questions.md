# Requirement Verification Questions

Please review the following verification questions and provide your choices by writing your answers directly after each `[Answer]:` tag in this file.

---

## Question 1: Scope of Apple Identifier Registration
How should the Apple Identifier registration feature behave regarding App Store Connect and capabilities?

A) **Pure App Identifier & Capabilities Registration (Recommended)**: Registers the Bundle ID / App ID strictly on the Apple Developer Portal with `skip_itc: true` (does not attempt to create the App record on App Store Connect). Supports enabling Apple capabilities/services (such as Push Notifications, Associated Domains, Sign in with Apple, In-App Purchase, App Groups) configured in `apps.json` or passed as parameters.
B) **Dual Mode (Pure Identifier OR Full App Creation)**: Provides a flag/option to choose between registering pure Identifier on Developer Portal (`skip_itc: true`) or creating both Identifier and App Store Connect app (`skip_itc: false`).
C) **Basic Bundle ID Registration Only**: Registers only the Bundle ID on Apple Developer Portal without configuring capabilities or services.
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A

---

## Question 2: Target Platforms and Batch Processing
Which platforms and execution modes should be supported?

A) **iOS + macOS with Single App & Batch ('all') Support (Recommended)**: Supports both iOS and macOS platforms. Allows running for a single specific app (`APP=<app_key>`) OR batch registering all Apple-supported apps (`APP=all` / `fastlane register_identifiers`) in one run.
B) **Single App Only (iOS + macOS)**: Supports iOS and macOS, but only allows registering one app at a time (`APP=<app_key>`).
C) **iOS Only**: Supports only iOS applications.
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A

---

## Question 3: User Interface & Integration Touchpoints
Where should this new registration feature be exposed across the repository?

A) **Comprehensive Integration across All Layers (Recommended)**:
   1. Fastlane lanes: `fastlane ios register_identifier`, `fastlane mac register_identifier`, and root lane `fastlane register_identifiers`.
   2. Makefile targets: `make register-identifier-ios`, `make register-identifier-mac`, `make register-identifiers`.
   3. Interactive CLI Menu: Add interactive prompts in `scripts/interactive_menu.rb` (under Certificates/Apple Management).
   4. Helper Logic: Dedicated helper method in `helpers/app_config_helper.rb` or `helpers/cert_helper.rb` / `helpers/api_key_helper.rb`.
B) **Fastlane Lanes + Makefile Only**: Expose via Fastlane and Makefile targets without modifying `scripts/interactive_menu.rb`.
C) **Fastlane Lanes Only**: Expose only as Fastlane lanes.
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A

---

## Question 4: Idempotency & Conflict Handling
How should the registration logic handle identifiers that already exist on Apple Developer Portal?

A) **Idempotent / Graceful Handling (Recommended)**: If the Bundle ID is already registered, report success / warning with an informational notice, verify or enable requested capabilities without throwing a fatal crash. In batch mode (`APP=all`), continue processing the remaining apps even if one identifier already exists.
B) **Strict Failure**: If an identifier already exists, throw an error and halt execution immediately.
X) Other (write your explanation after the [Answer]: tag)

[Answer]: B

---

## Question 5: Additional Identifiers (Extensions & App Groups)
Should the feature support registering secondary identifiers (e.g. Notification Service Extensions, Widget Extensions, App Groups)?

A) **Yes, support Primary App ID + Optional Extensions/App Groups (Recommended)**: If an app in `apps.json` defines `extensions` (e.g., `com.example.app.OneSignalNotificationServiceExtension`) or `app_groups` (e.g., `group.com.example.app`), automatically register those identifiers as well.
B) **Primary App ID Only**: Only register the main application bundle ID (`bundle_id`).
X) Other (write your explanation after the [Answer]: tag)

[Answer]: A

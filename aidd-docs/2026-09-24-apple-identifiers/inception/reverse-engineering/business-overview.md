# Business Overview

## System Purpose
`thanhlv-fastlane` is a centralized multi-app CI/CD and release automation repository designed to streamline building, signing, code obfuscation, provisioning, metadata synchronization, and store distribution for mobile and desktop applications (iOS, macOS, Android/AOS, Windows, and Linux).

## Key Objectives & Value Proposition
- **Multi-App Orchestration**: Manages 11+ applications listed in `fastlane/apps.json`, each with distinct bundle identifiers, package names, git repositories, and release flavors.
- **Fastlane & Match Integration**: Automated certificate generation, encrypted keychain synchronization, and provisioning profile management using Git-backed encrypted repositories (`MATCH_GIT_URL`).
- **Two-Way Store Metadata Sync**: Automated downloading, uploading, template generation, and localization across top 20 App Store and Google Play locales.
- **Interactive CLI & Make Tooling**: Provides an intuitive command-line interface (`scripts/interactive_menu.rb`) and Makefile targets to prevent manual configuration errors.
- **App Store Connect & Apple Developer Operations**: Supports API Key authentication (`.p8`), app creation, code signing, and deployment to TestFlight and App Store.

## Problem Statement & Need for Apple Identifiers Registration
Currently, the repository has an `ios register_app` and `mac register_app` lane that relies on Fastlane's `produce` action with `skip_itc: false`. This creates both the App ID on the Apple Developer Portal and an App record on App Store Connect.
However, developers frequently need to:
1. Register only the App Identifier (Bundle ID / App ID) on the Apple Developer Portal without attempting to create an App Store Connect app entry (`skip_itc: true`).
2. Batch register Apple App Identifiers for all iOS and macOS applications in `apps.json` with a single command.
3. Register supplementary identifiers such as App Extensions (Notification Service Extensions, Widget Extensions) or App Groups.
4. Enable or configure capabilities/services (such as Push Notifications, In-App Purchase, Associated Domains, Sign in with Apple) directly during identifier registration.
5. Access this capability easily from the Makefile (`make register-identifier-ios`, `make register-identifier-mac`, `make register-identifiers`), Fastlane lanes, and the interactive terminal menu (`scripts/interactive_menu.rb`).

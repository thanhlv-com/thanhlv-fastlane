# Technology Stack

## Core Technologies

- **Fastlane**: Automation engine (`produce`, `match`, `gym`, `deliver`, `pilot`).
- **Ruby**: Programming language for Fastfile, lanes, helpers, and CLI scripts (Ruby 3.x+).
- **Fastlane Spaceship**: Underlying Ruby library interacting directly with Apple Developer Portal and App Store Connect API.
- **GNU Make**: Build automation and command standardization via `Makefile`.
- **JSON**: Configuration registry format (`fastlane/apps.json`).
- **OpenSSL & Apple Security CLI**: Certificate inspection, keychain interactions, and AES-256 decryption.
- **Git**: Version control and backend for Match encrypted certificate storage.
- **GitHub Actions**: Cloud CI/CD workflows executing Fastlane in macOS runner environments.

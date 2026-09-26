# Component Inventory

## Inventory of Repository Components

| Component / File | Category | Description | Relevance to Identifier Registration |
|---|---|---|---|
| `fastlane/Fastfile` | Orchestration | Root lane definitions and helper imports | Needs root lane `register_identifiers` |
| `fastlane/lanes/ios.rb` | Platform Lane | iOS build, signing, and registration logic | Needs `register_identifier` lane |
| `fastlane/lanes/macos.rb` | Platform Lane | macOS build, signing, and registration logic | Needs `register_identifier` lane |
| `fastlane/helpers/app_config_helper.rb` | Helper | Reads `apps.json`, resolves identifiers and configurations | Supports resolving bundle IDs, can parse capabilities if added |
| `fastlane/helpers/api_key_helper.rb` | Helper | Loads App Store Connect API Key (`.p8`) | Used for authenticating `produce` and Spaceship calls |
| `fastlane/helpers/cert_helper.rb` | Helper | Manages keychain and provisioning certificates | Related to signing identities generated after identifiers |
| `scripts/interactive_menu.rb` | CLI Tooling | Interactive terminal menu for operations | Needs submenu / action for Apple Identifier registration |
| `Makefile` | CLI Entrypoint | Build and management command targets | Needs `register-identifier-ios`, `register-identifier-mac`, `register-identifiers` |
| `fastlane/apps.json` | Configuration | App registry containing bundle IDs and metadata | Source of bundle IDs and platform mappings for batch registration |
| `.github/workflows/` | CI/CD | GitHub Actions pipelines | Can include automated identifier verification / registration workflow |

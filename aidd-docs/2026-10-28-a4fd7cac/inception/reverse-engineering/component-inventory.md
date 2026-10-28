# Component Inventory - thanhlv-fastlane

## 1. Component Categories

### CI/CD Workflows (`.github/workflows/`)
- `build-standalone-fastlane.yml`: Multi-OS runner orchestration for Electron/Flutter desktop apps.
- `deploy-macos-fastlane.yml`, `deploy-ios-fastlane.yml`, `deploy-aos-fastlane.yml`: Mobile & App Store deployment workflows.
- `sync-certs-fastlane.yml`, `register-apple-fastlane.yml`: Apple developer portal provisioning pipelines.

### Fastlane Lanes (`fastlane/lanes/`)
- `standalone.rb`: Builds, codesigns, notarizes, and exports desktop binaries.
- `macos.rb`, `ios.rb`, `aos.rb`: Platform-specific mobile/desktop store lanes.

### Configuration & Data Registries (`fastlane/`)
- `apps.json`: App metadata, platform targets, git URLs, versions, and `release_download` settings.
- `Appfile`, `Matchfile`: Match and developer account credentials.

### Ruby Helpers (`fastlane/helpers/`)
- `app_config_helper.rb`: JSON parser and validator for `apps.json`.
- `git_workspace_helper.rb`: Clones repos, manages branches, and syncs version configs.
- `cert_helper.rb` & `api_key_helper.rb`: Certificate and App Store Connect key loaders.

## 2. Inventory Metrics
- **Workflows**: 8 YAML files.
- **Lanes**: 6 Ruby files.
- **Helpers**: 7 Ruby modules.
- **Configured Apps**: 10+ applications in `apps.json`.

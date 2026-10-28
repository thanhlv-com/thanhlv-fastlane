# Technology Stack - thanhlv-fastlane

## 1. Programming Languages & Runtimes
- **Ruby**: 3.3 (Bundler, Fastlane 2.226+)
- **YAML**: GitHub Actions Workflow definitions (v4 Actions)
- **Bash / Shell**: Multi-platform scripts on macOS (zsh/bash), Ubuntu (bash), Windows (PowerShell/Bash)
- **Node.js**: 22 LTS (Target application runtime for Electron apps)

## 2. Tools & Frameworks
- **Fastlane**: Automated deployment and build engine
- **Fastlane Match**: Encrypted Git keystore for certificates and provisioning profiles
- **GitHub Actions**: Cloud runners (`macos-latest`, `windows-latest`, `ubuntu-latest`)
- **GitHub CLI (`gh`)**: GitHub Releases and API interactions
- **Apple `xcrun notarytool` / `stapler`**: macOS Gatekeeper notarization and ticket stapling
- **Actions Ecosystem**:
  - `actions/checkout@v4`
  - `actions/create-github-app-token@v1`
  - `actions/setup-node@v4`
  - `ruby/setup-ruby@v1`
  - `actions/upload-artifact@v4`
  - `actions/download-artifact@v4`

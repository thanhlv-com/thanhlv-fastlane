# Dependencies - thanhlv-fastlane

## 1. Internal Dependencies

```mermaid
graph TD
    Workflow["build-standalone-fastlane.yml"] --> RubyBundler["Gemfile / Bundler"]
    RubyBundler --> Fastfile["fastlane/Fastfile"]
    Fastfile --> StandaloneLane["lanes/standalone.rb"]
    StandaloneLane --> AppConfigHelper["helpers/app_config_helper.rb"]
    StandaloneLane --> GitHelper["helpers/git_workspace_helper.rb"]
    AppConfigHelper --> AppsJSON["fastlane/apps.json"]
    Workflow --> GHAppToken["actions/create-github-app-token@v1"]
    Workflow --> ReleaseJob["New Job: publish-release"]
    ReleaseJob --> GHCLI["gh release CLI"]
```

## 2. External Dependencies & Services
- **GitHub App**: ID `3766151` with private key stored in `THANHLV_PRIVATE_KEY`
- **Keystore Repository**: `apple-certificates-keystore` (private repo accessed via App token)
- **Target Application Repositories**: e.g., `git@github.com:thanhlv-com/web-clone.git`
- **Download / Release Repositories**: e.g., `git@github.com:Web-Clone-app/download.git`
- **Apple Developer & App Store Connect**: Notary API and Developer ID Application certificates
- **Telegram Bot API**: Notifications via `api.telegram.org`

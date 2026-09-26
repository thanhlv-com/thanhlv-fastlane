# System Architecture

## Architecture Diagram

```mermaid
flowchart TD
    User["Developer / CI Pipeline"] --> CLI["scripts/interactive_menu.rb (Interactive CLI)"]
    User --> Make["Makefile Targets"]
    User --> FastlaneCore["fastlane (CLI commands)"]

    CLI --> Make
    Make --> FastlaneCore

    subgraph FastlaneCoreFramework ["Fastlane Core & Automation Layer"]
        Fastfile["fastlane/Fastfile"]
        LanesIOS["fastlane/lanes/ios.rb"]
        LanesMac["fastlane/lanes/macos.rb"]
        LanesAOS["fastlane/lanes/aos.rb"]
        LanesWin["fastlane/lanes/windows.rb"]
        LanesLinux["fastlane/lanes/linux.rb"]
    end

    FastlaneCore --> Fastfile
    Fastfile --> LanesIOS
    Fastfile --> LanesMac
    Fastfile --> LanesAOS

    subgraph HelpersLayer ["Shared Helper Modules"]
        AppConfig["helpers/app_config_helper.rb"]
        APIKeyHelper["helpers/api_key_helper.rb"]
        CertHelper["helpers/cert_helper.rb"]
        MetadataHelper["helpers/metadata_helper.rb"]
        GoogleKeyHelper["helpers/google_key_helper.rb"]
        GitWorkspaceHelper["helpers/git_workspace_helper.rb"]
    end

    LanesIOS --> AppConfig
    LanesIOS --> APIKeyHelper
    LanesIOS --> CertHelper
    LanesMac --> AppConfig
    LanesMac --> APIKeyHelper

    subgraph ExternalServices ["External Apple & Google APIs"]
        AppleDevPortal["Apple Developer Portal (Certificates, Identifiers & Profiles)"]
        ASC["App Store Connect API"]
        MatchGit["Encrypted Git Keystore (Certificates & Provisioning)"]
    end

    APIKeyHelper --> ASC
    LanesIOS -->|produce / spaceship| AppleDevPortal
    LanesIOS -->|produce / spaceship| ASC
    LanesIOS -->|match| MatchGit
```

## Layer Responsibilities
1. **Entrypoints**:
   - `scripts/interactive_menu.rb`: Ruby terminal UI for interactive option selection.
   - `Makefile`: Shell commands standardizing lane invocations with parameters.
   - Fastlane lanes: Individual task runners.
2. **Configuration & Data**:
   - `fastlane/apps.json`: Single source of truth for app metadata (bundle IDs, package names, git URLs, platforms, build numbers).
   - `.env`: Environment variables (API Key ID, Issuer ID, Match Git URL, passwords).
3. **Execution Engine**:
   - Fastlane actions (`produce`, `match`, `gym`, `deliver`, `pilot`).
   - Spaceship / App Store Connect API integration.

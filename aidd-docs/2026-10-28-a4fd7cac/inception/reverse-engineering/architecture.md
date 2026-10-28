# Architecture Overview - thanhlv-fastlane Standalone Build Pipeline

## 1. System Overview
The `thanhlv-fastlane` architecture separates orchestration (GitHub Actions workflows) from execution (Fastlane lanes and helper modules in Ruby). Standalone builds execute across multi-platform GitHub-hosted runners to produce native desktop binaries.

## 2. Architecture Diagram

```mermaid
flowchart TD
    subgraph GitHubActions["GitHub Actions: build-standalone-fastlane.yml"]
        Trigger["workflow_dispatch (app, platform, version, build_number, release)"]
        PreCheck["Optional Pre-Flight / Setup Gate\nValidate Version & Target Release Repo"]
        JobMac["Job: build-macos\n(macos-latest)"]
        JobWin["Job: build-windows\n(windows-latest)"]
        JobLinux["Job: build-linux\n(ubuntu-latest)"]
        JobRelease["Job: publish-release\n(all-platforms-success guard)"]
    end

    subgraph FastlaneCore["Fastlane Execution Layer"]
        LaneStandalone["standalone.rb (mac_build, win_build, linux_build)"]
        AppConfig["app_config_helper.rb & apps.json"]
        GitWorkspace["git_workspace_helper.rb"]
    end

    subgraph ExternalServices["External Ecosystem"]
        AppleASC["Apple Notary Service"]
        GitHubReleaseTarget["Target App / Download Repository\n(GitHub Releases API)"]
        Telegram["Telegram Notifications"]
    end

    Trigger --> PreCheck
    PreCheck --> JobMac
    PreCheck --> JobWin
    PreCheck --> JobLinux
    JobMac --> LaneStandalone
    JobWin --> LaneStandalone
    JobLinux --> LaneStandalone
    LaneStandalone --> AppConfig
    LaneStandalone --> GitWorkspace
    LaneStandalone --> AppleASC
    JobMac -.->|Upload Artifacts| JobRelease
    JobWin -.->|Upload Artifacts| JobRelease
    JobLinux -.->|Upload Artifacts| JobRelease
    JobRelease --> GitHubReleaseTarget
    JobMac --> Telegram
    JobWin --> Telegram
    JobLinux --> Telegram
    JobRelease --> Telegram
```

### Text Alternative
1. **GitHub Actions Workflow**: Receives user inputs, runs parallel platform jobs, uploads artifacts.
2. **Fastlane Core**: Clones target source repo into `.workspace_code/`, injects version, builds native binary, notarizes if macOS.
3. **External Services**: Apple Developer / Notary APIs, Telegram Bot notifications, GitHub Releases REST/GraphQL endpoints.

## 3. Data & Artifact Flow

```mermaid
sequenceDiagram
    autonumber
    actor User as Release Engineer
    participant GHA as GitHub Actions Workflow
    participant BuildRunner as Platform Runner (Mac/Win/Linux)
    participant Fastlane as Fastlane standalone.rb
    participant Repo as Target GitHub Repository
    participant TG as Telegram Bot

    User->>GHA: Trigger workflow_dispatch (app, platform, version, release)
    GHA->>BuildRunner: Start parallel runners
    BuildRunner->>Fastlane: bundle exec fastlane standalone <platform>_build
    Fastlane->>Fastlane: Clone app repo into .workspace_code
    Fastlane->>Fastlane: Compile & bundle native artifact (.dmg / .exe / .AppImage)
    Fastlane-->>BuildRunner: Save into build_output/
    BuildRunner->>GHA: Upload GitHub Actions Artifact
    BuildRunner->>TG: Send build completion status
    opt Release option enabled & all requested platforms succeeded
        GHA->>GHA: Collect all platform artifacts
        GHA->>Repo: Verify release tag does NOT exist
        GHA->>Repo: Create GitHub Release & Upload binaries
        GHA->>TG: Send Release Published notification
    end
```

## 4. Integration Points
- **GitHub App Authentication**: Uses `actions/create-github-app-token@v1` for scoped access to private keystores, source repositories, and release target repositories.
- **Apple Notary Tool (`xcrun notarytool`)**: Submits DMG/ZIP for gatekeeper notarization.
- **GitHub REST API / CLI (`gh`)**: Verifies release tag presence and creates release assets.
- **Telegram Notification Webhook**: Posts status updates to developer threads.

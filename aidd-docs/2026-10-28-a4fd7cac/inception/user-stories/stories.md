# User Stories - Standalone GitHub Release Automation

## Story US-01: Workflow Release Input Configuration
**As a** Release Engineer (Alex),  
**I want to** toggle a `release` checkbox when triggering `build-standalone-fastlane.yml`,  
**So that** I can build and publish an official GitHub Release in a single automated action.

### Acceptance Criteria
- **Scenario AC-01.1**: Default behavior remains unchanged
  - **Given** a user triggers the workflow without setting `release`
  - **When** the workflow executes
  - **Then** `release` defaults to `false`, artifacts are uploaded to GitHub Actions artifacts, and no GitHub Release is created.
- **Scenario AC-01.2**: Release mode enabled
  - **Given** a user checks `release: true`
  - **When** the workflow executes
  - **Then** the release pipeline activates pre-flight checks and the post-build release publishing job.

---

## Story US-02: Fail-Fast Duplicate Release Check (Rule 1)
**As a** Release Engineer (Alex),  
**I want** the pipeline to check whether a release matching the target version already exists in the target repository before launching heavy build jobs,  
**So that** I do not waste expensive macOS, Windows, and Linux runner minutes on a build that cannot be released.

### Acceptance Criteria
- **Scenario AC-02.1**: Target release version already exists
  - **Given** `release: true` and version is `1.0.2`
  - **And** target repository already has an active release for tag `v1.0.2` or `1.0.2`
  - **When** the pre-flight job executes
  - **Then** the job fails immediately with exit code 1
  - **And** outputs clear error message: `"❌ LỖI: Bản release cho version 1.0.2 (tag: v1.0.2) đã tồn tại trên repo <target-repo>! Vui lòng nâng version trước khi tạo release mới."`
  - **And** no build runner jobs (`build-macos`, `build-windows`, `build-linux`) are started.
- **Scenario AC-02.2**: Target release version is new
  - **Given** `release: true` and version is `1.0.3`
  - **And** target repository has no release matching `v1.0.3` or `1.0.3`
  - **When** the pre-flight job executes
  - **Then** pre-flight succeeds and passes validation outputs to downstream build runners.

---

## Story US-03: Dynamic Release Target Repository Resolution
**As an** App Developer (Thanh),  
**I want** the workflow to automatically inspect `apps.json` and publish to `release_download` if present, or fallback to `git_url`,  
**So that** I can host user-facing downloads on dedicated repositories (e.g. `Web-Clone-app/download`) seamlessly.

### Acceptance Criteria
- **Scenario AC-03.1**: App specifies `release_download`
  - **Given** app `web-clone` with `"release_download": "git@github.com:Web-Clone-app/download.git"`
  - **When** the target repository is resolved
  - **Then** target repository is set to `Web-Clone-app/download`
  - **And** GitHub App token is acquired for owner `Web-Clone-app`.
- **Scenario AC-03.2**: App does not specify `release_download`
  - **Given** app `CloudOps` with `"git_url": "git@github.com:thanhlv-com/dev-tool.git"` and no `release_download`
  - **When** the target repository is resolved
  - **Then** target repository is set to `thanhlv-com/dev-tool`
  - **And** GitHub App token is acquired for owner `thanhlv-com`.

---

## Story US-04: Strict All-Platforms Success Gating (Rule 2)
**As a** Desktop App End-User (Sam),  
**I want** every official GitHub Release to contain verified binaries for all target platforms,  
**So that** I never experience missing platform installers or partial releases.

### Acceptance Criteria
- **Scenario AC-04.1**: All requested platforms succeed
  - **Given** `platform: all` and `release: true`
  - **When** `build-macos`, `build-windows`, and `build-linux` all complete with status `success`
  - **Then** `publish-release` runs and publishes the complete multi-platform release.
- **Scenario AC-04.2**: Any requested platform fails
  - **Given** `platform: all` and `release: true`
  - **When** `build-windows` fails or is cancelled
  - **Then** `publish-release` does NOT run (status skipped / aborted)
  - **And** no GitHub Release is created.

---

## Story US-05: Release Assets Aggregation & Publication
**As a** Release Engineer (Alex),  
**I want** the workflow to aggregate all generated platform artifacts and publish the GitHub Release with informative release notes,  
**So that** the entire release process is 100% hands-free and reproducible.

### Acceptance Criteria
- **Scenario AC-05.1**: Successful release creation
  - **Given** all platform build jobs completed and artifacts uploaded
  - **When** `publish-release` executes
  - **Then** it downloads `.dmg`, `.exe`, and `.AppImage` files
  - **And** runs `gh release create` attaching all downloaded files
  - **And** posts a notification with the release URL to Telegram.

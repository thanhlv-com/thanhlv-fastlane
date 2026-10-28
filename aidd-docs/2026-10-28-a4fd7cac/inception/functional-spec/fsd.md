# Functional Specification Document (FSD)
## Standalone Automated GitHub Release Pipeline

### 1. Document Control & Metadata
- **Feature Name**: Standalone GitHub Release Automation
- **Target File**: `.github/workflows/build-standalone-fastlane.yml`
- **Specification Version**: 1.0.0
- **Status**: APPROVED
- **Date**: 2026-10-28
- **Authors**: AI-DD Inception Team

---

### 2. Executive Summary & Scope

#### 2.1 Objective
Enhance `.github/workflows/build-standalone-fastlane.yml` with automated release capabilities. Allow release engineers to toggle a `release` input which triggers pre-flight validation against duplicate releases, enforces all-or-nothing platform success gates, resolves target repositories dynamically (supporting `release_download` override), and automatically creates a GitHub Release with all compiled desktop assets (`.dmg`, `.exe`, `.AppImage`).

#### 2.2 In-Scope
- Addition of `release` input to `workflow_dispatch`.
- Pre-Flight validation job (`validate-release` / pre-check) to check release tag existence prior to building.
- Dynamic target repository resolution from `fastlane/apps.json`:
  - Priority 1: `release_download` (if specified and non-empty).
  - Priority 2: `git_url`.
- URL parsing converting SSH/HTTPS URLs into `owner/repo` format.
- GitHub App token generation for the target repository owner.
- Multi-platform success condition evaluation (`build-macos`, `build-windows`, `build-linux`).
- Post-build release publishing job (`publish-release`).
- Artifact download, aggregation, and GitHub Release publication using `gh release create`.
- Telegram notifications for release status.

#### 2.3 Out-of-Scope (Non-Goals)
- Modifying App Store / Play Store mobile deployment workflows (`deploy-ios-fastlane.yml`, etc.).
- Modifying binary compilation flags inside Electron or Flutter codebases.
- Changing Apple Developer certificates or Match keystore encryption.

---

### 3. User Personas & Permissions (RBAC)

| Role / Persona | Responsibilities | Permissions Needed |
|---|---|---|
| **Release Engineer / Maintainer** | Triggers workflow dispatch from GitHub Actions UI or CLI | GitHub Actions `workflow_dispatch` permission on `thanhlv-fastlane` |
| **GitHub Actions CI/CD Runner** | Executes jobs, builds binaries, downloads artifacts | Internal GitHub runner permissions |
| **GitHub App Bot (`3766151`)** | Accesses private source repos, creates releases and uploads assets | Contents: `write`, Metadata: `read` on target repository |

---

### 4. Process Flow & Navigation

```mermaid
flowchart TD
    Start([User triggers workflow_dispatch]) --> CheckReleaseInput{inputs.release == true?}
    
    CheckReleaseInput -->|No: Standard Build| BuildRunners[Run requested build jobs: Mac, Win, Linux]
    BuildRunners --> FinishBuild[Upload Actions Artifacts & Notify Telegram]
    FinishBuild --> End([Done])

    CheckReleaseInput -->|Yes: Release Mode| PreCheck[Job: pre-check & validate-release]
    PreCheck --> ParseRepo[Resolve target repo from apps.json: release_download || git_url]
    ParseRepo --> ResolveVersion[Resolve version from inputs.version || apps.json]
    ResolveVersion --> CheckDuplicateTag{Release tag already exists in target repo?}
    
    CheckDuplicateTag -->|Yes: Duplicate Found| FailFast[❌ Fail Early with Error Message\nAbort Pipeline]
    FailFast --> EndFail([Failed Pre-Flight])
    
    CheckDuplicateTag -->|No: Tag Available| LaunchBuilds[Run requested build jobs in parallel]
    LaunchBuilds --> CheckPlatformResults{All requested platform jobs SUCCESS?}
    
    CheckPlatformResults -->|Any Job Failed/Cancelled| AbortRelease[❌ Abort Release Job\nDo NOT publish release]
    AbortRelease --> EndFail
    
    CheckPlatformResults -->|All Jobs Succeeded| PublishJob[Job: publish-release]
    PublishJob --> DownloadArtifacts[Download all platform artifacts DMG, EXE, AppImage]
    PublishJob --> CreateGHRelease[gh release create with binary assets]
    CreateGHRelease --> ReleaseNotification[Send Telegram Release Notification]
    ReleaseNotification --> EndSuccess([Release Published Successfully])
```

---

### 5. Detailed Feature Specifications (`FS-REL-001`)

#### 5.1 Inputs & Preconditions
- **Workflow Input**:
  - Name: `release`
  - Type: `boolean`
  - Default: `false`
  - Description: "Tạo GitHub Release và tải lên các file build thành công"
- **Preconditions**:
  - `apps.json` contains valid configuration for `inputs.app`.
  - Target repository is accessible via the GitHub App credentials.

#### 5.2 Happy Path Flow
1. User triggers workflow with `app: web-clone`, `platform: all`, `version: 1.0.3`, `release: true`.
2. Job `pre-check` starts:
   - Reads `fastlane/apps.json`.
   - Sees `release_download: "git@github.com:Web-Clone-app/download.git"`.
   - Parses target repo slug: `Web-Clone-app/download`.
   - Resolves target owner: `Web-Clone-app`.
   - Checks release tag `v1.0.3` via GitHub API: returns 404 (Not Found).
   - Validation passes! Emits outputs: `target_repo`, `target_owner`, `release_tag`, `version`.
3. Parallel build jobs launch:
   - `build-macos` succeeds, uploads `standalone-macos-web-clone-artifacts`.
   - `build-windows` succeeds, uploads `standalone-windows-web-clone-artifacts`.
   - `build-linux` succeeds, uploads `standalone-linux-web-clone-artifacts`.
4. Job `publish-release` runs (conditions met: all 3 jobs succeeded):
   - Generates GitHub App Token for owner `Web-Clone-app`.
   - Downloads all 3 platform artifact bundles into `release_assets/`.
   - Runs `gh release create v1.0.3 ./release_assets/* --repo Web-Clone-app/download --title "Web Clone - Multi-Session Browser v1.0.3" --notes "..."`.
   - Posts release announcement to Telegram.

#### 5.3 Exception & Alternative Flows

##### Exception 1: Release Tag Already Exists (Rule 1 Violation)
- **Condition**: Tag `v1.0.3` or `1.0.3` already exists on `Web-Clone-app/download`.
- **System Behavior**:
  - `pre-check` job immediately executes `exit 1` with error:
    `"❌ LỖI: Bản release cho version 1.0.3 (tag: v1.0.3) đã tồn tại trên repo Web-Clone-app/download! Vui lòng nâng version trước khi tạo release mới."`
  - Build runners never start. Zero runner minutes wasted.

##### Exception 2: Build Job Failure (Rule 2 Violation)
- **Condition**: `platform: all` was requested, but `build-windows` failed due to a compilation error.
- **System Behavior**:
  - `publish-release` evaluation checks: `needs.build-windows.result != 'success'`.
  - `publish-release` job is skipped or aborted immediately.
  - No release is created. No partial artifacts uploaded.

---

### 6. Field-Level Data Dictionary & Validation Rules

| Field Name | Source | Type | Validation / Format Rule | Default / Fallback |
|---|---|---|---|---|
| `inputs.release` | Workflow Input | Boolean | Must be `true` or `false` | `false` |
| `target_repo` | `apps.json` | String | Slug format `owner/repo` (alphanumeric, dashes) | Priority: `release_download` -> `git_url` |
| `target_owner` | Derived from `target_repo` | String | Extracted first segment before `/` | e.g. `Web-Clone-app` |
| `version` | `inputs.version` / `apps.json` | String | SemVer format (e.g. `1.0.3`) | `apps.json[app].version` |
| `release_tag` | Derived from `version` | String | Prefix with `v` (`v${version}`) | `v1.0.0` |
| `release_title` | Derived | String | `${app_name} v${version}` | `${app} v${version}` |

---

### 7. Requirements Traceability Matrix (RTM)

| Business Requirement | FSD Section | GitHub Actions Implementation | Acceptance Test Case |
|---|---|---|---|
| FR-1: Release Input | 5.1 | `inputs.release` in `on.workflow_dispatch` | Workflow UI displays toggle checkbox |
| FR-2: Target Repo Resolution | 5.2 | Node.js/Python script reading `apps.json` | Correctly prioritizes `release_download` |
| FR-3: Duplicate Release Check (Rule 1) | 5.3 | `pre-check` job `gh release view` check | Pipeline aborts if release exists |
| FR-4: All-Platform Gate (Rule 2) | 5.3 | `publish-release` `needs` & `if` conditions | Release blocked if any build fails |
| FR-5: Asset Aggregation | 5.2 | `actions/download-artifact@v4` | All DMG, EXE, AppImage files collected |
| FR-6: Release Creation | 5.2 | `gh release create` command | Release created on GitHub with assets |

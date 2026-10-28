# Requirements Document - Standalone GitHub Release Feature

## 1. Intent Analysis Summary
- **User Request**: Extend `.github/workflows/build-standalone-fastlane.yml` with optional GitHub Release creation and binary asset uploads:
  1. Add a `release` option (`workflow_dispatch` boolean input).
  2. If `release` is enabled, create a GitHub Release and upload built desktop artifacts to the app's repository.
  3. If the app has a `release_download` property in `apps.json`, create the GitHub Release and upload the assets to that `release_download` repository instead of `git_url`.
  4. Rule 1: Validate that the target repository does NOT already have an existing release matching the version being built. If it exists, abort with an error.
  5. Rule 2: All requested platforms must build successfully before any release is created.
- **Request Type**: Enhancement / Feature Addition to CI/CD Workflow.
- **Scope**: Targeted to `.github/workflows/build-standalone-fastlane.yml` with coordination across `fastlane/apps.json` schema and GitHub Actions jobs.
- **Complexity**: Moderate (cross-repository GitHub App token authorization, multi-job conditional gating, pre-flight duplicate release validation, multi-platform artifact aggregation).

## 2. Functional Requirements (FR)

### FR-1: Workflow Dispatch Input: `release`
- Add an optional boolean input `release` to `.github/workflows/build-standalone-fastlane.yml`.
- `description`: "Tự động tạo GitHub Release và tải lên các file build thành công"
- `required`: false
- `default`: false
- `type`: boolean

### FR-2: Target Repository Dynamic Resolution
- If `release` is true:
  - Query `fastlane/apps.json` for the specified `app` key.
  - Check for the existence and non-emptiness of `release_download`.
  - **Resolution Priority**:
    1. If `release_download` is present and valid: Target Repo = `release_download` (e.g., `Web-Clone-app/download`).
    2. Otherwise: Target Repo = `git_url` (e.g., `thanhlv-com/web-clone`).
  - Convert SSH (`git@github.com:owner/repo.git`) or HTTPS (`https://github.com/owner/repo.git`) formats into standard GitHub repository slug (`owner/repo`).

### FR-3: Pre-Flight Duplicate Release Validation (Rule 1)
- When `release` is true:
  - Resolve the effective release version:
    - If `inputs.version` is provided, use `inputs.version`.
    - If `inputs.version` is empty, read `version` from `apps.json` for the given app.
  - Determine the release tag name (e.g., `v${VERSION}` or `${VERSION}`).
  - Query the target repository using GitHub CLI / API (`gh release view`).
  - If a release already exists for this tag/version:
    - Immediately terminate the workflow with a descriptive user-facing error message:
      `"❌ LỖI: Bản release cho version ${VERSION} (tag: ${TAG}) đã tồn tại trên repo ${TARGET_REPO}! Vui lòng nâng version trước khi tạo release mới."`
  - If no matching release exists, proceed with the pipeline.

### FR-4: Strict Platform Success Gating (Rule 2)
- The release creation job (`publish-release`) must depend on all requested build jobs (`build-macos`, `build-windows`, `build-linux`).
- If `platform: all`: All 3 build jobs (`build-macos`, `build-windows`, `build-linux`) must complete with status `success`.
- If `platform: macos`: `build-macos` must complete with status `success`.
- If `platform: windows`: `build-windows` must complete with status `success`.
- If `platform: linux`: `build-linux` must complete with status `success`.
- If ANY requested build job fails, crashes, or is cancelled:
  - The `publish-release` job must NOT execute, preventing partial or broken releases.

### FR-5: Release Asset Download and Aggregation
- The `publish-release` job must download all uploaded platform artifacts:
  - `standalone-macos-*-artifacts` (`.dmg`)
  - `standalone-windows-*-artifacts` (`.exe`)
  - `standalone-linux-*-artifacts` (`.AppImage`)
- Consolidate all binary assets into a dedicated `release_assets/` directory.

### FR-6: GitHub Release Creation & Binary Upload
- Execute `gh release create <tag> <files...> --repo <target-repo> --title <title> --notes <notes>`.
- Release Title format: `${APP_NAME} v${VERSION}`.
- Release Notes: Automated changelog summary, commit hash, build date, and list of included platform binaries with checksums.
- Send a Telegram notification upon successful release publication with the release URL.

## 3. Non-Functional Requirements (NFR)

### NFR-1: Compute Efficiency (Fail-Fast)
- Duplicate release verification should execute in a lightweight Pre-Flight job before long-running multi-OS build runners spin up, preventing unnecessary consumption of GitHub Actions runner minutes.

### NFR-2: Security & Permissions
- Cross-repository release creation must utilize the scoped GitHub App token (`actions/create-github-app-token@v1`) generated for the target repository owner.
- Secrets must never be logged in workflow stdout or release notes.

### NFR-3: Idempotence & Error Transparency
- Clear error messages describing missing repositories, authorization failures, or duplicate version conflicts.

### NFR-4: Backward Compatibility
- Existing build behavior without `release` (default `release: false`) must remain 100% backward compatible without altering current build-and-upload artifact behavior.

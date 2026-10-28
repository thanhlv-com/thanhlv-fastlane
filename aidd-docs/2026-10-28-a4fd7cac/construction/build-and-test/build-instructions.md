# Build Instructions - Standalone Release Workflow

## 1. Prerequisites
- **Git**: Working copy of `thanhlv-fastlane`.
- **Ruby**: Version 3.3 with Bundler installed (`bundle install`).
- **Node.js**: Version 22 LTS.
- **GitHub App Credentials**:
  - `GH_APP_ID`: `"3766151"`
  - `THANHLV_PRIVATE_KEY`: Secret in GitHub Actions
- **Apple Developer Credentials**: For macOS DMG code signing and notarization.

## 2. Triggering the Workflow
The workflow is triggered via GitHub Actions `workflow_dispatch`:

### 2.1 Standard Build (No Release)
```bash
gh workflow run build-standalone-fastlane.yml \
  -f app="web-clone" \
  -f platform="all"
```

### 2.2 Release Build (With Release Publication)
```bash
gh workflow run build-standalone-fastlane.yml \
  -f app="web-clone" \
  -f platform="all" \
  -f version="1.0.3" \
  -f release=true
```

## 3. Workflow Execution Phases
1. **`pre-check` Job**:
   - Parses `fastlane/apps.json`.
   - Selects `release_download` if present, else fallback to `git_url`.
   - Checks if tag `v1.0.3` or `1.0.3` exists on target repo.
   - If tag exists: halts immediately (Rule 1).
2. **Build Runners (`build-macos`, `build-windows`, `build-linux`)**:
   - Run in parallel across macOS, Windows, and Ubuntu runners.
   - Compile desktop binaries and upload to actions artifacts.
3. **`publish-release` Job**:
   - Verifies all requested platforms succeeded (Rule 2).
   - Downloads all artifacts and aggregates them into `release_assets/`.
   - Executes `gh release create` to publish the release with assets.
   - Sends Telegram notification.

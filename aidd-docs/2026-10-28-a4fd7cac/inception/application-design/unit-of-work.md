# Units of Work - Standalone GitHub Release Pipeline

## Unit 1: Release Pre-Flight & Target Resolution Engine (`uow-preflight-resolver`)

### 1.1 Overview & Responsibilities
- **Unit ID**: `uow-preflight-resolver`
- **Scope**: Upstream workflow inputs and pre-flight validation job (`pre-check`).
- **Core Responsibilities**:
  1. Add `release` boolean input to `on.workflow_dispatch`.
  2. Implement `pre-check` job on `ubuntu-latest`.
  3. Parse `fastlane/apps.json` for `inputs.app`.
  4. Dynamically resolve target repository: prioritize `release_download` over `git_url`.
  5. Convert SSH/HTTPS URLs to GitHub repository slug `owner/repo`.
  6. Generate scoped GitHub App Token using target repository `owner`.
  7. Check `gh release view` for `v${VERSION}` and `${VERSION}`.
  8. Fail-fast with error if release tag already exists (Rule 1).
  9. Emit step outputs: `target_repo`, `target_owner`, `version`, `release_tag`, `app_name`.

### 1.2 Boundary & Deliverables
- Target file: `.github/workflows/build-standalone-fastlane.yml` (`inputs` section and `pre-check` job definition).

---

## Unit 2: All-Platforms Gating & Multi-Artifact Release Publisher (`uow-release-publisher`)

### 2.1 Overview & Responsibilities
- **Unit ID**: `uow-release-publisher`
- **Scope**: Build job synchronization, gating condition, and `publish-release` job.
- **Core Responsibilities**:
  1. Wire conditional `needs: [pre-check]` into `build-macos`, `build-windows`, and `build-linux`.
  2. Implement `publish-release` job depending on `[pre-check, build-macos, build-windows, build-linux]`.
  3. Enforce strict all-platforms success condition (Rule 2).
  4. Download and aggregate all `.dmg`, `.exe`, and `.AppImage` files using `actions/download-artifact@v4`.
  5. Execute `gh release create` to publish release and upload binary assets.
  6. Dispatch Telegram notification containing release URL and platform summary.

### 2.2 Boundary & Deliverables
- Target file: `.github/workflows/build-standalone-fastlane.yml` (`publish-release` job and job dependency updates).

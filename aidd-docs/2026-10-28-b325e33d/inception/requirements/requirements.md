# Requirements Document

## 1. Intent Analysis Summary

- **User Request**: "`build-standalone-fastlane` cấu hình ở trong `apps.json` là 1.0.1 nhưng khi build ra thì app vẫn là 1.0.0. Có vẻ ở config trong app chưa thực hiện cấu hình lại verion theo param"
- **Request Type**: Bug Fix & Enhancement
- **Initial Scope Estimate**: Multiple Components (`fastlane/lanes/standalone.rb`, `fastlane/helpers/git_workspace_helper.rb`, `.github/workflows/build-standalone-fastlane.yml`, target Electron workspace `web-clone`)
- **Initial Complexity Estimate**: Moderate (Requires reliable cross-platform JSON mutation, build tool command-line integration, workflow argument propagation, and target app TypeScript refactoring)
- **Requirements Depth**: Standard

---

## 2. Business Context & Problem Statement

In `thanhlv-fastlane`, application configurations are centralized in `fastlane/apps.json`. For the Electron-based application `web-clone`, `apps.json` specifies `"version": "1.0.1"`. When users trigger standalone packaging via the GitHub Actions workflow `build-standalone-fastlane.yml` (or Fastlane CLI), the resulting desktop packages (`.dmg`, `.exe`, `.AppImage`) remain at version `1.0.0`.

### Root Causes Addressed:
1. Fastlane standalone lanes (`mac_build`, `win_build`, `linux_build` in `fastlane/lanes/standalone.rb`) calculate the resolved `version_name` via `resolve_version_and_build_number` (returning `1.0.1`), but **never update the target application's `package.json`** prior to invoking `electron-builder`.
2. Target application `web-clone` hardcodes `'1.0.0'` in `src/main/menu.ts` (`app.setAboutPanelOptions`) instead of dynamically referencing `app.getVersion()`.
3. When the GitHub Actions workflow input `version` is left blank, the workflow relies on Fastlane's internal resolution from `apps.json`, which failed to write to disk.

---

## 3. User Clarification Answers Incorporated

Based on the verified answers in `requirement-verification-questions.md`:
- **Answer 1 -> Option A**: Fastlane must automatically update the `"version"` field in `package.json` inside the workspace before invoking the build command, AND append the build flag `-c.extraMetadata.version=#{version_name}` to `electron-builder` to guarantee 100% parity across app runtime and installer metadata.
- **Answer 2 -> Option A**: Refactor `web-clone/src/main/menu.ts` to dynamically retrieve `app.getVersion()` for `version` and `applicationVersion` in the About panel so the UI dynamically mirrors the packaged version without manual edits.
- **Answer 3 -> Option A**: Fastlane automatically reads the `"version"` configured in `apps.json` when the workflow input `version` is blank. If a manual `version` is provided on workflow dispatch, the manual input takes precedence over `apps.json`.
- **Answer 4 -> Option A**: Flutter standalone builds retain native `--build-name=#{version_name}` and `--build-number=#{build_number}` command-line overrides without touching `pubspec.yaml`, focusing file mutation exclusively on Electron / Node projects.

---

## 4. Functional Requirements

### FR-01: Electron Application Version Injection Helper
- **Description**: Fastlane must provide a reusable helper `configure_electron_version!(workspace_dir, version_name, build_number)` within `git_workspace_helper.rb` (or `app_config_helper.rb`).
- **Behavior**:
  1. Locates `package.json` in `workspace_dir`.
  2. Reads and parses `package.json`.
  3. Updates `package_json["version"] = version_name`.
  4. Optionally updates `build_number` if applicable.
  5. Writes formatted JSON back to `package.json`.
  6. Logs clear confirmation: `UI.success("📝 Đã cập nhật version: #{version_name} vào #{package_json_path}")`.

### FR-02: Standalone Lanes Version Synchronization
- **Description**: Update `mac_build`, `win_build`, and `linux_build` in `fastlane/lanes/standalone.rb`.
- **Behavior**:
  1. For Electron apps, call `configure_electron_version!` immediately after workspace preparation and before executing `npm install` or build commands.
  2. When constructing the `electron-builder` execution command, append `--extraMetadata.version=#{version_name}` (or `-c.extraMetadata.version=#{version_name}`) to the `npx electron-builder` command or npm script invocation.
  3. Ensure identical behavior across all three desktop platforms (`mac_build`, `win_build`, `linux_build`).

### FR-03: Target Electron Application Menu Dynamic Versioning
- **Description**: Refactor `src/main/menu.ts` in `.workspace_code/web-clone`.
- **Behavior**:
  1. Replace hardcoded `applicationVersion: '1.0.0'` with `applicationVersion: app.getVersion()`.
  2. Replace hardcoded `version: '1.0.0'` with `version: app.getVersion()`.
  3. Verify that the About dialog displays the dynamic runtime version.

### FR-04: Workflow Parameter Integrity & Verification
- **Description**: Verify and ensure `.github/workflows/build-standalone-fastlane.yml` seamlessly propagates custom `version` and `build_number` inputs, and gracefully falls back to `apps.json` when empty.
- **Behavior**:
  1. When `INPUT_VERSION` is provided, Fastlane receives `version:$INPUT_VERSION`.
  2. When `INPUT_VERSION` is empty, Fastlane resolves `version` from `apps.json`.
  3. Fastlane injects the resulting version into `package.json`.

---

## 5. Non-Functional Requirements

### NFR-01: Clean Workspace State & Idempotency
- Multiple consecutive runs of Fastlane or the workflow must safely overwrite `package.json` with the latest target version without corrupting formatting, dependencies, or scripts.

### NFR-02: Backward Compatibility
- Existing Flutter desktop lanes (`flutter build macos/windows/linux`) and mobile lanes (`ios`, `macos`, `aos`) must not be broken or altered.
- All Fastlane helper syntax must pass `ruby -c` validation.

### NFR-03: Performance
- The version injection step must be instantaneous (under 50ms) with zero impact on overall CI/CD build times.

### NFR-04: Automated Verification
- Verify that `web-clone` packages with `1.0.1` in output artifacts and filenames (`Web Clone-1.0.1.dmg`, `Web Clone Setup 1.0.1.exe`, `Web Clone-1.0.1.AppImage`).
- Verify `npm run check:lines`, `npm run typecheck`, and `npm test` in `web-clone` pass cleanly.

# Integration Test Instructions - Multi-Job Gating & End-to-End Simulation

## 1. Test Scenarios

### Scenario IT-01: End-to-End Release Publishing (`platform: all`, `release: true`)
- **Preconditions**: Target repository does NOT contain release for version `1.0.9`.
- **Expected Flow**:
  1. `pre-check` validates `v1.0.9` -> succeeds, exports `target_repo: Web-Clone-app/download`.
  2. `build-macos`, `build-windows`, and `build-linux` run and succeed.
  3. `publish-release` condition evaluates to `true`.
  4. Release `v1.0.9` is created on `Web-Clone-app/download` with `.dmg`, `.exe`, `.AppImage` uploaded.

### Scenario IT-02: Fail-Fast Tag Conflict Detection (Rule 1)
- **Preconditions**: Target repository ALREADY contains release for tag `v1.0.2`.
- **Trigger**: `version: 1.0.2`, `release: true`.
- **Expected Flow**:
  1. `pre-check` executes `gh release view v1.0.2` -> returns 0 (Found).
  2. `pre-check` executes `exit 1` with error: `"❌ LỖI: Bản release cho version 1.0.2 (tag: v1.0.2) đã tồn tại..."`.
  3. `build-macos`, `build-windows`, `build-linux` are skipped.
  4. Zero runner minutes consumed on compilation.

### Scenario IT-03: Partial Build Failure Barrier Gating (Rule 2)
- **Preconditions**: `platform: all`, `release: true`.
- **Simulated Event**: `build-windows` fails compilation.
- **Expected Flow**:
  1. `build-macos` succeeds.
  2. `build-linux` succeeds.
  3. `build-windows` fails.
  4. `publish-release` condition checks: `needs.build-windows.result == 'success'`.
  5. Condition evaluates to `false` -> `publish-release` is skipped.
  6. No incomplete release is published.

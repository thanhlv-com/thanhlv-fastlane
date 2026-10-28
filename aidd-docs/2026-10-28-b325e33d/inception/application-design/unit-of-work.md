# Units of Work (UOW)

## 1. Units Decomposition Overview

The implementation is partitioned into 4 atomic, verifiable Units of Work:

| Unit ID | Unit Name | Scope / Target Files | Story Mapping |
|---|---|---|---|
| **UOW-01** | Electron Version Injection Helper | `fastlane/helpers/git_workspace_helper.rb` | US-01, FR-01 |
| **UOW-02** | Standalone Lanes Integration | `fastlane/lanes/standalone.rb` | US-01, FR-02, FR-04 |
| **UOW-03** | Web Clone Dynamic About Panel | `.workspace_code/web-clone/src/main/menu.ts` | US-02, FR-03 |
| **UOW-04** | E2E Packaging & Verification | `tests`, `Fastfile`, `make check-all` | US-01, US-02 |

---

## 2. Unit Specifications

### UOW-01: Electron Version Injection Helper
- **Goal**: Implement `configure_electron_version!(workspace_dir, version_name, build_number = nil)` in `git_workspace_helper.rb`.
- **Key Responsibilities**:
  - Safely read and JSON-parse `package.json` in the target workspace.
  - Modify `"version"` attribute with `version_name`.
  - Format and write back with standard 2-space indentation.
  - Fail-safe exception handling so invalid JSON logs an error rather than halting with an unhandled exception.
- **Definition of Done (DoD)**:
  - Helper is defined in `git_workspace_helper.rb`.
  - `ruby -c fastlane/helpers/git_workspace_helper.rb` succeeds.
  - Unit test / dry-run successfully mutates a sample `package.json`.

---

### UOW-02: Fastlane Standalone Lanes Update
- **Goal**: Integrate version injection and electron-builder CLI arguments into `mac_build`, `win_build`, and `linux_build`.
- **Key Responsibilities**:
  - In `fastlane/lanes/standalone.rb`, invoke `configure_electron_version!` after `prepare_app_workspace`.
  - Append `-c.extraMetadata.version=#{version_name}` to `build_cmd`.
  - Ensure uniform handling across `mac_build`, `win_build`, and `linux_build`.
- **Definition of Done (DoD)**:
  - All three lanes updated in `fastlane/lanes/standalone.rb`.
  - `ruby -c fastlane/lanes/standalone.rb` succeeds.
  - Dry run verifies command construction includes version flag.

---

### UOW-03: Web Clone Dynamic About Panel Refactor
- **Goal**: Refactor `src/main/menu.ts` in `.workspace_code/web-clone/`.
- **Key Responsibilities**:
  - Replace hardcoded `applicationVersion: '1.0.0'` and `version: '1.0.0'` with `app.getVersion()`.
- **Definition of Done (DoD)**:
  - `web-clone/src/main/menu.ts` updated.
  - `npm run check:lines` passes (under 250 lines).
  - `npm run typecheck` passes cleanly with 0 TypeScript errors.

---

### UOW-04: Standalone Build Validation & E2E Verification
- **Goal**: Execute end-to-end verification of version propagation from `apps.json` and workflow parameters.
- **Key Responsibilities**:
  - Verify that `web-clone` `package.json` reflects `1.0.1`.
  - Execute syntax validation across all Ruby files (`make check-all`).
  - Document verification evidence in retrospective and state tracking.
- **Definition of Done (DoD)**:
  - All automated checks pass cleanly.

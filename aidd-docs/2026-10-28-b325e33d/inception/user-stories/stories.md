# User Stories

## Story US-01: Automated Package Version Injection from Central Config
- **Persona**: Alex (DevOps & Release Engineer)
- **Requirement Traceability**: FR-01, FR-02, FR-04, FSD Section 2.1
- **INVEST Verification**:
  - Independent: Can be developed and tested independently in Fastlane standalone lanes.
  - Negotiable: Implementation details (helper function structure) remain flexible.
  - Valuable: Delivers immediate business value by eliminating release version discrepancy.
  - Estimable: Scope is well-defined and confined to helper and lane files.
  - Small: Fits within a single unit of work.
  - Testable: Fully verifiable by checking resulting `package.json` and generated DMG/EXE/AppImage filenames.

### Narrative
**As a** DevOps & Release Engineer,  
**I want** Fastlane standalone lanes (`mac_build`, `win_build`, `linux_build`) to automatically inject the resolved version from `apps.json` or workflow dispatch parameters into the Electron target app's `package.json` before building,  
**So that** the generated distribution packages (`.dmg`, `.exe`, `.AppImage`) and internal app manifests match the intended release version without manual intervention.

### Acceptance Criteria (Gherkin)

```gherkin
Scenario: Standalone packaging with default apps.json version
  Given "web-clone" is configured with "version": "1.0.1" in "fastlane/apps.json"
  And the workflow "build-standalone-fastlane.yml" is triggered with empty version parameter
  When Fastlane executes "mac_build", "win_build", or "linux_build"
  Then the target app workspace "package.json" must be updated with "version": "1.0.1"
  And electron-builder must receive the version override
  And the generated artifacts must be named with version "1.0.1" (e.g., "Web Clone-1.0.1.dmg")

Scenario: Standalone packaging with explicit workflow version override
  Given "web-clone" is configured with "version": "1.0.1" in "fastlane/apps.json"
  And the workflow is triggered with parameter "version: 1.2.0"
  When Fastlane executes standalone packaging
  Then the target app workspace "package.json" must be updated with "version": "1.2.0"
  And the generated artifacts must reflect version "1.2.0"
```

---

## Story US-02: Dynamic Application About Panel Rendering
- **Persona**: Sam (Desktop Application End User)
- **Requirement Traceability**: FR-03, FSD Section 2.2
- **INVEST Verification**:
  - Independent: Confined to `src/main/menu.ts` in target application repository.
  - Negotiable: Choice of Electron runtime API (`app.getVersion()`).
  - Valuable: Prevents end-user confusion regarding installed release versions.
  - Estimable: Minimal refactoring in a single file.
  - Small: Small refactor of 2 lines in `menu.ts`.
  - Testable: Verifiable via Electron application execution and unit tests.

### Narrative
**As a** Desktop Application End User,  
**I want** the "About Web Clone" dialog to display the dynamic runtime version of the application,  
**So that** I can accurately verify the version I am currently running.

### Acceptance Criteria (Gherkin)

```gherkin
Scenario: Viewing About panel after version update
  Given the application was packaged with version "1.0.1"
  When I launch Web Clone on macOS, Windows, or Linux
  And I open the "About Web Clone" dialog
  Then the dialog must display version "1.0.1"
  And there must be no hardcoded "1.0.0" displayed in the version fields
```

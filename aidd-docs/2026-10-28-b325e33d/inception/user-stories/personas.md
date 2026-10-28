# User Personas

## Persona 1: Alex — DevOps & Release Engineer
- **Role**: Maintains CI/CD infrastructure, triggers release workflows, and distributes standalone installers.
- **Goals**:
  - Ensure releases built via `build-standalone-fastlane.yml` or Fastlane CLI strictly reflect the version defined in `apps.json` or entered via workflow parameters.
  - Avoid manual patching of target repo configuration files (`package.json`) before every release.
- **Pain Points**:
  - Workflow builds produce `1.0.0` packages even though `apps.json` specifies `1.0.1`.
  - Inconsistency between installer filename and actual bundled version.

## Persona 2: Sam — Desktop Application End User
- **Role**: Uses `web-clone` desktop browser daily for multi-session browsing across platforms.
- **Goals**:
  - Verify installed app version from the application menu (About dialog).
  - Confirm that features or bugfixes announced in release notes (e.g., v1.0.1) are running in their installed app.
- **Pain Points**:
  - Downloaded an updated version (v1.0.1), but the About dialog still displays `1.0.0`, causing confusion about whether the upgrade succeeded.

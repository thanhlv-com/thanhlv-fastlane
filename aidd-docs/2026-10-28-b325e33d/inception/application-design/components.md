# Application Components

## 1. Component Overview

The version synchronization architecture consists of three collaborating components:

```mermaid
graph TD
    LaneComponent["Fastlane Standalone Lanes<br/>(mac_build, win_build, linux_build)"]
    HelperComponent["Electron Version Helper<br/>(configure_electron_version!)"]
    TargetComponent["Target App Dynamic Menu<br/>(web-clone setupAppMenu)"]

    LaneComponent -->|invokes before build| HelperComponent
    HelperComponent -->|mutates package.json| PkgJson["package.json"]
    LaneComponent -->|passes CLI flag| ElectronBuilder["npx electron-builder"]
    ElectronBuilder -->|packages app| AppDist["DMG / EXE / AppImage"]
    TargetComponent -->|reads runtime version| AppDist
```

## 2. Component Inventory

### COMP-01: `FastlaneStandaloneLane`
- **Location**: `fastlane/lanes/standalone.rb`
- **Role**: Automation orchestrator for desktop builds.
- **Responsibilities**:
  - Resolves version and build number from command line options or `apps.json`.
  - Determines framework type via `is_electron_app?`.
  - Prepares workspace and calls `configure_electron_version!`.
  - Injects `-c.extraMetadata.version=#{version_name}` into electron-builder execution string.
  - Codesigns and notarizes output packages.

### COMP-02: `ElectronWorkspaceHelper`
- **Location**: `fastlane/helpers/git_workspace_helper.rb`
- **Role**: Workspace manipulation utility.
- **Responsibilities**:
  - Locates `package.json` in target workspace.
  - Parses JSON content safely with error handling.
  - Updates the top-level `"version"` attribute.
  - Writes back formatted, indented JSON.

### COMP-03: `ElectronDynamicMenu`
- **Location**: `.workspace_code/web-clone/src/main/menu.ts`
- **Role**: Target Electron application menu controller.
- **Responsibilities**:
  - Configures the macOS and Windows/Linux application menu.
  - Populates `app.setAboutPanelOptions` dynamically from `app.getVersion()`.

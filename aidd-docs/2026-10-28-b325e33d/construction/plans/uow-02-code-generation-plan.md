# Code Generation Plan: UOW-02 — Standalone Lanes Integration

## Unit Overview
- **Unit ID**: `UOW-02`
- **Unit Name**: Standalone Lanes Integration
- **Target File**: `fastlane/lanes/standalone.rb`
- **Requirements Traced**: FR-02, FR-04, NFR-02
- **User Story Traced**: US-01

## Implementation Checklist
- [x] Step 1: Update `mac_build` lane in `fastlane/lanes/standalone.rb`:
  - Call `configure_electron_version!(workspace_dir, version_name, build_number)` for Electron apps.
  - Append version build flag `-c.extraMetadata.version=#{version_name}` to `build_cmd`.
- [x] Step 2: Update `win_build` lane in `fastlane/lanes/standalone.rb`:
  - Call `configure_electron_version!(workspace_dir, version_name, build_number)` for Electron apps.
  - Append version build flag to `build_cmd`.
- [x] Step 3: Update `linux_build` lane in `fastlane/lanes/standalone.rb`:
  - Call `configure_electron_version!(workspace_dir, version_name, build_number)` for Electron apps.
  - Append version build flag to `build_cmd`.
- [x] Step 4: Verify Ruby syntax with `ruby -c fastlane/lanes/standalone.rb`

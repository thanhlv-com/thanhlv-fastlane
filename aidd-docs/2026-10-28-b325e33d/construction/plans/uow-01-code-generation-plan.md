# Code Generation Plan: UOW-01 — Electron Version Injection Helper

## Unit Overview
- **Unit ID**: `UOW-01`
- **Unit Name**: Electron Version Injection Helper
- **Target File**: `fastlane/helpers/git_workspace_helper.rb`
- **Requirements Traced**: FR-01, NFR-01
- **User Story Traced**: US-01

## Implementation Checklist
- [x] Step 1: Implement `configure_electron_version!(workspace_dir, version_name, build_number = nil)` in `fastlane/helpers/git_workspace_helper.rb`
- [x] Step 2: Validate JSON parsing and writing with pretty generation (2 spaces)
- [x] Step 3: Implement graceful rescue and error handling for missing/corrupted `package.json`
- [x] Step 4: Verify Ruby syntax with `ruby -c fastlane/helpers/git_workspace_helper.rb`
- [x] Step 5: Test version mutation against a fixture/workspace `package.json`

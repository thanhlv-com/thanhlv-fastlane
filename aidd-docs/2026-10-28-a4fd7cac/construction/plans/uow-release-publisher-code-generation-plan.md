# Code Generation Plan - Unit 2: uow-release-publisher

## 1. Generation Checklist
- [x] Step 1: Update `build-macos`, `build-windows`, and `build-linux` with `needs: [pre-check]` and condition handling
- [x] Step 2: Implement `publish-release` job in `.github/workflows/build-standalone-fastlane.yml`
- [x] Step 3: Implement multi-platform asset aggregation, `gh release create`, and Telegram release notification
- [x] Step 4: Validate workflow structure and write `code-summary.md`

## 2. File Modification Boundaries
- **Modified File**: `.github/workflows/build-standalone-fastlane.yml`
- **Updated Jobs**: `build-macos`, `build-windows`, `build-linux`
- **New Job**: `publish-release`
- **Output Artifact**: `aidd-docs/construction/uow-release-publisher/code/code-summary.md`

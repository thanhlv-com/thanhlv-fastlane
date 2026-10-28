# Code Generation Plan - Unit 1: uow-preflight-resolver

## 1. Generation Checklist
- [x] Step 1: Add `release` input and environment variable to `.github/workflows/build-standalone-fastlane.yml`
- [x] Step 2: Implement `pre-check` job with dynamic target resolution and fail-fast duplicate tag verification
- [x] Step 3: Verify YAML syntax and write code summary (`code-summary.md`)

## 2. File Modification Boundaries
- **Modified File**: `.github/workflows/build-standalone-fastlane.yml`
- **New Section**: `jobs.pre-check`
- **Output Artifact**: `aidd-docs/construction/uow-preflight-resolver/code/code-summary.md`

# Business Rules - Unit 1: uow-preflight-resolver

## 1. Rule Definitions

### Rule BR-PRE-01: App Existence Validation
- **Trigger**: Execution of `pre-check` job.
- **Assertion**: `apps[inputs.app]` must exist in `fastlane/apps.json`.
- **Violation Action**: Log `::error::App '${inputs.app}' không tồn tại trong fastlane/apps.json` and exit with code 1.

### Rule BR-PRE-02: Target Repository Priority
- **Trigger**: Selecting destination repository for release creation.
- **Priority Order**:
  1. If `apps[inputs.app].release_download` is defined, trimmed, and non-empty: Destination = `release_download`.
  2. Otherwise: Destination = `apps[inputs.app].git_url`.
- **Validation**: Raw URL must be parseable into a valid GitHub `owner/repo` pattern.

### Rule BR-PRE-03: Version Resolution
- **Trigger**: Determining version number.
- **Precedence**:
  1. `inputs.version` (if non-empty).
  2. `apps[inputs.app].version` from `apps.json`.
  3. Default: `"1.0.0"`.

### Rule BR-PRE-04: Duplicate Release Prevention (Rule 1)
- **Trigger**: Prior to any compilation runner executing.
- **Assertion**:
  - `gh release view "v${VERSION}" --repo "${TARGET_REPO}"` must fail (release not found).
  - AND `gh release view "${VERSION}" --repo "${TARGET_REPO}"` must fail (release not found).
- **Violation Action**:
  - Abort immediately with exit code 1.
  - Log error annotation:
    `::error::❌ LỖI: Bản release cho version ${VERSION} (tag: ${RELEASE_TAG}) đã tồn tại trên repo ${TARGET_REPO}! Vui lòng nâng version trước khi tạo release mới.`

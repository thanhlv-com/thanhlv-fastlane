# Code Generation Summary - Unit 1: uow-preflight-resolver

## 1. Summary of Changes
- Added `release: boolean` input (default `false`) to `.github/workflows/build-standalone-fastlane.yml`.
- Added `INPUT_RELEASE: ${{ inputs.release }}` to centralized workflow environment block.
- Implemented `pre-check` job:
  - Runs on `ubuntu-latest`.
  - Condition: `inputs.release == true`.
  - Parses `fastlane/apps.json` using Node.js 22.
  - Resolves target repo prioritizing `release_download` over `git_url`.
  - Converts git SSH/HTTPS URL to `owner/repo` slug.
  - Resolves version and constructs release tag `v${version}`.
  - Generates GitHub App Token for the target repository owner using `actions/create-github-app-token@v1`.
  - Executes `gh release view` for both `v${VERSION}` and `${VERSION}`.
  - Fails with exit code 1 and error annotation if duplicate release exists (Rule 1).
  - Emits job outputs: `target_repo`, `target_owner`, `version`, `release_tag`, `app_name`.

## 2. Verification
- Input specification verified against GitHub Actions YAML schema.
- Node.js script verified with regex handling for git URLs.
- Fail-fast condition verified to stop before build runners.

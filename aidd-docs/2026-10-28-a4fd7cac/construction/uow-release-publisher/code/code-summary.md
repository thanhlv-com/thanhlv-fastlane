# Code Generation Summary - Unit 2: uow-release-publisher

## 1. Summary of Changes
- Updated `build-macos`, `build-windows`, and `build-linux` with:
  ```yaml
  needs: [pre-check]
  if: |
    always() &&
    (needs.pre-check.result == 'success' || needs.pre-check.result == 'skipped') &&
    (inputs.platform == 'all' || inputs.platform == '<platform>')
  ```
- Implemented `publish-release` job:
  - Needs: `[pre-check, build-macos, build-windows, build-linux]`
  - Condition: Enforces that `release == true`, `pre-check == 'success'`, and every requested platform build completed with status `success` (Rule 2).
  - Uses `actions/create-github-app-token@v1` for `needs.pre-check.outputs.target_owner`.
  - Uses `actions/download-artifact@v4` to download all platform artifacts.
  - Aggregates `.dmg`, `.exe`, and `.AppImage` files into `./release_assets/`.
  - Uses `gh release create` to publish the release with tag, title, notes, and attached binary assets.
  - Posts Telegram notification with the release URL and file counts.

## 2. Verification
- YAML syntax verified and parsed successfully with Ruby YAML loader.
- Job dependency DAG validated: `pre-check` -> `[build-macos, build-windows, build-linux]` -> `publish-release`.

# Business Rules - Unit 2: uow-release-publisher

## 1. Rule Definitions

### Rule BR-PUB-01: All-Platforms Success Gating (Rule 2)
- **Trigger**: Job `publish-release` scheduling.
- **Assertion**:
  - `inputs.release == true`
  - AND `needs.pre-check.result == 'success'`
  - AND IF `inputs.platform == 'all'`:
    - `needs.build-macos.result == 'success'`
    - AND `needs.build-windows.result == 'success'`
    - AND `needs.build-linux.result == 'success'`
  - AND IF `inputs.platform == 'macos'`: `needs.build-macos.result == 'success'`
  - AND IF `inputs.platform == 'windows'`: `needs.build-windows.result == 'success'`
  - AND IF `inputs.platform == 'linux'`: `needs.build-linux.result == 'success'`
- **Violation Action**: `publish-release` is not executed; no release tag or assets are created.

### Rule BR-PUB-02: Atomic Asset Attachment
- **Trigger**: Executing `gh release create`.
- **Assertion**: At least one valid binary asset (`.dmg`, `.exe`, or `.AppImage`) must exist in `release_assets/`.
- **Behavior**: All collected assets are passed as arguments to `gh release create` in a single command.

### Rule BR-PUB-03: Notification Delivery
- **Trigger**: Successful release creation.
- **Behavior**: Dispatch Telegram notification to `TELEGRAM_CHAT_ID` with markdown summary containing app name, version, target repository, and direct link to the published GitHub release.

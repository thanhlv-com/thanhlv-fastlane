# Application Design Plan

## 1. Objectives
Define the structural design, helper architecture, lane contracts, and error resilience boundaries for the Apple registration feature.

## 2. Design Scope
1. **Helper Design**:
   - Create `fastlane/helpers/apple_registration_helper.rb` to isolate all Apple Portal & App Store Connect verification logic from lanes.
   - Import helper in `fastlane/Fastfile`.
2. **Lane Contracts**:
   - `fastlane ios register_app` & `fastlane mac register_app`: accept `app` (optional, default: `all`), `bundle_id` (optional override).
   - `fastlane register_apps`: accept `app` (default: `all`), `platform` (default: `all`).
3. **Data Contracts**:
   - Reads existing app structure from `fastlane/apps.json`.
   - Reads `.env` for `ASC_KEY_ID`, `ASC_ISSUER_ID`, `MATCH_GIT_URL`, etc.
4. **Summary Table Formatting**:
   - Terminal summary table using Fastlane's built-in `Terminal::Table`.

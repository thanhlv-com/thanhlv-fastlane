# Component Methods Specification

## 1. `AppleRegistrationHelper` Methods

### `verify_and_register_apple_app(app_key, app_info, platform, options = {})`
- **Purpose**: Verifies and provisions a single app's Bundle ID on Developer Portal and App record on App Store Connect.
- **Parameters**:
  - `app_key` (String): Identifier key in `apps.json` (e.g. `"OpsFlow_Hub"`).
  - `app_info` (Hash): Configuration hash from `apps.json`.
  - `platform` (String): `"ios"` or `"macos"`.
  - `options` (Hash): Optional overrides (e.g. `:bundle_id`).
- **Returns**: `Hash` containing:
  ```ruby
  {
    app_key: app_key,
    platform: platform,
    bundle_id: bundle_id,
    app_name: app_name,
    portal_status: "EXISTS" | "CREATED" | "FAILED",
    asc_status: "EXISTS" | "CREATED" | "FAILED",
    error_message: nil | String
  }
  ```

### `verify_or_create_portal_bundle_id(bundle_id, app_name, platform_code)`
- **Purpose**: Checks `Spaceship::ConnectAPI.get_bundle_ids(filter: { identifier: bundle_id })`.
- **Behavior**:
  - If found: logs notice, returns `"EXISTS"`.
  - If missing: calls `Spaceship::ConnectAPI.post_bundle_id(name: app_name, identifier: bundle_id, platform: platform_code)`, returns `"CREATED"`.

### `verify_or_create_asc_app(bundle_id, app_name, platform_name, api_key)`
- **Purpose**: Checks `Spaceship::ConnectAPI.get_apps(filter: { bundleId: bundle_id })`.
- **Behavior**:
  - If found: logs notice, returns `"EXISTS"`.
  - If missing: calls Fastlane `produce(skip_devcenter: true, app_identifier: bundle_id, app_name: app_name, platform: platform_name, api_key: api_key)`, returns `"CREATED"`.

### `batch_verify_and_register(apps_data, target_platform, options = {})`
- **Purpose**: Iterates through matching apps and invokes `verify_and_register_apple_app` for each, accumulating results.

### `render_registration_summary_table(results)`
- **Purpose**: Uses `Terminal::Table` to render an execution summary table in the console.

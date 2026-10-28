# API Documentation

## Internal Ruby Helpers & Lanes

### `resolve_version_and_build_number(app_info, options)`
- **Module**: `fastlane/helpers/app_config_helper.rb`
- **Parameters**:
  - `app_info` (Hash): Application configuration loaded from `apps.json`.
  - `options` (Hash): Command-line / workflow options passed to the lane (e.g., `version`, `build_name`, `build_number`).
- **Return Type**: `[version_name (String), build_num (String)]`
- **Logic**:
  1. Checks `options[:version]`, `options[:build_name]`, `app_info["version"]`, `app_info["build_name"]`.
  2. Parses `+` delimiter if present (e.g., `"1.0.1+42"` -> `version_name = "1.0.1"`, `build_num = "42"`).
  3. Defaults `build_num` to epoch seconds (`Time.now.to_i.to_s`) if missing or set to `"timestamp"`.

### `prepare_app_workspace(app_key, app_info, options, target_platform)`
- **Module**: `fastlane/helpers/git_workspace_helper.rb`
- **Parameters**:
  - `app_key` (String): App identifier key in `apps.json`.
  - `app_info` (Hash): App configuration.
  - `options` (Hash): Invocation options.
  - `target_platform` (String): Target platform (e.g., `"macos"`, `"windows"`, `"linux"`).
- **Return Type**: `workspace_dir` (String - absolute path)
- **Logic**:
  1. Validates platform compatibility.
  2. Clones or fetches/pulls git branch.
  3. Installs dependencies (`npm install` or `flutter pub get`).

### `mac_build(options)` / `win_build(options)` / `linux_build(options)`
- **Module**: `fastlane/lanes/standalone.rb`
- **Parameters**:
  - `app` (String, required): App key (e.g. `"web-clone"`).
  - `version` (String, optional): Version string override (e.g. `"1.0.1"`).
  - `build_number` (String, optional): Build number override.
  - `skip_certs` (Boolean, optional): Skip signing checks.
  - `notarize` (Boolean, optional): Run xcrun notarytool submit (macOS).
- **Return Type**: Path to generated distribution artifact (`.dmg`, `.exe`, `.AppImage`) or output directory.

## GitHub Actions Workflow Contract: `build-standalone-fastlane.yml`

### Inputs
- `app` (choice, required): Key in `apps.json` (e.g., `"web-clone"`).
- `platform` (choice, required): `"all"`, `"macos"`, `"windows"`, `"linux"`.
- `version` (string, optional): Target version string. Default: `""`.
- `build_number` (string, optional): Target build number. Default: `""`.
- `skip_certs` (boolean, optional): Default: `false`.
- `notarize` (boolean, optional): Default: `true`.

### Outputs
- Uploaded GitHub Actions artifacts:
  - `standalone-macos-<app>-artifacts/*.dmg`
  - `standalone-windows-<app>-artifacts/*.exe`
  - `standalone-linux-<app>-artifacts/*.AppImage`
- Telegram notification payload containing run number, status icon, app, platform, and action URL.

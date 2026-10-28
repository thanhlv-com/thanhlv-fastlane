# API Documentation - Standalone Workflows & Helpers

## 1. Workflow Inputs API (`.github/workflows/build-standalone-fastlane.yml`)

### Current Inputs
| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `app` | choice | true | `web-clone` | App key defined in `fastlane/apps.json`. |
| `platform` | choice | true | `all` | Target platforms: `all`, `macos`, `windows`, `linux`. |
| `version` | string | false | `""` | Version override (e.g. `1.0.3`). Fallback to `apps.json` or `package.json`. |
| `build_number` | string | false | `""` | Build number override. Fallback to Epoch timestamp. |
| `skip_certs` | boolean | false | `false` | Skip code signing on macOS. |
| `notarize` | boolean | false | `true` | Submit macOS DMG to Apple Notarization. |

### Proposed New Inputs
| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `release` | boolean | false | `false` | Enable automated GitHub Release creation and upload of built desktop assets. |

## 2. Fastlane Lane APIs (`fastlane/lanes/standalone.rb`)

### `standalone mac_build`
- **Parameters**: `app: String`, `version: String` (opt), `build_number: String` (opt), `skip_certs: Boolean` (opt), `notarize: Boolean` (opt).
- **Outputs**: Signed & notarized `.dmg` placed in `.workspace_code/<app>/dist/` and copied to `build_output/`.

### `standalone win_build`
- **Parameters**: `app: String`, `version: String` (opt), `build_number: String` (opt).
- **Outputs**: Windows standalone `.exe` placed in `build_output/`.

### `standalone linux_build`
- **Parameters**: `app: String`, `version: String` (opt), `build_number: String` (opt).
- **Outputs**: Linux standalone `.AppImage` placed in `build_output/`.

## 3. Data Schema: `apps.json` (Standalone Target Applications)
```json
{
  "web-clone": {
    "app_name": "Web Clone - Multi-Session Browser",
    "git_url": "git@github.com:thanhlv-com/web-clone.git",
    "branch": "main",
    "framework": "electron",
    "release_download": "git@github.com:Web-Clone-app/download.git",
    "package_manager": "npm",
    "platforms": ["macos", "windows", "linux"],
    "bundle_id": "com.thanhlv.webclone",
    "package_name": "com.thanhlv.webclone",
    "version": "1.0.2",
    "obfuscate": false,
    "description": "Multi-session browser"
  }
}
```
- **`git_url`**: Primary source repository. Default target for GitHub release if `release_download` is omitted.
- **`release_download`**: Specialized download repository. When present, takes precedence as the release target repository.

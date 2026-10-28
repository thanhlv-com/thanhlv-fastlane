# Inter-Unit Interface Definitions

## 1. Interface Table

| Providing Unit | Consuming Unit | Interface Name | Type | Contract Format | Summary |
|---|---|---|---|---|---|
| `uow-preflight-resolver` | Build Runners | `PreFlightApproval` | GHA Job Status | `needs.pre-check.result` | Signals build runners that release tag is valid |
| `uow-preflight-resolver` | `uow-release-publisher` | `ReleaseContextPayload` | GHA Step Outputs | JSON / GHA Key-Value | Passes target repo, owner, tag, version |
| Build Runners | `uow-release-publisher` | `PlatformBinaryArtifacts` | File System / GHA Artifacts | File Patterns (`*.dmg`, `*.exe`, `*.AppImage`) | Aggregates binaries for release upload |

## 2. Detailed Contract Schemas

### Interface `ReleaseContextPayload` (Outputs of `pre-check`)
```yaml
outputs:
  target_repo:
    description: "GitHub repository slug (e.g. Web-Clone-app/download or thanhlv-com/web-clone)"
    value: ${{ steps.resolve.outputs.target_repo }}
  target_owner:
    description: "GitHub owner/org for token generation (e.g. Web-Clone-app or thanhlv-com)"
    value: ${{ steps.resolve.outputs.target_owner }}
  version:
    description: "Effective release version string (e.g. 1.0.3)"
    value: ${{ steps.resolve.outputs.version }}
  release_tag:
    description: "Target git release tag name (e.g. v1.0.3)"
    value: ${{ steps.resolve.outputs.release_tag }}
  app_name:
    description: "Human-readable application name"
    value: ${{ steps.resolve.outputs.app_name }}
```

### Interface `PlatformBinaryArtifacts` (Artifact Contracts)
- `standalone-macos-${{ inputs.app }}-artifacts`: Path `build_output/*.dmg`
- `standalone-windows-${{ inputs.app }}-artifacts`: Path `build_output/*.exe`
- `standalone-linux-${{ inputs.app }}-artifacts`: Path `build_output/*.AppImage`

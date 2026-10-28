# Services & Orchestration Patterns

## 1. Standalone Build Lifecycle Service

The standalone desktop build process follows a four-phase lifecycle orchestration:

```mermaid
sequenceDiagram
    autonumber
    participant Runner as CI Runner / CLI
    participant Lane as Fastlane Standalone Lane
    participant Config as app_config_helper
    participant Ws as git_workspace_helper
    participant App as Target Workspace

    Runner->>Lane: Invoke mac_build / win_build / linux_build
    Lane->>Config: get_app_config(app_key)
    Lane->>Config: resolve_version_and_build_number(app_info, options)
    Note over Lane,Config: Returns resolved version_name (e.g., "1.0.1")
    Lane->>Ws: prepare_app_workspace(app_key, app_info)
    Lane->>Ws: configure_electron_version!(workspace_dir, version_name)
    Ws->>App: Writes "version": "1.0.1" to package.json
    Lane->>App: Executes npm run build:* with -c.extraMetadata.version
    App-->>Lane: Outputs packaged artifact with version 1.0.1
```

## 2. Orchestration Invariants
1. **Idempotency**: Running the lane repeatedly with the same or modified version always safely overwrites `package.json` without file corruption.
2. **Environment Isolation**: Execution uses `Bundler.with_unbundled_env` via `run_node_cmd` to guarantee that Ruby Gems do not interfere with Node/npm commands.
3. **Dual-Layer Guarantee**:
   - Layer 1: In-file mutation of `package.json` ensures runtime `app.getVersion()` and Vite compilation see the updated version.
   - Layer 2: CLI build flag `-c.extraMetadata.version` ensures `electron-builder` overrides any cached build metadata.

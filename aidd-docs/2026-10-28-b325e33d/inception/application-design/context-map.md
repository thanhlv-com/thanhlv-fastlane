# Context Map

## 1. Bounded Contexts

```mermaid
graph LR
    subgraph "Fastlane Automation Context"
        Lanes["Fastlane Standalone Lanes"]
        Config["Central Registry (apps.json)"]
        Helpers["Workspace & Version Helpers"]
    end

    subgraph "Target Application Context (web-clone)"
        PkgManifest["package.json Manifest"]
        RuntimeUI["Electron Runtime (menu.ts)"]
    end

    subgraph "CI/CD Orchestration Context"
        GHA["GitHub Actions Workflow"]
    end

    GHA -->|Customer/Supplier| Lanes
    Config -->|Shared Kernel| Helpers
    Lanes -->|Orchestrator| Helpers
    Helpers -->|Mutates via ACL| PkgManifest
    PkgManifest -->|Read by| RuntimeUI
```

## 2. Relationship Patterns
- **GitHub Actions -> Fastlane**: Customer-Supplier. GitHub Actions passes inputs (`app`, `platform`, `version`, `build_number`) to Fastlane CLI.
- **Fastlane Helper -> Target App `package.json`**: Upstream-to-Downstream file synchronization. Fastlane ensures target application manifest matches centralized registry declarations before packaging begins.

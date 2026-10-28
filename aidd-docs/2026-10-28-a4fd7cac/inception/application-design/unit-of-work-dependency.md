# Unit of Work Dependency Matrix

## 1. Dependency Diagram

```mermaid
graph TD
    UOW1["Unit 1: uow-preflight-resolver\n(Inputs, apps.json parsing, duplicate check)"]
    BuildRunners["Existing Platform Build Runners\n(build-macos, build-windows, build-linux)"]
    UOW2["Unit 2: uow-release-publisher\n(Gating, asset aggregation, release publishing)"]

    UOW1 -->|Provides validation gate & context| BuildRunners
    UOW1 -->|Provides target_repo, tag, metadata| UOW2
    BuildRunners -->|Provides binary artifacts (.dmg, .exe, .AppImage)| UOW2
```

## 2. Unit Interaction Specifications

| Providing Unit | Consuming Unit | Data / Artifact Crossing Boundary |
|---|---|---|
| `uow-preflight-resolver` | Build Runners | Execution permission (proceed only if pre-flight passed or `release: false`) |
| `uow-preflight-resolver` | `uow-release-publisher` | Job outputs: `target_repo`, `target_owner`, `release_tag`, `version`, `app_name` |
| Build Runners | `uow-release-publisher` | Actions artifacts: `standalone-*-artifacts` containing binary files |

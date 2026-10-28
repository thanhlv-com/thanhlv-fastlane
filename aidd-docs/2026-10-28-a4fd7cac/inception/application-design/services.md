# Service Definitions & Orchestration Patterns

## 1. Service Definitions

### Service 1: Pipeline Pre-Flight Service (`SVC-PREFLIGHT`)
- **Scope**: Target discovery, configuration resolution, authentication exchange, collision detection.
- **Pattern**: Fail-Fast Filter Pattern.
- **Service Contract**:
  - Request: `inputs.app`, `inputs.version`, `inputs.release`.
  - Response (Success): Outputs `target_repo`, `target_owner`, `version`, `release_tag`, `app_name`.
  - Response (Failure): Workflow terminates immediately before build runner initialization.

### Service 2: Multi-Platform Compilation Service (`SVC-COMPILATION`)
- **Scope**: Parallel execution across `build-macos`, `build-windows`, `build-linux`.
- **Pattern**: Scatter-Gather Pattern.
- **Service Contract**:
  - Receives version and app context.
  - Compiles desktop packages and uploads platform artifacts.

### Service 3: Release Orchestration Service (`SVC-RELEASE-ORCHESTRATOR`)
- **Scope**: Multi-job result evaluation, artifact aggregation, release publication.
- **Pattern**: Barrier Synchronization Gate.
- **Service Contract**:
  - Evaluates platform job statuses (`needs.*.result`).
  - Gated execution: Executes only if all requested platform compilation jobs evaluated to `success`.

## 2. Orchestration & State Transition Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> PreFlight: workflow_dispatch triggered
    
    state PreFlight {
        [*] --> CheckReleaseToggle
        CheckReleaseToggle --> ResolveConfig: release == true
        CheckReleaseToggle --> SkipPreFlight: release == false
        ResolveConfig --> CheckDuplicateRelease
        CheckDuplicateRelease --> AbortConflict: Tag Exists (Exit 1)
        CheckDuplicateRelease --> PreFlightPassed: Tag Available
    }

    PreFlight --> BuildJobs: PreFlightPassed or SkipPreFlight
    
    state BuildJobs {
        [*] --> RunPlatforms
        RunPlatforms --> MacBuild: platform in [all, macos]
        RunPlatforms --> WinBuild: platform in [all, windows]
        RunPlatforms --> LinuxBuild: platform in [all, linux]
    }

    BuildJobs --> ReleaseGating: All jobs finished
    
    state ReleaseGating {
        [*] --> EvaluateStatus
        EvaluateStatus --> AbortRelease: Any requested job failed/cancelled
        EvaluateStatus --> ProceedRelease: release==true AND all requested succeeded
        EvaluateStatus --> EndStandard: release==false
    }

    ReleaseGating --> PublishRelease: ProceedRelease
    
    state PublishRelease {
        [*] --> DownloadArtifacts
        DownloadArtifacts --> AggregateAssets
        AggregateAssets --> ExecuteGHRelease
        ExecuteGHRelease --> NotifyTelegram
    }

    PublishRelease --> Completed
    EndStandard --> Completed
    AbortConflict --> Failed
    AbortRelease --> Failed
    Completed --> [*]
    Failed --> [*]
```

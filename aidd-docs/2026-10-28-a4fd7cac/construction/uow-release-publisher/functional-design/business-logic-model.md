# Business Logic Model - Unit 2: uow-release-publisher

## 1. Process Flow Diagram

```mermaid
flowchart TD
    BuildCompletion([Build Jobs Complete:\nbuild-macos, build-windows, build-linux]) --> GatingEval{"All requested platforms SUCCEEDED?"}
    
    GatingEval -->|No: Any Requested Platform Failed/Cancelled| SkipRelease["❌ Release Job Blocked / Skipped\nNo Release Created"]
    
    GatingEval -->|Yes: All Requested Platforms Succeeded| StartReleaseJob["Execute Job: publish-release (ubuntu-latest)"]
    StartReleaseJob --> TokenAuth["Generate App Token for target_owner via actions/create-github-app-token@v1"]
    TokenAuth --> DownloadArtifacts["actions/download-artifact@v4 to ./downloaded_artifacts"]
    DownloadArtifacts --> Aggregate["Consolidate all .dmg, .exe, .AppImage into ./release_assets/"]
    Aggregate --> VerifyAssets{"Are there any binary assets in release_assets/?"}
    
    VerifyAssets -->|No files found| WarnFail["Log warning/error and halt"]
    VerifyAssets -->|Files present| GenNotes["Generate Release Notes with Changelog, Commit SHA, and File Inventory"]
    GenNotes --> ExecGHRelease["gh release create {release_tag} ./release_assets/*\n--repo {target_repo}\n--title {release_title}\n--notes {release_notes}"]
    
    ExecGHRelease --> TelegramNotify["Send Telegram Release Announcement with Direct GitHub URL"]
    TelegramNotify --> CompleteRelease([Release Successfully Published])
```

## 2. Key Data Transformations
1. **Artifact Aggregation**: Multi-runner directories flattened into `./release_assets/` containing:
   - macOS: `*.dmg`
   - Windows: `*.exe`
   - Linux: `*.AppImage`
2. **Release Title Formulation**:
   `${APP_NAME} v${VERSION}` (e.g. `Web Clone - Multi-Session Browser v1.0.3`).
3. **Release Notes Formulation**:
   Auto-formatted markdown listing commit SHA, trigger actor, build run link, and asset list with file sizes.

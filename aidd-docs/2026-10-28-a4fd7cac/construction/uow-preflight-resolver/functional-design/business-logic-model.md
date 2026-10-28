# Business Logic Model - Unit 1: uow-preflight-resolver

## 1. Process Flow Diagram

```mermaid
flowchart TD
    Start([User triggers workflow]) --> CheckRelease{"inputs.release == true?"}
    
    CheckRelease -->|false| SkipJob["Skip pre-check job\nDownstream builds start normally"]
    
    CheckRelease -->|true| RunPreCheck["Execute job: pre-check (ubuntu-latest)"]
    RunPreCheck --> Checkout["actions/checkout@v4"]
    Checkout --> ReadConfig["Read fastlane/apps.json for inputs.app"]
    
    ReadConfig --> ResolveVersion["Resolve effective version: inputs.version || app.version"]
    ResolveVersion --> FormatTag["Construct release tag: v{version}"]
    
    FormatTag --> ResolveTargetRepo{"app.release_download present & non-empty?"}
    ResolveTargetRepo -->|Yes| UseDownloadRepo["Target Repo = app.release_download\n(e.g. Web-Clone-app/download)"]
    ResolveTargetRepo -->|No| UseGitUrl["Target Repo = app.git_url\n(e.g. thanhlv-com/web-clone)"]
    
    UseDownloadRepo --> ParseSlug["Extract {owner}/{repo} from git SSH or HTTPS URL"]
    UseGitUrl --> ParseSlug
    
    ParseSlug --> GenToken["actions/create-github-app-token@v1 for target owner"]
    GenToken --> CheckTagExists["gh release view v{version} on target repo"]
    
    CheckTagExists --> TagExistsDecision{"Tag v{version} or {version} exists?"}
    TagExistsDecision -->|Yes| FailFast["❌ Error Annotation & Exit 1\nHalts pipeline immediately"]
    TagExistsDecision -->|No| EmitOutputs["✅ Set GHA Step Outputs:\ntarget_repo, target_owner, version, release_tag, app_name"]
    
    EmitOutputs --> FinishPreCheck([Proceed to Build Runners])
```

## 2. Key Data Transformations
1. **App Registry Lookup**: Given `inputs.app = "web-clone"`, locate JSON object in `fastlane/apps.json`.
2. **Version Resolution**:
   - If `inputs.version != ""`: use `inputs.version.trim()`.
   - Else: use `app.version` (fallback `"1.0.0"`).
3. **Repository Slug Normalization**:
   - Matches both `git@github.com:owner/repo.git` and `https://github.com/owner/repo.git`.
   - Normalizes to canonical format: `owner/repo`.
4. **Tag Normalization**: Prefix canonical tag `v${version}`.

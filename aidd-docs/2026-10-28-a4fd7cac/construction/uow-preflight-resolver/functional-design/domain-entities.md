# Domain Entities - Unit 1: uow-preflight-resolver

## 1. Domain Entities

### Entity: `AppConfig`
- `app_key`: String (e.g. `"web-clone"`)
- `app_name`: String (e.g. `"Web Clone - Multi-Session Browser"`)
- `git_url`: String (e.g. `"git@github.com:thanhlv-com/web-clone.git"`)
- `release_download`: Optional String (e.g. `"git@github.com:Web-Clone-app/download.git"`)
- `version`: String (e.g. `"1.0.2"`)

### Entity: `TargetRepository`
- `owner`: String (e.g. `"Web-Clone-app"` or `"thanhlv-com"`)
- `repo_name`: String (e.g. `"download"` or `"web-clone"`)
- `full_slug`: String (e.g. `"Web-Clone-app/download"`)

### Entity: `ReleaseTag`
- `version`: String (e.g. `"1.0.3"`)
- `tag_name`: String (e.g. `"v1.0.3"`)

## 2. Interface DTO (`PreCheckOutputs`)
```yaml
outputs:
  target_repo: string
  target_owner: string
  version: string
  release_tag: string
  app_name: string
```

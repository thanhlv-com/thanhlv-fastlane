# Domain Entities - Unit 2: uow-release-publisher

## 1. Domain Entities

### Entity: `ReleaseAssetBundle`
- `dmg_files`: Array of Paths (e.g. `["build_output/WebClone-1.0.3-arm64.dmg"]`)
- `exe_files`: Array of Paths (e.g. `["build_output/WebClone-Setup-1.0.3.exe"]`)
- `appimage_files`: Array of Paths (e.g. `["build_output/WebClone-1.0.3.AppImage"]`)
- `total_files_count`: Integer

### Entity: `GitHubReleaseMetadata`
- `target_repo`: String (e.g. `"Web-Clone-app/download"`)
- `tag_name`: String (e.g. `"v1.0.3"`)
- `title`: String (e.g. `"Web Clone - Multi-Session Browser v1.0.3"`)
- `notes`: String (Markdown formatted release notes)
- `release_url`: String (e.g. `"https://github.com/Web-Clone-app/download/releases/tag/v1.0.3"`)
